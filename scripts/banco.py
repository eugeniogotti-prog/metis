#!/usr/bin/env python3
"""banco.py — banco di prova delle skill (protocollo: banco/README.md del plugin).

Una skill si modifica solo dopo averla misurata su casi veri: questo script esegue i casi, li fa giudicare e
confronta due giri. Portato il 6/10/2026 dal vault di riferimento e generalizzato.

Uso (con la configurazione caricata, come gli altri script; vedi banco/README.md):
  banco.py esegui    SKILL ETICHETTA [--esempi] [--skill-file PATH] [--casi id1,id2] [--paralleli 4]
  banco.py giudica   SKILL ETICHETTA [--esempi] [--paralleli 4]
  banco.py confronta SKILL ETICHETTA_A ETICHETTA_B

Dove stanno le cose:
  casi del cliente        <cartella di Claude>/banco-skill/SKILL/casi/*.md, con INDICE.md
  casi d'esempio          <plugin>/banco/SKILL/casi/*.md (con --esempi): inventati, mostrano come si scrive un caso
  esiti di ogni giro      <cartella di Claude>/banco-skill/SKILL/esiti/ETICHETTA/ (anche per i casi d'esempio)
  skill esaminata         <plugin>/skills/SKILL/SKILL.md, oppure --skill-file per una versione candidata

esegui:    per ogni caso, un Claude senza strumenti e senza impostazioni riceve SOLO la skill più «Situazione» e
           «Compito per l'agente». Se il caso ha un «Materiale per l'esaminatore», l'esame è in due tempi: il
           materiale si consegna solo se la prima risposta dichiara la verifica che lo troverebbe.
giudica:   un giudice separato riceve il caso intero e la risposta e dà PASSA o NON PASSA punto per punto del
           «Criterio di successo». Verdetti in <caso>.verdetto.md, riepilogo in RIEPILOGO.md.
confronta: tabella caso per caso fra due giri (prima e dopo una modifica).

Modelli: METIS_BANCO_ESECUTORE (default opus), METIS_BANCO_GIUDICE (default fable, con ripiego su opus se il piano
non lo offre), METIS_BANCO_CONTROLLO (default sonnet). Il giudice conta più dell'esecutore per la costanza: il 6/10,
rigiudicando tre volte le stesse 29 risposte, opus ha cambiato verdetto su 6 casi, fable su 1. Ogni chiamata consuma la quota dell'abbonamento: un giro su 4 casi sono circa 10 chiamate.
"""
import argparse, concurrent.futures as cf, datetime, json, os, re, subprocess, sys, tempfile

