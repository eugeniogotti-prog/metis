#!/usr/bin/env python3
"""link.py — il link cliccabile a un file del vault nel FileBrowser del server (web.sh), da mettere nelle risposte.

Uso: link.py <percorso> [<percorso> ...]
     il percorso può essere assoluto (dentro il vault) o relativo alla radice del vault.
Stampa una riga per file: l'indirizzo https://<nome>/files/<percorso codificato>. Esce con 1 se un file è fuori dal vault,
nascosto (FileBrowser non lo mostra) o se l'indirizzo del FileBrowser non è configurato (METIS_WEB_URL, scritto da web.sh).
"""
import os, sys, urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "telegram"))
import metis_telegram as mt   # noqa: E402  solo per leggere la configurazione


def main(a):
    if not a:
        print(__doc__); return 2
    c = mt.leggi_kv(os.environ.get("METIS_CONFIG", os.path.join(mt.CFG_DIR, "config")))
    base = (c.get("METIS_WEB_URL") or "").rstrip("/")
    vault = os.path.realpath(os.path.expanduser(c.get("METIS_VAULT", "")))
    if not base:
        print("link: METIS_WEB_URL non configurato (web.sh)", file=sys.stderr); return 1
    err = 0
    for p in a:
        assoluto = os.path.realpath(p if os.path.isabs(p) else os.path.join(vault, p))
        rel = os.path.relpath(assoluto, vault)
        if rel.startswith(".."):
            print(f"link: fuori dal vault: {p}", file=sys.stderr); err = 1; continue
        if any(x.startswith(".") for x in rel.split(os.sep)):
            print(f"link: percorso nascosto, FileBrowser non lo mostra: {p}", file=sys.stderr); err = 1; continue
        coda = "/" if os.path.isdir(assoluto) else ""
        print(f"{base}/files/{urllib.parse.quote(rel)}{coda}")
    return err


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
