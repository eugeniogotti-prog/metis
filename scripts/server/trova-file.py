#!/usr/bin/env python3
"""trova-file.py — dal riferimento che il cliente incolla al file sul server.

Il cliente non conosce i percorsi del server: incolla quello che ha sotto mano. Questo script lo traduce:
  - un percorso del suo computer dentro una cartella sincronizzata (Drive, OneDrive: «/Users/…/Google Drive/Il mio Drive/
    Lavoro/x.pdf», «C:\\Users\\…\\OneDrive\\Lavoro\\x.pdf», «G:\\Il mio Drive\\…») → la copia sul server, cercando la coda
    più lunga del percorso che esiste nelle cartelle allineate (sync.sh) o nel vault;
  - un link di Google Drive con l'identificativo del file (…/d/<id>/…, ?id=<id>) → il file con quell'identificativo nelle
    coppie su Drive (rclone lsf --format pi);
  - un link di OneDrive o SharePoint → il nome del file contenuto nel link, se c'è, poi come sopra;
  - un link del FileBrowser del server (…/files/<percorso>) → il percorso nel vault;
  - altrimenti, un nome: la ricerca per nome nel vault e nelle cartelle allineate.
Uso: trova-file.py "<percorso, link o nome>"
Stampa i percorsi trovati sul server (al massimo 10), uno per riga, i più probabili prima; esce con 1 se non trova niente.
Le coppie cloud ↔ server sono quelle di sync.sh (<cartella della configurazione>/sync-coppie).
"""
import os, re, subprocess, sys, urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "telegram"))
import metis_telegram as mt   # noqa: E402  configurazione

c = mt.leggi_kv(os.environ.get("METIS_CONFIG", os.path.join(mt.CFG_DIR, "config")))
VAULT = os.path.realpath(os.path.expanduser(c.get("METIS_VAULT", "")))


def coppie():
    p = os.path.join(mt.CFG_DIR, "sync-coppie")
    if not os.path.exists(p):
        return []
    return [tuple(r.rstrip("\n").split("\t", 1)) for r in open(p, encoding="utf-8") if "\t" in r]


def radici():
    return [VAULT] + [l for _, l in coppie() if os.path.isdir(l)]


def per_coda(parti):
    """Il file la cui coda di percorso coincide con quella data, provando dalla coda più lunga alla più corta."""
    trovati = []
    for n in range(len(parti), 0, -1):
        coda = os.path.join(*parti[-n:])
        for r in radici():
            for d, _, fs in os.walk(r):
                if any(x.startswith(".") for x in os.path.relpath(d, r).split(os.sep) if x != "."):
                    continue
                cand = os.path.join(d, parti[-1])
                if parti[-1] in fs and cand.endswith(os.sep + coda) and cand not in trovati:
                    trovati.append(cand)
        if trovati:
            return trovati
    return trovati


def per_id_drive(fid):
    trovati = []
    for remoto, locale in coppie():
        try:
            out = subprocess.run(["rclone", "lsf", "-R", "--format", "pi", "--separator", "\t", remoto],
                                 capture_output=True, text=True, timeout=300).stdout
        except Exception:
            continue
        for riga in out.splitlines():
            percorso, _, ident = riga.partition("\t")
            if ident.strip() == fid:
                trovati.append(os.path.join(locale, percorso))
    return trovati


def main(a):
    if not a:
        print(__doc__); return 2
    rif = " ".join(a).strip().strip("'\"")
    trovati = []
    if re.match(r"https?://", rif):
        u = urllib.parse.urlparse(rif)
        if "/files/" in u.path and c.get("METIS_WEB_URL", "").split("//")[-1].split("/")[0] in u.netloc:
            p = os.path.join(VAULT, urllib.parse.unquote(u.path.split("/files/", 1)[1]).rstrip("/"))
            trovati = [p] if os.path.exists(p) else []
        elif "google.com" in u.netloc:
            m = re.search(r"/d/([A-Za-z0-9_-]{10,})", u.path) or re.search(r"(?:^|&)id=([A-Za-z0-9_-]{10,})", u.query)
            if m:
                trovati = per_id_drive(m.group(1))
        else:   # OneDrive, SharePoint, altro: il nome del file, se il link lo contiene
            pezzi = [x for x in urllib.parse.unquote(u.path + "/" + u.query.replace("&", "/").replace("=", "/")).split("/") if x]
            nomi = [x for x in pezzi if re.search(r"\.[A-Za-z0-9]{2,5}$", x)]
            if nomi:
                trovati = per_coda([nomi[-1]])
    else:
        parti = [x for x in re.split(r"[\\/]+", rif) if x and not re.match(r"^[A-Za-z]:$", x)]
        if parti:
            trovati = per_coda(parti)
    for p in trovati[:10]:
        print(p)
    return 0 if trovati else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
