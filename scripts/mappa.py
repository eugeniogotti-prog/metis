#!/usr/bin/env python3
"""mappa.py — mappa delle cartelle del cliente: inventario, fotografia giornaliera, confronto.

Uso (le variabili arrivano dalla configurazione, letta da scripts/lib/config.sh):
    python3 mappa.py            scrive <cartella di Claude>/mappa-inventario.md e le righe per il doctor
    python3 mappa.py --stdout   stampa l'inventario invece di scriverlo (fotografia e righe si scrivono comunque)

Che cosa fa (generalizzato il 3/10/2026 dallo script del vault di riferimento):
  a) lavori nella cartella del ruolo PROGETTI: numero di note, ultima attività, stato collegato; le aree (ruolo AREE)
     con le stesse colonne, senza la proposta d'archivio; con i documenti accanto alle note, i temi delle risorse;
  b) stati in <Claude>/stati/ con la cartella del lavoro (`fonte-primaria:`) e se esiste ancora;
  c) cartelle di primo livello delle radici fuori dal vault, con lo stato che le segue;
  d) archivio, in un file a parte (<Claude>/mappa-archivio.md, decisione del 3/10/2026): stati archiviati con
     oggetto, chiusura, persone e cartella del lavoro; lavori nella cartella ARCHIVIO; con le radici fuori dal vault,
     le loro cartelle di lavori chiusi e degli anni passati. Si consulta all'avvio di ogni lavoro nuovo per trovarne
     i precedenti;

Documenti accanto alle note (METIS_DOCUMENTI=accanto, default dal 23/10/2026): la cartella del lavoro è una sola, con
le note nella radice e i documenti in _IN/, _fonti/ e _OUT/. Queste sottocartelle (come ogni cartella che comincia con
«_») non sono lavori: non si elencano e non si fotografano a sé, ma i nomi dei loro file servono a riconoscere la
cartella del lavoro quando si sposta, e la data dei loro file conta come attività del lavoro. Le note si contano fuori
da esse. Con METIS_DOCUMENTI=separati i documenti stanno in METIS_FONTI, fuori dal vault, e la mappa li tratta come
radice a parte (sezione c).
  e) incoerenze, compresi i lavori fermi da oltre METIS_MAPPA_GIORNI_FERMO giorni;
  f) spostamenti: ogni giro salva una fotografia delle cartelle fino al secondo livello delle radici
     (<Claude>/cache/mappa-snapshot/AAAA-MM-GG.json, 30 giorni) e la confronta con la precedente:
     cartelle spostate o rinominate (riconosciute dai nomi dei file che contengono), sparite, nuove,
     lavori la cui cartella su disco non si trova più. Righe per il doctor in
     <Claude>/cache/mappa-spostamenti.txt («warn|testo» / «info|testo»).

Configurazione (tutte facoltative):
  METIS_MAPPA_RADICI        radici da fotografare, separate da «|»: relative al vault o assolute. Il segnaposto
                            {anno} vale l'anno corrente, o la cartella più recente se quella dell'anno non c'è ancora
                            (es. «~/Drive/{anno} attività in corso»).
                            Default con i documenti accanto alle note: cartelle PROGETTI, AREE, RISORSE e ARCHIVIO
                            (METIS_FONTI coincide con PROGETTI). Con METIS_DOCUMENTI=separati: cartella PROGETTI,
                            cartella ARCHIVIO, METIS_FONTI.
  METIS_MAPPA_CONTENITORI   nomi di cartelle di primo livello delle radici su disco i cui figli sono lavori
                            distinti, separati da «|» (oltre a quelle con almeno 10 sottocartelle).
  METIS_MAPPA_GIORNI_FERMO  giorni senza attività oltre i quali un lavoro è proposto per l'archivio (90).
  METIS_OGGI                data di oggi, solo per le prove.

Sola lettura su vault e disco, tranne i file generati. Non entra mai nella cartella riservata, nelle
cartelle nascoste, nella cartella di Claude (salvo stati) né in «node_modules». Solo libreria standard,
compatibile con /usr/bin/python3 3.9. Esce sempre con 0; l'ultima riga su stdout è il riepilogo per il doctor.
"""
import datetime
import json
import os
import re
import sys
import unicodedata


def nfc(s):
    return unicodedata.normalize("NFC", s)


def env(nome, default=""):
    return os.environ.get(nome, default)


VAULT = env("METIS_VAULT").rstrip("/")
CL = env("METIS_CL") or os.path.join(VAULT, env("METIS_RUOLO_CLAUDE", "_Claude"))
STATI = os.path.join(CL, "stati")
STATI_ARCH = os.path.join(STATI, "archivio")
FONTI = os.path.expanduser(env("METIS_FONTI")).rstrip("/")


def ruolo(r):
    v = env("METIS_RUOLO_" + r)
    return os.path.join(VAULT, v) if v else ""


