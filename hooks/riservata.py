#!/usr/bin/env python3
"""riservata.py — la parte della guardia (guardia.sh) che decide sui percorsi protetti. Stampa «nega» (cartella
riservata), «ricerca» (una ricerca ricorsiva che la attraversa senza escluderla) o «segreto» (file delle credenziali di
Metis e dei suoi server: token di Claude, del bot, chiave Groq, posta, rclone); niente se lascia passare.

Uso: riservata.py <strumento> <cwd> <vault> <cartella riservata o vuoto> dentro|fuori
     evento JSON in $GUARDIA_EVENTO; cartelle dei segreti in $GUARDIA_SEGRETI (separate da «:»); cartella del plugin
     in $METIS_ROOT (i suoi script possono ricevere quei percorsi: li leggono per conto loro, senza mostrarli)
  dentro  la sessione è del vault: tutti i controlli;
  fuori   un'altra cartella del Mac: solo i percorsi che portano davvero nella cartella riservata del vault.

Perché non un confronto di stringhe (rilievo della revisione di sicurezza del 15/11/2026): la shell arriva alla stessa
cartella con virgolette («"_Privato"/x»), caratteri jolly («_Privat?»), maiuscole diverse (il disco del Mac non le
distingue), collegamenti simbolici, «cd _Privato && cat x». Qui il comando si scompone in parole come fa la shell
(virgolette e barre rovesciate tolte), ogni parola si risolve come percorso (realpath, quindi anche i collegamenti),
i caratteri jolly si espandono, e i confronti si fanno senza maiuscole. Un nome nominato come esclusione di una ricerca
(--exclude-dir=, -not -path, rg -g '!…') conta come esclusione solo se copre davvero la cartella.
Limiti dichiarati: variabili e sostituzioni costruite a pezzi ($A$B, $'\\x5f…') e programmi che aprono file per conto
loro (python3 -c, node -e) non si risolvono; la difesa lì restano le regole deny di Read e la regola scritta.
"""
import fnmatch, glob, json, os, re, shlex, sys, unicodedata

tool, cwd, vault, ris, modo = sys.argv[1:6]
try:
    evento = json.loads(os.environ.get("GUARDIA_EVENTO", "") or "{}")
except Exception:
    evento = {}
ti = evento.get("tool_input") or {}
cwd = cwd or os.getcwd()
ris = ris.strip("/")


def n(s):   # forma di confronto: Unicode composto e senza maiuscole (APFS non le distingue)
    return unicodedata.normalize("NFC", s).casefold()


RA = n(os.path.realpath(os.path.join(vault, ris))) if ris else ""
RN = n(ris)
RC = RN.split("/")
JOLLY = re.compile(r"[*?\[]")
SEGRETI = [n(os.path.realpath(os.path.expanduser(x))) for x in os.environ.get("GUARDIA_SEGRETI", "").split(":") if x.strip()]
ROOT = n(os.path.realpath(os.environ.get("METIS_ROOT", "") or "/nessuna-cartella"))


def dentro_ris(p):
    q = n(p)
    return bool(RA) and (q == RA or q.startswith(RA + "/"))


def segreto(parola):
    """Vero se la parola, come percorso (anche con collegamenti o caratteri jolly), porta in un file dei segreti."""
    if not SEGRETI or not parola or len(parola) > 4096:
        return False
    p = os.path.expanduser(parola)
    base = p if os.path.isabs(p) else os.path.join(cwd, p)
    cand = [base]
    if JOLLY.search(p):
        try:
            cand += glob.glob(base)[:500]
        except Exception:
            pass
    for c in cand:
        q = n(os.path.realpath(c))
        if any(q == s or q.startswith(s.rstrip("/") + "/") for s in SEGRETI):
            return True
    return False


def risolve(parola):
    """Vero se la parola, come percorso, porta nella cartella riservata (anche per collegamento o caratteri jolly)."""
    if not parola or len(parola) > 4096:
        return False
    p = os.path.expanduser(parola)
    base = p if os.path.isabs(p) else os.path.join(cwd, p)
    if dentro_ris(os.path.realpath(base)):
        return True
    if JOLLY.search(p):
        try:
            for g in glob.glob(base)[:500]:
                if dentro_ris(os.path.realpath(g)):
                    return True
        except Exception:
            pass
    return False


def nomina(parola):
    """Vero se la parola nomina la cartella come componente di un percorso, anche con caratteri jolly («_Privat?»,
    «*_Privato*») o in un'opzione («--file=_Privato/x»)."""
    w = n(parola)
    if w.startswith("-") and "=" in w:
        w = w.split("=", 1)[1]
    comp = [c for c in w.split("/") if c]
    for i in range(len(comp) - len(RC) + 1):
        if all(c == r or (JOLLY.search(c) and fnmatch.fnmatchcase(r, c)) for c, r in zip(comp[i:i + len(RC)], RC)):
            return True
    if JOLLY.search(w) and re.sub(r"[*?\[\]/!]", "", w):      # un modello con almeno un carattere vero
        for prova in (RN, RN + "/x", "./" + RN + "/x", RA, RA + "/x"):
            if fnmatch.fnmatchcase(prova, w):
                return True
    return False