RADICE = os.environ.get("METIS_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CL = os.environ.get("METIS_CL", "")
ESECUTORE = os.environ.get("METIS_BANCO_ESECUTORE", "opus")
GIUDICE = os.environ.get("METIS_BANCO_GIUDICE", "fable")
GIUDICE_RIPIEGO = "opus"
CONTROLLO_MODELLO = os.environ.get("METIS_BANCO_CONTROLLO", "sonnet")
SCRATCH = tempfile.mkdtemp(prefix="metis-banco-")

ISTRUZIONI_ESECUTORE = """Sei un agente che lavora sul vault Obsidian di un professionista (il cliente). Per questo compito
segui la skill riportata sotto. Non hai strumenti: non puoi leggere file né cercare nella posta. Se prima di scrivere
faresti una verifica (posta inviata, un file, un altro stato), dichiarala come passo esplicito, in ordine, e scrivi che
cosa faresti in ciascuno dei due esiti possibili. Rispondi al compito in modo completo: righe esatte da scrivere,
modificare o chiudere, e l'eventuale risposta al cliente. Scrivi in italiano."""

ISTRUZIONI_GIUDICE = """Sei il revisore avversariale. Giudichi la risposta di un agente a un caso del banco di prova.
Usa SOLO il «Criterio di successo» del caso (ed eventualmente il «Materiale per l'esaminatore»): un punto non scritto
nel criterio non conta, né a favore né contro. Per ogni punto del criterio dai PASSA o NON PASSA e cita la frase della
risposta che lo giustifica, o dichiara che manca. Se l'agente ha dichiarato una verifica senza poterla fare, valutala
come fatta se il criterio chiede di farla e l'agente ne trae le conseguenze giuste per l'esito indicato nel materiale.
Non addolcire. Chiudi con una riga esatta, l'ultima della risposta:
ESITO: PASSA            (tutti i punti passano)
ESITO: PARZIALE n/m     (passano n punti su m)
ESITO: NON PASSA        (nessun punto passa)"""

CONTROLLO = """Ti do un «materiale» di un caso d'esame, con la condizione alla quale va consegnato, e la risposta di un
agente. Domanda unica: la risposta DICHIARA di fare la verifica che la condizione richiede (anche come passo di un
piano, anche senza poterla eseguire)? Non giudicare nient'altro. Rispondi con una sola parola: SÌ oppure NO."""


def cartella_casi(skill, esempi):
    return os.path.join(RADICE, "banco", skill) if esempi else os.path.join(CL, "banco-skill", skill)


def cartella_esiti(skill, etichetta):
    base = os.path.join(CL, "banco-skill", skill) if CL else os.path.join(RADICE, "banco", skill)
    return os.path.join(base, "esiti", etichetta)


def sezioni(testo):
    """Sezioni «## Titolo» del caso. Le righe dentro i blocchi di codice (```) non aprono sezioni: le situazioni
    riportano spesso righe di stati che cominciano con «## Impegni»."""
    corpo = re.sub(r"^---\n.*?\n---\n", "", testo, count=1, flags=re.S)
    out, titolo, buf, codice = {}, None, [], False
    for riga in corpo.split("\n"):
        if riga.lstrip().startswith("```"):
            codice = not codice
        if not codice and riga.startswith("## "):
            if titolo is not None:
                out[titolo] = "\n".join(buf) + "\n"
            titolo, buf = riga[3:].strip(), []
        else:
            buf.append(riga)
    if titolo is not None:
        out[titolo] = "\n".join(buf) + "\n"
    return out


def casi(cartella, filtro=None):
    d = os.path.join(cartella, "casi")
    if not os.path.isdir(d):
        sys.exit("banco: nessuna cartella dei casi in %s" % d)
    ids = sorted(f[:-3] for f in os.listdir(d) if f.endswith(".md"))
    return [i for i in ids if not filtro or i in filtro]


def claude(prompt, modello, sessione=False, riprendi=None):
    """Claude headless isolato: nessuno strumento, nessuna impostazione, cartella vuota."""
    cmd = ["claude", "-p", "--tools", "", "--setting-sources", "", "--model", modello]
    if riprendi:
        cmd += ["--resume", riprendi]
    if sessione or riprendi:
        cmd += ["--output-format", "json"]
    r = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=SCRATCH, timeout=900)
    if not (sessione or riprendi):
        return r.stdout.strip() or "[ERRORE] %s" % r.stderr.strip()[:500]
    try:
        j = json.loads(r.stdout)
        return j.get("result", "").strip(), j.get("session_id")
    except Exception:
        return "[ERRORE] %s %s" % (r.stderr.strip()[:500], r.stdout[:300]), None


def esegui(a):
    skill_file = a.skill_file or os.path.join(RADICE, "skills", a.skill, "SKILL.md")
    testo_skill = open(skill_file, encoding="utf-8").read()
    origine = cartella_casi(a.skill, a.esempi)
    out = cartella_esiti(a.skill, a.etichetta)
    os.makedirs(out, exist_ok=True)
    json.dump({"skill_file": skill_file, "casi": origine, "data": datetime.datetime.now().isoformat(timespec="minutes"),
               "esecutore": ESECUTORE}, open(os.path.join(out, "giro.json"), "w"), ensure_ascii=False, indent=1)

    def uno(cid):
        s = sezioni(open(os.path.join(origine, "casi", cid + ".md"), encoding="utf-8").read())
        compito = s.get("Compito per l'agente", "")
        m = re.search(r"(?ms)^\**Materiale per l.esaminatore.*?(?=\n\s*\n|\Z)", s.get("Situazione", ""))
        materiale = m.group(0) if m else None
        situazione = s.get("Situazione", "").replace(materiale, "") if materiale else s.get("Situazione", "")
        assert "Materiale per l" not in situazione, cid
        prompt = "%s\n\n=== SKILL ===\n%s\n=== FINE SKILL ===\n\n## Situazione\n%s\n## Compito\n%s" % (
            ISTRUZIONI_ESECUTORE, testo_skill, situazione, compito)
        if not materiale:
            risposta = claude(prompt, ESECUTORE)
        else:
            primo, sid = claude(prompt, ESECUTORE, sessione=True)
            verdetto = claude("%s\n\n=== MATERIALE E CONDIZIONE ===\n%s\n=== RISPOSTA ===\n%s" % (CONTROLLO, materiale, primo),
                              CONTROLLO_MODELLO)
            if verdetto.strip().upper().startswith("S") and sid:
                dato = re.sub(r"(?s)^.*?:\s*", "", materiale.split("—", 1)[-1], count=1)
                secondo, _ = claude("Esito della verifica che hai dichiarato: " + dato +
                                    "\n\nOra scrivi la risposta definitiva al compito, con le righe esatte, senza varianti.",
                                    ESECUTORE, riprendi=sid)
                risposta = "%s\n\n---\n**[Secondo tempo: verifica dichiarata, materiale consegnato]**\n> %s\n\n%s" % (primo, dato, secondo)
            else:
                risposta = "%s\n\n---\n**[Secondo tempo: verifica non dichiarata (%s), materiale non consegnato]**" % (primo, verdetto[:20])
        open(os.path.join(out, cid + ".risposta.md"), "w", encoding="utf-8").write(risposta + "\n")
        return cid, len(risposta)

    with cf.ThreadPoolExecutor(a.paralleli) as ex:
        for cid, n in ex.map(uno, casi(origine, a.casi)):
            print("%s: %d caratteri" % (cid, n), flush=True)