PROGETTI = ruolo("PROGETTI")
AREE = ruolo("AREE")
RISORSE = ruolo("RISORSE")
PERSONE = ruolo("PERSONE")
ARCHIVIO = ruolo("ARCHIVIO")
RISERVATA = ruolo("RISERVATA")
OUT = os.path.join(CL, "mappa-inventario.md")
OUT_ARCH = os.path.join(CL, "mappa-archivio.md")
SNAP_DIR = os.path.join(CL, "cache", "mappa-snapshot")
SPOST_TXT = os.path.join(CL, "cache", "mappa-spostamenti.txt")
SNAP_GIORNI = 30
SOGLIA_RINOMINA = 0.6     # somiglianza (Jaccard) dei nomi dei file per dire «stessa cartella»
CAMPIONE_NOMI = 400
SOGLIA_CONTENITORE = 10
CONTENITORI = {nfc(x.strip()) for x in env("METIS_MAPPA_CONTENITORI").split("|") if x.strip()}
try:
    GIORNI_FERMO = int(env("METIS_MAPPA_GIORNI_FERMO", "90"))
except ValueError:
    GIORNI_FERMO = 90
try:
    TODAY = datetime.date.fromisoformat(env("METIS_OGGI")) if env("METIS_OGGI") else datetime.date.today()
except ValueError:
    TODAY = datetime.date.today()
DATE_RE = re.compile(r"(\d{4}-\d{2}-\d{2})")
SOTTO_LAVORO = {"_IN", "_fonti", "_OUT"}   # documenti del lavoro: ricevuti, fonti, consegnati


def _dentro_vault(p):
    return bool(VAULT and p) and (nfc(os.path.abspath(p)) + os.sep).startswith(nfc(VAULT) + os.sep)


# Documenti accanto alle note: dichiarato in configurazione (config.sh lo deduce per le installazioni vecchie); senza,
# vale «accanto» se la cartella fonti manca o sta nel vault.
DOCUMENTI = env("METIS_DOCUMENTI") or ("accanto" if not FONTI or _dentro_vault(FONTI) else "separati")
ACCANTO = DOCUMENTI != "separati"


def vietata(path):
    """Cartelle in cui non si entra: riservata e cartella di Claude."""
    p = nfc(os.path.abspath(path))
    for v in (RISERVATA, CL):
        if v and (p == nfc(v) or p.startswith(nfc(v) + os.sep)):
            return True
    return False


def saltare(nome, padre=""):
    if nome.startswith(".") or nome == "node_modules":
        return True
    return bool(padre) and vietata(os.path.join(padre, nome))


def leggi(path, limite=None):
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            return f.read(limite) if limite else f.read()
    except OSError:
        return ""


def frontmatter(testo):
    if not testo.startswith("---"):
        return {}
    fm = {}
    for r in testo.split("\n")[1:]:
        if r.strip() == "---":
            break
        m = re.match(r"^([A-Za-z0-9_\-]+):\s*(.*)$", r)
        if m:
            fm[m.group(1)] = re.sub(r"\s+#.*$", "", m.group(2)).strip()
    return fm


def data_da(valore):
    m = DATE_RE.search(valore or "")
    if not m:
        return None
    try:
        return datetime.date.fromisoformat(m.group(1))
    except ValueError:
        return None


def sottocartelle(path):
    try:
        return sorted(nfc(e) for e in os.listdir(path)
                      if not saltare(e, path) and not e.startswith("_") and os.path.isdir(os.path.join(path, e)))
    except OSError:
        return []