def tocca(parola):
    if not ris:
        return False
    return risolve(parola) or (modo == "dentro" and nomina(parola))


# --- strumenti che non sono la shell --------------------------------------------------------------------------------
if tool != "Bash":
    def stringhe(x, chiave=""):
        if isinstance(x, str):
            yield chiave, x
        elif isinstance(x, dict):
            for k, v in x.items():
                yield from stringhe(v, k)
        elif isinstance(x, list):
            for v in x:
                yield from stringhe(v, chiave)
    for k, s in stringhe(ti):
        if k in ("file_path", "path", "notebook_path", "directory", "cwd"):
            if tocca(s):
                print("nega"); sys.exit(0)
            if segreto(s):
                print("segreto"); sys.exit(0)
        elif not ris:
            continue
        else:   # testo libero: le forme di prima (percorso assoluto, «nome/», nome in fondo), senza maiuscole e virgolette
            t = n(s.replace('"', "").replace("'", "").replace("\\", ""))
            if RA in t or (modo == "dentro" and (RN + "/" in t or t.endswith(RN))):
                print("nega"); sys.exit(0)
    sys.exit(0)

# --- la shell -------------------------------------------------------------------------------------------------------
cmd = ti.get("command", "") if isinstance(ti, dict) else ""
if not cmd:
    sys.exit(0)
SEP = set(";&|()<>$")


def parole_di(testo):
    try:
        lx = shlex.shlex(testo, posix=True, punctuation_chars=True)
        lx.whitespace_split = True
        return list(lx)
    except ValueError:      # virgolette non chiuse: si tolgono e si spezza sugli spazi
        return re.sub(r"[\"'\\]", "", testo).split()


def comandi_di(testo, prof=0):
    """Comandi semplici della riga, con le parole già pulite; «bash -c '…'» ed «eval '…'» si aprono."""
    out, cur = [], []
    for p in parole_di(testo):
        p = p.strip("`")
        if not p:
            continue
        if set(p) <= SEP:
            out.append(cur); cur = []
            continue
        cur.append(p)
    out.append(cur)
    finale = []
    for c in out:
        if not c:
            continue
        b = os.path.basename(c[0])
        if prof < 3 and b in ("bash", "sh", "zsh", "dash") and "-c" in c[1:] and c.index("-c") + 1 < len(c):
            finale += comandi_di(c[c.index("-c") + 1], prof + 1)
        elif prof < 3 and b == "eval" and len(c) > 1:
            finale += comandi_di(" ".join(c[1:]), prof + 1)
        else:
            finale.append(c)
    return finale


def svolgi(c):
    """Toglie gli involucri davanti al comando vero: con-timeout.sh SECONDI, bash/sh <script>, env VAR=…, nice,
    command, time, nohup, xargs (6/10/2026; xargs dal 15/11)."""
    while c:
        b = os.path.basename(c[0])
        if b in ("bash", "sh", "zsh") and len(c) > 1 and os.path.basename(c[1]) == "con-timeout.sh":
            c = c[3:]
        elif b == "con-timeout.sh":
            c = c[2:]
        elif b in ("env", "nice", "command", "time", "nohup", "xargs", "builtin", "exec"):
            c = c[1:]
            while c and ("=" in c[0] and not c[0].startswith("-") or c[0].startswith("-")):
                c = c[1:]
        elif "=" in c[0] and not c[0].startswith("-") and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", c[0]):
            c = c[1:]                     # VAR=valore davanti al comando
        else:
            return c
    return c