def giudica(a):
    origine = cartella_casi(a.skill, a.esempi)
    out = cartella_esiti(a.skill, a.etichetta)
    ids = [f[:-len(".risposta.md")] for f in sorted(os.listdir(out)) if f.endswith(".risposta.md")]

    def uno(cid):
        caso = open(os.path.join(origine, "casi", cid + ".md"), encoding="utf-8").read()
        risp = open(os.path.join(out, cid + ".risposta.md"), encoding="utf-8").read()
        prompt = "%s\n\n=== CASO ===\n%s\n=== RISPOSTA DELL'AGENTE ===\n%s" % (ISTRUZIONI_GIUDICE, caso, risp)
        v = claude(prompt, GIUDICE)
        if v.startswith("[ERRORE]") and GIUDICE != GIUDICE_RIPIEGO:
            v = claude(prompt, GIUDICE_RIPIEGO) + "\n\n[giudice: %s, ripiego perché %s non ha risposto]" % (GIUDICE_RIPIEGO, GIUDICE)
        open(os.path.join(out, cid + ".verdetto.md"), "w", encoding="utf-8").write(v + "\n")
        m = re.findall(r"ESITO:\s*(PASSA|PARZIALE\s*\d+/\d+|NON PASSA)", v)
        return cid, m[-1] if m else "?"

    with cf.ThreadPoolExecutor(a.paralleli) as ex:
        esiti = list(ex.map(uno, ids))
    try:
        indice = open(os.path.join(origine, "INDICE.md"), encoding="utf-8").read()
    except OSError:
        indice = ""
    righe = ["| caso | mazzo | esito |", "|---|---|---|"]
    for cid, e in esiti:
        m = re.search(r"\[\[" + re.escape(cid) + r"\]\][^\n]*\| (modifica|tenuto) \|", indice)
        righe.append("| %s | %s | %s |" % (cid, m.group(1) if m else "?", e))
    tot = sum(1 for _, e in esiti if e == "PASSA")
    testo = "# Esito del giro «%s»\n\nSkill: `%s`. Passano %d casi su %d.\n\n%s\n" % (a.etichetta, a.skill, tot, len(esiti), "\n".join(righe))
    open(os.path.join(out, "RIEPILOGO.md"), "w", encoding="utf-8").write(testo)
    print(testo)


def confronta(a):
    def leggi(et):
        t = open(os.path.join(cartella_esiti(a.skill, et), "RIEPILOGO.md"), encoding="utf-8").read()
        return dict(re.findall(r"^\| ([a-z0-9-]+) \| [\w?]+ \| ([^|]+?) \|", t, re.M))
    x, y = leggi(a.etichetta), leggi(a.etichetta_b)
    for c in sorted(set(x) | set(y)):
        segno = "" if x.get(c) == y.get(c) else ("  ⬆" if y.get(c) == "PASSA" else "  ⬇" if x.get(c) == "PASSA" else "  ≠")
        print("%s: %-14s → %s%s" % (c, x.get(c, "-"), y.get(c, "-"), segno))


p = argparse.ArgumentParser(description="Banco di prova delle skill di Metis")
p.add_argument("azione", choices=["esegui", "giudica", "confronta"])
p.add_argument("skill"); p.add_argument("etichetta"); p.add_argument("etichetta_b", nargs="?")
p.add_argument("--esempi", action="store_true", help="usa i casi d'esempio del plugin")
p.add_argument("--skill-file"); p.add_argument("--casi", type=lambda s: set(s.split(",")))
p.add_argument("--paralleli", type=int, default=4)
a = p.parse_args()
{"esegui": esegui, "giudica": giudica, "confronta": confronta}[a.azione](a)