def cella(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


# ---------------------------------------------------------------- radici
def etichetta(path):
    """Nome stabile di una radice: relativo al vault se ci sta dentro, altrimenti col ~."""
    p = nfc(os.path.abspath(path))
    if VAULT and p.startswith(nfc(VAULT) + os.sep):
        return os.path.relpath(p, nfc(VAULT))
    casa = nfc(os.path.expanduser("~"))
    return "~" + p[len(casa):] if p.startswith(casa + os.sep) else p


def con_anno(voce):
    """Risolve il segnaposto {anno} in un percorso (6/10/2026): la cartella dell'anno corrente; se non c'è ancora (a
    gennaio, per esempio), la più recente che esiste. I nomi si confrontano in NFC, perché su Drive i nomi con accenti
    possono essere in NFD. Si restituisce il nome com'è sul disco. Una voce senza {anno} resta com'è."""
    if "{anno}" not in voce:
        return voce
    parti = voce.split(os.sep)
    i = next(k for k, x in enumerate(parti) if "{anno}" in x)
    padre = os.sep.join(parti[:i]) or os.sep
    rx = re.compile("^" + re.escape(nfc(parti[i])).replace(re.escape("{anno}"), r"(\d{4})") + "$")
    trovati = {}
    try:
        for n in os.listdir(padre):
            m = rx.match(nfc(n))
            if m:
                trovati[int(m.group(1))] = n
    except OSError:
        pass
    if not trovati:
        return voce.replace("{anno}", str(TODAY.year))
    anno = TODAY.year if TODAY.year in trovati else max(a for a in trovati if a <= TODAY.year) if any(a <= TODAY.year for a in trovati) else max(trovati)
    return os.sep.join(parti[:i] + [trovati[anno]] + parti[i + 1:])


def radici():
    """[(etichetta, percorso, su_disco)] delle radici da fotografare, solo quelle che esistono. Nelle voci di
    METIS_MAPPA_RADICI il segnaposto {anno} si risolve a ogni giro (con_anno): l'etichetta è quella risolta, quindi
    il passaggio d'anno compare come una radice nuova, non come cartelle sparite."""
    voci = [x.strip() for x in env("METIS_MAPPA_RADICI").split("|") if x.strip()]
    percorsi = []
    if voci:
        for v in voci:
            v = os.path.expanduser(v)
            v = v if os.path.isabs(v) else os.path.join(VAULT, v)
            percorsi.append(con_anno(v))
    else:
        percorsi = [p for p in ((PROGETTI, AREE, RISORSE, ARCHIVIO, FONTI) if ACCANTO else (PROGETTI, ARCHIVIO, FONTI)) if p]
    out, viste = [], set()
    for p in percorsi:
        p = os.path.abspath(p)
        if p in viste or not os.path.isdir(p) or vietata(p):
            continue
        viste.add(p)
        su_disco = not (VAULT and nfc(p).startswith(nfc(VAULT) + os.sep))
        out.append((etichetta(p), p, su_disco))
    return out


# ---------------------------------------------------------------- fonte-primaria
_indice = None


def indice_cartelle():
    """Cartelle fino a 4 livelli sotto le radici su disco, per i percorsi relativi a una base non dichiarata."""
    global _indice
    if _indice is None:
        _indice = []
        for _, r, su_disco in radici():
            if not su_disco:
                continue
            base = r.rstrip("/").count("/")
            for dp, dn, _ in os.walk(r):
                dn[:] = [d for d in dn if not saltare(d, dp)]
                if dp.count("/") - base >= 4:
                    dn[:] = []
                _indice.append(dp)
    return _indice


def risolvi(valore):
    """(esito, percorso): ✓ trovato, ≈ trovato solo cercandolo, ✗ non trovato."""
    quot = re.findall(r"'([^']+)'", valore) or re.findall(r'"([^"]+)"', valore)
    cand = (quot[0] if quot else valore.split(" (")[0]).strip().strip("`")
    if not cand:
        return "✗", ""
    p = os.path.expanduser(cand)
    if os.path.isabs(p):
        return ("✓", p) if os.path.exists(p) else ("✗", p)
    for base in (FONTI, VAULT):
        if base and os.path.exists(os.path.join(base, p)):
            return "✓", os.path.join(base, p)
    trovati = [os.path.join(d, p) for d in indice_cartelle() if os.path.exists(os.path.join(d, p))]
    if trovati:
        return "≈", trovati[0]
    return "✗", p


def corto(p):
    return etichetta(p) if os.path.isabs(p) else p


# ---------------------------------------------------------------- stati e lavori
def carica_stati(cartella):
    stati = []
    try:
        nomi = sorted(f for f in os.listdir(cartella) if f.endswith(".md") and not f.startswith("_"))
    except OSError:
        return stati
    for f in nomi:
        testo = nfc(leggi(os.path.join(cartella, f)))
        fm = frontmatter(testo)
        fp = fm.get("fonte-primaria", "").strip("'\"")
        esito, risolto = risolvi(fp) if fp else ("", "")
        m = re.search(r"^# (?:Stato — )?(.+)$", testo, re.M)
        titolo = (fm.get("name", "").strip("'\"") or (m.group(1).strip() if m else ""))
        chiuso = data_da(fm.get("chiuso")) or data_da(fm.get("updated_at")) or data_da(fm.get("ultima-mossa"))
        stati.append({"nome": nfc(f[:-3]), "testo": testo, "status": fm.get("status", ""),
                      "titolo": titolo, "chiuso": chiuso, "persone": fm.get("persone", ""),
                      "ultima": fm.get("ultima-mossa", "").strip("'\""), "fp": fp,
                      "fp_esito": esito, "fp_path": nfc(risolto)})
    return stati


def tokens(s):
    return {t for t in re.split(r"[^a-z0-9àèéìòù]+", nfc(s).lower()) if len(t) >= 2}


def cita(testo, prefisso, nome, fratelli=()):
    """True se il testo scrive il percorso prefisso/nome (una sorella con nome più lungo non conta)."""
    lunghi = [prefisso + "/" + f for f in fratelli if f != nome and f.startswith(nome)]
    pat = re.escape(prefisso + "/" + nome) + r"(?=[/`'\")\]|\s,;.]|$)"
    for m in re.finditer(pat, testo):
        if not any(testo.startswith(l, m.start()) for l in lunghi):
            return True
    return False


def scan_lavoro(path):
    """(note, (data, origine)) di una cartella di lavoro. Le note si contano fuori da _IN, _fonti e _OUT; dentro, i
    file sono documenti e la loro data di modifica conta come attività («doc»)."""
    n, best = 0, None
    for dp, dn, fn in os.walk(path):
        dn[:] = [d for d in dn if not saltare(d, dp)]
        rel = os.path.relpath(dp, path)
        documenti = rel != "." and rel.split(os.sep)[0] in SOTTO_LAVORO
        for f in fn:
            if documenti:
                if f.startswith("."):
                    continue
                try:
                    cand = (datetime.date.fromtimestamp(os.path.getmtime(os.path.join(dp, f))), "doc")
                except OSError:
                    continue
                if cand[0] <= TODAY and (best is None or cand[0] > best[0]):
                    best = cand
                continue
            if not f.endswith(".md"):
                continue
            n += 1
            full = os.path.join(dp, f)
            fm = frontmatter(leggi(full, 6000))
            dfm = [d for d in (data_da(fm.get("created_at")), data_da(fm.get("updated_at"))) if d and d <= TODAY]
            if dfm:
                cand = (max(dfm), "fm")
            else:
                try:
                    cand = (datetime.date.fromtimestamp(os.path.getmtime(full)), "mtime")
                except OSError:
                    continue
            if best is None or cand[0] > best[0]:
                best = cand
    return n, best


def stati_del_lavoro(nome, path, stati, fratelli):
    tp = tokens(nome)
    per_nome = [s["nome"] for s in stati if tokens(s["nome"]) and
                (tokens(s["nome"]) <= tp or (len(tp) >= 2 and tp <= tokens(s["nome"])))]
    if per_nome:
        return per_nome, "nome"
    pref = etichetta(PROGETTI)
    cit = [s["nome"] for s in stati if cita(s["testo"], pref, nome, fratelli)
           or (s["fp_path"] and (s["fp_path"] == nfc(path) or s["fp_path"].startswith(nfc(path) + os.sep)))]
    return (cit, "citazione") if cit else ([], "")


# ---------------------------------------------------------------- fotografia e confronto
def fotografa():
    foto = {}
    for etich, radice, _ in radici():
        for d1 in sottocartelle(radice):
            p1 = os.path.join(radice, d1)
            k1 = etich + "/" + d1
            nomi = {k1: set()}
            for d2 in sottocartelle(p1):
                nomi[k1 + "/" + d2] = set()
            for dp, dn, fn in os.walk(p1):
                dn[:] = [d for d in dn if not saltare(d, dp)]
                rel = os.path.relpath(dp, p1)
                k2 = None
                if rel != ".":
                    primo = nfc(rel.split(os.sep)[0])
                    if (k1 + "/" + primo) in nomi:
                        k2 = k1 + "/" + primo
                for f in fn:
                    if f.startswith("."):
                        continue
                    f = nfc(f)
                    nomi[k1].add(f)
                    if k2:
                        nomi[k2].add(f)
            for k, v in nomi.items():
                foto[k] = sorted(v)[:CAMPIONE_NOMI]
    return foto


def ultima_foto():
    try:
        nomi = sorted(f for f in os.listdir(SNAP_DIR) if re.match(r"\d{4}-\d{2}-\d{2}\.json$", f))
    except OSError:
        return None, None
    prec = [f for f in nomi if f[:10] < TODAY.isoformat()]
    if not prec:
        return None, None
    try:
        with open(os.path.join(SNAP_DIR, prec[-1]), encoding="utf-8") as f:
            return prec[-1][:10], json.load(f)
    except (OSError, ValueError):
        return None, None


def salva_foto(dati):
    try:
        os.makedirs(SNAP_DIR, exist_ok=True)
        tmp = os.path.join(SNAP_DIR, TODAY.isoformat() + ".json.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(dati, f, ensure_ascii=False)
        os.replace(tmp, os.path.join(SNAP_DIR, TODAY.isoformat() + ".json"))
        limite = (TODAY - datetime.timedelta(days=SNAP_GIORNI)).isoformat()
        for f in os.listdir(SNAP_DIR):
            if re.match(r"\d{4}-\d{2}-\d{2}\.json$", f) and f[:10] < limite:
                os.remove(os.path.join(SNAP_DIR, f))
    except OSError:
        pass


def jaccard(a, b):
    a, b = set(a), set(b)
    if not a or not b:
        return 0.0
    return len(a & b) / float(len(a | b))


def sotto(k, padri):
    return any(k.startswith(p + "/") for p in padri)


def confronta(vecchia, nuova):
    """(spostate [(da, a)], sparite [k], comparse [k]), con i figli delle cartelle già elencate tolti."""
    vk, nk = set(vecchia), set(nuova)
    sparite = sorted(vk - nk, key=lambda k: (k.count("/"), k))
    comparse = sorted(nk - vk, key=lambda k: (k.count("/"), k))
    spostate, usate = [], set()
    for s in sparite:
        if sotto(s, [a for a, _ in spostate]):
            continue
        # A parità di somiglianza vince la cartella con lo stesso nome, poi la più profonda: un lavoro spostato
        # in una cartella d'anno nuova («Archivio/2026/X») somiglia per intero anche alla cartella dell'anno.
        migliore, punteggio, chiave = None, 0.0, None
        for c in comparse:
            if c in usate or sotto(c, [b for _, b in spostate]):
                continue
            j = jaccard(vecchia[s], nuova[c])
            k = (j, c.rsplit("/", 1)[-1] == s.rsplit("/", 1)[-1], c.count("/"))
            if j > 0 and (chiave is None or k > chiave):
                migliore, punteggio, chiave = c, j, k
        if migliore and punteggio >= SOGLIA_RINOMINA:
            spostate.append((s, migliore))
            usate.add(migliore)
    da = [a for a, _ in spostate]
    a_ = [b for _, b in spostate]
    sparite = [k for k in sparite if k not in da and not sotto(k, da)]
    comparse = [k for k in comparse if k not in a_ and not sotto(k, a_)]
    sparite = [k for k in sparite if not sotto(k, sparite)]
    comparse = [k for k in comparse if not sotto(k, comparse)]
    return spostate, sparite, comparse


def relativa(chiave):
    """Parte di una chiave della fotografia dopo l'etichetta della sua radice."""
    for etich, _, _ in radici():
        if chiave.startswith(etich + "/"):
            return chiave[len(etich) + 1:]
    return ""


def assoluto(chiave):
    """Percorso assoluto di una chiave della fotografia («etichetta/cartella»)."""
    for etich, r, _ in radici():
        if chiave == etich or chiave.startswith(etich + "/"):
            return os.path.join(r, chiave[len(etich) + 1:])
    return ""


# ---------------------------------------------------------------- main
def main():
    stdout_only = "--stdout" in sys.argv
    if not VAULT or not os.path.isdir(VAULT):
        print("mappa: vault non configurato")
        return
    stati = carica_stati(STATI)
    stati_arch = carica_stati(STATI_ARCH)
    incoerenze = []

    # a) lavori nella cartella PROGETTI
    lavori = []
    nomi = sottocartelle(PROGETTI) if PROGETTI else []
    for nome in nomi:
        path = os.path.join(PROGETTI, nome)
        n, best = scan_lavoro(path)
        coll, come = stati_del_lavoro(nome, path, stati, nomi)
        lavori.append({"nome": nome, "n": n, "best": best, "stati": coll, "come": come})
        if best and (TODAY - best[0]).days > GIORNI_FERMO:
            incoerenze.append(("Lavori fermi da oltre %d giorni (proposte per l'archivio)" % GIORNI_FERMO,
                               "%s — ultima attività %s, %d note" % (nome, best[0].isoformat(), n)))

    # a2) aree: stesse colonne dei lavori, senza la proposta d'archivio (una responsabilità continuativa non si chiude)
    aree = []
    nomi_aree = sottocartelle(AREE) if AREE and nfc(AREE) != nfc(PROGETTI) else []
    for nome in nomi_aree:
        path = os.path.join(AREE, nome)
        n, best = scan_lavoro(path)
        coll, come = stati_del_lavoro(nome, path, stati, nomi_aree)
        aree.append({"nome": nome, "n": n, "best": best, "stati": coll, "come": come})

    # a3) risorse, con i documenti accanto alle note: temi e sottotemi delle fonti comuni, con il README del tema
    risorse = []
    if ACCANTO and RISORSE and os.path.isdir(RISORSE):
        for tema in sottocartelle(RISORSE):
            pt = os.path.join(RISORSE, tema)
            if PERSONE and os.path.realpath(pt) == os.path.realpath(PERSONE):
                continue   # la cartella delle persone è un ruolo a sé, non un tema delle fonti
            nfile = 0
            for dp, dn, fn in os.walk(pt):
                dn[:] = [d for d in dn if not saltare(d, dp)]
                nfile += sum(1 for f in fn if not f.startswith(".") and f != "README.md")
            risorse.append((tema, sottocartelle(pt), nfile, os.path.isfile(os.path.join(pt, "README.md"))))

    # b) stati
    for s in stati:
        if s["fp"] and s["fp_esito"] == "✗":
            incoerenze.append(("Cartella del lavoro indicata da uno stato e non trovata", "%s → %s" % (s["nome"], s["fp_path"])))

    # c) radici su disco
    seguiti = [(s["nome"], s["fp_path"]) for s in stati + stati_arch if s["fp_esito"] in ("✓", "≈")]
    righe_disco = []
    for etich, r, su_disco in radici():
        if not su_disco:
            continue
        base = os.path.basename(r)
        prime = sottocartelle(r)
        for nome in prime:
            p = nfc(os.path.join(r, nome))
            subs = sottocartelle(p)
            cont = nome in CONTENITORI or len(subs) >= SOGLIA_CONTENITORE
            figli = [(nome + "/" + x, nfc(os.path.join(p, x))) for x in subs] if cont else []
            for rel, pp in [(nome, p)] + figli:
                chi = sorted({n for n, fp in seguiti if fp == pp or fp.startswith(pp + os.sep)}
                             | {s["nome"] for s in stati + stati_arch if cita(s["testo"], base, rel)})
                righe_disco.append((etich, rel, cont and rel == nome, chi))
                if not chi and not (cont and rel == nome) and recente(pp):
                    incoerenze.append(("Cartelle su disco toccate negli ultimi %d giorni che nessun lavoro segue" % GIORNI_FERMO,
                                       "%s/%s" % (etich, rel)))

    # d) archivio: file a parte, da consultare all'avvio di ogni lavoro nuovo
    n_arch = genera_archivio(stati_arch, righe_disco, stdout_only)

    # f) spostamenti
    foto_nuova = {"cartelle": fotografa(), "radici": [e for e, _, _ in radici()],
                  "fp": {s["nome"]: [s["fp_esito"], s["fp_path"]] for s in stati if s["fp"]}}
    data_prec, foto_prec = ultima_foto()
    righe = []
    if foto_prec:
        # Radici cambiate (passaggio d'anno di una voce con {anno}, o configurazione cambiata): le loro cartelle non si
        # confrontano una per una, altrimenti un anno nuovo sembrerebbe un anno intero di cartelle sparite.
        vecchie_r = foto_prec.get("radici")
        if vecchie_r is None:   # fotografie di prima del 6/10/2026: radici ricavate dalle chiavi
            vecchie_r = sorted({k.rsplit("/", 1)[0] for k in foto_prec.get("cartelle", {}) if "/" in k})
        nuove_r = foto_nuova["radici"]
        tolte = [r_ for r_ in vecchie_r if r_ not in nuove_r and not any(r_.startswith(n + "/") for n in nuove_r)]
        aggiunte = [r_ for r_ in nuove_r if r_ not in vecchie_r and foto_prec.get("radici") is not None]
        fuori = lambda k, rr: any(k == r_ or k.startswith(r_ + "/") for r_ in rr)
        vecchia = {k: v for k, v in foto_prec.get("cartelle", {}).items() if not fuori(k, tolte)}
        nuova = {k: v for k, v in foto_nuova["cartelle"].items() if not fuori(k, aggiunte)}
        for r_ in aggiunte:
            righe.append(("info", "Radice nuova: `%s`%s" % (r_, (" (al posto di `%s`)" % tolte[0]) if len(tolte) == 1 and len(aggiunte) == 1 else "")))
        for r_ in tolte:
            if not (len(tolte) == 1 and len(aggiunte) == 1):
                righe.append(("info", "Radice non più fotografata: `%s`" % r_))
        spostate, sparite, comparse = confronta(vecchia, nuova)
        seguite = {r_[0] + "/" + r_[1] for r_ in righe_disco if r_[3]}
        seguite |= {etichetta(PROGETTI) + "/" + l["nome"] for l in lavori if l["stati"]}
        # «nessun lavoro la segue» vale per le cartelle dei lavori: progetti e radici fuori dal vault, non aree,
        # risorse e archivio, che non hanno uno stato per cartella.
        da_seguire = {etichetta(PROGETTI)} | {e for e, _, su in radici() if su}
        for a, b in spostate:
            righe.append(("info", "Cartella spostata o rinominata: `%s` → `%s`" % (a, b)))
        for k in sparite:
            righe.append(("info", "Cartella sparita (non ritrovata altrove): `%s`" % k))
        for k in comparse:
            rel = relativa(k)
            nota = " — nessun lavoro la segue" if rel and "/" not in rel and k not in seguite and k[:-len(rel) - 1] in da_seguire else ""
            righe.append(("info", "Cartella nuova: `%s`%s" % (k, nota)))
        fp_prec = foto_prec.get("fp", {})
        for nome, (esito, percorso) in sorted(foto_nuova["fp"].items()):
            vecchio = fp_prec.get(nome)
            if esito == "✗" and vecchio and vecchio[0] in ("✓", "≈"):
                sugg = ""
                for a, b in spostate:
                    pa, pb = assoluto(a), assoluto(b)
                    if pa and pb and (vecchio[1] == pa or vecchio[1].startswith(pa + os.sep)):
                        sugg = " — forse ora è `%s`" % corto(pb + vecchio[1][len(pa):])
                righe.append(("warn", "Lavoro [[%s]]: la cartella del lavoro `%s` non si trova più%s"
                              % (nome, corto(vecchio[1]), sugg)))
    salva_foto(foto_nuova)
    try:
        os.makedirs(os.path.dirname(SPOST_TXT), exist_ok=True)
        with open(SPOST_TXT, "w", encoding="utf-8") as f:
            for liv, t in righe:
                f.write("%s|%s\n" % (liv, t))
    except OSError:
        pass

    # scrittura dell'inventario
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    fermi = [t for c, t in incoerenze if c.startswith("Lavori fermi")]
    L = ["---", "created_at: %s" % TODAY.isoformat(), "tags:", "- tipo/indice", "up:", "- '[[_Claude]]'",
         "updated_at: %s" % TODAY.isoformat(), "---", "",
         "<!-- FILE GENERATO da mappa.py — non modificare a mano. Generato il %s -->" % ts, "",
         "# Mappa — inventario generato", "",
         "*Generato il %s dal doctor. Radici: %s.*" % (ts, ", ".join("`%s`" % e for e, _, _ in radici()) or "nessuna"), "",
         "**%d lavori · %d stati attivi · %d incoerenze**" % (len(lavori), len(stati), len(incoerenze)), ""]
    if ACCANTO:
        L += ["Documenti accanto alle note: ogni lavoro ha una sola cartella, con le note nella radice e i documenti in "
              "`_IN/`, `_fonti/` e `_OUT/`. Le note si contano fuori da queste sottocartelle; la data dei documenti conta "
              "come attività (`doc`).", ""]
    L += ["## Lavori in «%s»" % (etichetta(PROGETTI) if PROGETTI else "—"), "",
          "Ultima attività: la data più recente fra `created_at` e `updated_at` delle note (`fm`), altrimenti la data di modifica del file (`mtime`).", "",
          "| Lavoro | Note | Ultima attività | Stato collegato |", "|---|---:|---|---|"]
    for l in lavori:
        best = "%s (%s)" % (l["best"][0].isoformat(), l["best"][1]) if l["best"] else "—"
        st = ", ".join("[[%s]]" % s for s in l["stati"][:4])
        L.append("| %s | %d | %s | %s |" % (cella(l["nome"]), l["n"], best, cella(st + (" (%s)" % l["come"] if st else ""))))
    if aree:
        L += ["", "## Aree in «%s»" % etichetta(AREE), "", "| Area | Note | Ultima attività | Stato collegato |", "|---|---:|---|---|"]
        for l in aree:
            best = "%s (%s)" % (l["best"][0].isoformat(), l["best"][1]) if l["best"] else "—"
            st = ", ".join("[[%s]]" % s for s in l["stati"][:4])
            L.append("| %s | %d | %s | %s |" % (cella(l["nome"]), l["n"], best, cella(st + (" (%s)" % l["come"] if st else ""))))
    if risorse:
        L += ["", "## Risorse in «%s»" % etichetta(RISORSE), "",
              "Fonti che servono a più lavori, per tema e sottotema; i `_fonti/` dei lavori rimandano qui senza copiare.", "",
              "| Tema | Sottotemi | File | README |", "|---|---|---:|---|"]
        for tema, subs, nfile, readme in risorse:
            L.append("| %s | %s | %d | %s |" % (cella(tema), cella(", ".join(subs)) or "—", nfile, "sì" if readme else "**manca**"))
    L += ["", "## Stati attivi", "", "| Stato | status | ultima-mossa | cartella del lavoro | Esiste |", "|---|---|---|---|---|"]
    for s in stati:
        L.append("| [[%s]] | %s | %s | %s | %s |" % (cella(s["nome"]), cella(s["status"] or "—"), cella(s["ultima"] or "—"),
                                                     cella("`%s`" % corto(s["fp_path"]) if s["fp"] else "—"), s["fp_esito"] or "—"))
    if righe_disco or not ACCANTO:
        L += ["", "## Cartelle su disco", "", "| Radice | Cartella | Seguita da |", "|---|---|---|"]
        for etich, rel, cont, chi in righe_disco:
            L.append("| %s | %s | %s |" % (cella(etich), cella(("**%s** (contenitore)" % rel) if cont else rel),
                                           cella(", ".join("[[%s]]" % x for x in chi)) or "nessuno"))
    L += ["", "## Archivio", "",
          "Lavori chiusi, con i loro documenti, e stati archiviati: [[mappa-archivio]] (%d stati archiviati, %d lavori archiviati)."
          % (len(stati_arch), n_arch), "", "## Spostamenti dall'ultima passata", ""]
    if not foto_prec:
        L.append("Prima fotografia delle cartelle: il confronto parte dalla prossima passata.")
    elif not righe:
        L.append("Nessuno spostamento rispetto alla fotografia del %s." % data_prec)
    else:
        L.append("Rispetto alla fotografia del %s:" % data_prec)
        L.append("")
        L += ["- " + ("⚠️ " if liv == "warn" else "") + t for liv, t in righe]
    L += ["", "## Incoerenze", ""]
    if not incoerenze:
        L.append("Nessuna.")
    else:
        cats = []
        for c, _ in incoerenze:
            if c not in cats:
                cats.append(c)
        for c in cats:
            voci = [t for cc, t in incoerenze if cc == c]
            L += ["### %s (%d)" % (c, len(voci)), ""] + ["- " + t for t in voci] + [""]
    L.append("<!-- fine file generato -->")
    md = "\n".join(L) + "\n"
    if stdout_only:
        sys.stdout.write(md)
    else:
        try:
            with open(OUT + ".tmp", "w", encoding="utf-8") as f:
                f.write(md)
            os.replace(OUT + ".tmp", OUT)
        except OSError as e:
            print("mappa: ERRORE nella scrittura di %s: %s" % (OUT, e))
            return
    nwarn = sum(1 for liv, _ in righe if liv == "warn")
    print("mappa: %d lavori · %d stati · %d fermi da oltre %d giorni · %s"
          % (len(lavori), len(stati), len(fermi), GIORNI_FERMO,
             ("%d spostamenti dal %s (%d lavori scollegati)" % (len(righe), data_prec, nwarn)) if foto_prec
             else "prima fotografia delle cartelle"))


def persone_brevi(v):
    return ", ".join(re.findall(r"\[\[([^\]|]+)", v)) or "—"


def genera_archivio(stati_arch, righe_disco, stdout_only):
    """Scrive <Claude>/mappa-archivio.md: stati archiviati, lavori nell'archivio del vault e, con radici fuori dal
    vault, le loro cartelle di lavori chiusi. Si consulta all'avvio di ogni lavoro nuovo per trovare i precedenti. Ritorna i lavori archiviati."""
    lavori = []   # (gruppo, nome, note, ultima attività, stati)
    if ARCHIVIO and os.path.isdir(ARCHIVIO):
        for d in sottocartelle(ARCHIVIO):
            p = os.path.join(ARCHIVIO, d)
            figli = [(d, x, os.path.join(p, x)) for x in sottocartelle(p)] if re.match(r"^\d{4}$", d) else [("", d, p)]
            for gruppo, nome, path in figli:
                n, best = scan_lavoro(path)
                fili, _ = stati_del_lavoro(nome, path, stati_arch, [])
                lavori.append((gruppo, nome, n, best, fili))
    chiusi = sorted({e + "/" + r for e, r, _, chi in righe_disco
                     if chi and all(c in {s["nome"] for s in stati_arch} for c in chi)})
    fuori = any(su for _, _, su in radici())
    anni_disco = []
    for etich, r, su_disco in radici():
        if su_disco:
            for d in sottocartelle(r):
                if re.match(r"^\d{4}\b", d) and int(d[:4]) < TODAY.year:
                    anni_disco.append((etich + "/" + d, sottocartelle(os.path.join(r, d))))
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    L = ["---", "created_at: %s" % TODAY.isoformat(), "tags:", "- tipo/indice", "up:", "- '[[_Claude]]'",
         "updated_at: %s" % TODAY.isoformat(), "---", "",
         "<!-- FILE GENERATO da mappa.py — non modificare a mano. Generato il %s -->" % ts, "",
         "# Mappa — archivio", "",
         "*Generato il %s dal doctor. Le cose in corso sono in [[mappa-inventario]]. **Da consultare all'avvio di ogni "
         "lavoro nuovo**: stesso cliente, stesso tema, stesse persone → precedente da scrivere in `precedenti:` "
         "nello stato del lavoro nuovo.*" % ts, "",
         "**%d stati archiviati · %d lavori nell'archivio del vault%s**"
         % (len(stati_arch), len(lavori), (" · %d cartelle su disco di lavori chiusi" % len(chiusi)) if fuori else ""), "",
         "## Stati archiviati", "", "| Lavoro | Oggetto | Chiuso | Persone | Cartella del lavoro |", "|---|---|---|---|---|"]
    for s in sorted(stati_arch, key=lambda x: x["chiuso"] or datetime.date.min, reverse=True):
        L.append("| [[%s]] | %s | %s | %s | %s |" % (cella(s["nome"]), cella(s["titolo"] or "—"),
                 s["chiuso"].isoformat() if s["chiuso"] else "—", cella(persone_brevi(s["persone"])),
                 cella("`%s`" % corto(s["fp_path"])) if s["fp_path"] else "—"))
    L += ["", "## Lavori nell'archivio del vault («%s»)" % (etichetta(ARCHIVIO) if ARCHIVIO else "—"), "",
          ] + (["Ogni cartella contiene il lavoro intero: le note e i documenti in `_IN/`, `_fonti/` e `_OUT/`.", ""] if ACCANTO else []) + [
          "| Anno | Cartella | Note | Ultima attività | Stato archiviato |", "|---|---|---:|---|---|"]
    for gruppo, nome, n, best, fili in lavori:
        L.append("| %s | %s | %d | %s | %s |" % (gruppo or "—", cella(nome), n, best[0].isoformat() if best else "—",
                                                cella(", ".join("[[%s]]" % f for f in fili)) or "—"))
    if fuori:
        L += ["", "## Cartelle su disco di lavori chiusi", "",
              "Restano dove sono: lo stato archiviato le indica in `fonte-primaria:`.", ""]
        L += ["- `%s`" % c for c in chiusi] or ["Nessuna."]
    if anni_disco:
        L += ["", "## Cartelle su disco degli anni passati", ""]
        L += ["**%s (%d):** %s" % (k, len(v), " · ".join(v) or "—") for k, v in anni_disco]
    L += ["", "<!-- fine file generato -->"]
    if not stdout_only:
        try:
            with open(OUT_ARCH + ".tmp", "w", encoding="utf-8") as f:
                f.write("\n".join(L) + "\n")
            os.replace(OUT_ARCH + ".tmp", OUT_ARCH)
        except OSError:
            pass
    return len(lavori)


def recente(path):
    try:
        mt = max([os.path.getmtime(path)] + [os.path.getmtime(os.path.join(path, e))
                                              for e in os.listdir(path) if not e.startswith(".")])
    except OSError:
        return False
    return (TODAY - datetime.date.fromtimestamp(mt)).days <= GIORNI_FERMO


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # lo script non deve mai far fallire chi lo lancia
        print("mappa: ERRORE %s: %s" % (type(e).__name__, e))
    sys.exit(0)