def esclusioni(nome, args):
    """Indici delle parole che sono esclusioni di una ricerca, e se almeno una copre davvero la cartella riservata.
    Il confronto delle esclusioni distingue le maiuscole, come fanno grep e find."""
    ultimo = ris.split("/")[-1]
    idx, copre = set(), False

    def copre_modello(m, tipo):
        m = unicodedata.normalize("NFC", m)
        if tipo == "base":      # grep --exclude-dir, rg/ag con nome di cartella: il nome della cartella
            return fnmatch.fnmatchcase(ultimo, m.rstrip("/")) or fnmatch.fnmatchcase(ris, m.rstrip("/"))
        prove = ["./" + ris + "/x", ris + "/x", os.path.join(vault, ris) + "/x"]
        if tipo == "prune":
            prove += ["./" + ris, ris, os.path.join(vault, ris), ultimo]
        return any(fnmatch.fnmatchcase(p, m) for p in prove)

    for i, a in enumerate(args):
        prec = args[i - 1] if i else ""
        prec2 = args[i - 2] if i > 1 else ""
        succ = args[i + 1] if i + 1 < len(args) else ""
        if nome in ("grep", "egrep", "rg", "ag"):
            m = None
            if a.startswith("--exclude-dir="):
                m, t = a.split("=", 1)[1], "base"
            elif prec == "--exclude-dir":
                m, t = a, "base"
            elif nome == "rg" and (prec in ("-g", "--glob", "--iglob") and a.startswith("!")):
                m, t = a[1:], "rg"
            elif nome == "rg" and re.match(r"^--i?glob=!", a):
                m, t = a.split("=!", 1)[1], "rg"
            elif nome == "ag" and prec in ("--ignore", "--ignore-dir"):
                m, t = a, "rg"
            elif nome == "ag" and re.match(r"^--ignore(-dir)?=", a):
                m, t = a.split("=", 1)[1], "rg"
            if m is not None:
                idx.add(i)
                if t == "rg":
                    m2 = m.rstrip("/")
                    if m2.endswith("/**"):
                        m2 = m2[:-3]
                    copre = copre or fnmatch.fnmatchcase(ultimo, m2) or fnmatch.fnmatchcase(ris, m2) \
                        or fnmatch.fnmatchcase(ris, m2.lstrip("*/")) or fnmatch.fnmatchcase(ris + "/x", m)
                else:
                    copre = copre or copre_modello(m, t)
        elif nome == "find":
            if prec in ("-path", "-wholename", "-ipath", "-name", "-iname"):
                if prec2 in ("-not", "!") and prec in ("-path", "-wholename", "-ipath"):
                    idx.add(i); copre = copre or copre_modello(a, "path")
                elif succ == "-prune":
                    idx.add(i); copre = copre or copre_modello(a, "prune")
    return idx, copre


def contiene(percorso):
    a = n(os.path.realpath(os.path.join(cwd, os.path.expanduser(percorso))))
    return dentro_ris(a) or RA.startswith(a.rstrip("/") + "/")


for c in comandi_di(cmd):
    c = svolgi(c)
    if not c:
        continue
    nome = os.path.basename(c[0])
    args = c[1:]
    # 0. file dei segreti: nessun comando li apre, tranne gli script del plugin che li usano per conto loro
    script = next((a for a in args if not a.startswith("-")), "") if nome in ("bash", "sh", "python3", "python", "node") else c[0]
    del_plugin = n(os.path.realpath(os.path.join(cwd, script))).startswith(ROOT + "/") if script else False
    if not del_plugin and any(segreto(a) for a in c):
        print("segreto"); sys.exit(0)
    if not ris:
        continue
    esc, copre = esclusioni(nome, args) if nome in ("grep", "egrep", "rg", "ag", "find") else (set(), False)
    # 1. una parola che porta nella cartella (o la nomina), fuori dalle esclusioni
    for i, a in enumerate([c[0]] + args):
        if i - 1 in esc:
            continue
        if tocca(a):
            print("nega"); sys.exit(0)
    if modo != "dentro":
        continue
    # 2. ricerca ricorsiva che parte da una cartella che contiene quella riservata, senza un'esclusione che la copra
    if nome not in ("grep", "egrep", "rg", "ag", "find") or copre:
        continue
    if nome == "find":
        percorsi, aa = [], args
        # opzioni che stanno PRIMA dei percorsi (BSD e GNU): -H -L -P -E -X -d -s -x, -f <percorso>, -O<livello>
        while aa and (aa[0] in ("-H", "-L", "-P", "-E", "-X", "-d", "-s", "-x") or aa[0].startswith("-O") or aa[0] == "-f"):
            if aa[0] == "-f" and len(aa) > 1:
                percorsi.append(aa[1]); aa = aa[2:]
            else:
                aa = aa[1:]
        for a in aa:
            if a.startswith("-") or a in ("(", "!", ")"):
                break
            percorsi.append(a)
        percorsi = percorsi or ["."]
    else:
        ricorsivo = nome in ("rg", "ag") or any(a.startswith("-") and not a.startswith("--") and ("r" in a or "R" in a) for a in args) \
            or "--recursive" in args or "--dereference-recursive" in args
        if not ricorsivo:
            continue
        non_opz = [a for i, a in enumerate(args) if not a.startswith("-") and i not in esc and (i == 0 or args[i - 1] not in ("--exclude-dir", "-g", "--glob", "--iglob", "--ignore", "--ignore-dir", "-e", "-f", "--include", "--exclude"))]
        percorsi = non_opz[1:] or ["."]      # il primo argomento non opzione è il pattern
    if any(contiene(p) for p in percorsi):
        print("ricerca"); sys.exit(0)
