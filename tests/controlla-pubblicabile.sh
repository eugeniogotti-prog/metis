#!/bin/bash
# controlla-pubblicabile.sh — prima di ogni push: il repository è pubblico, quindi nei file versionati, nelle modifiche
# in attesa di commit e in tutti i messaggi di commit non devono comparire segreti, percorsi di un Mac né nomi di
# clienti, enti, piloti o terzi.
# Uso: bash tests/controlla-pubblicabile.sh [--storia]
#   --storia  controlla anche ogni file di tutta la storia (git rev-list --objects --all), compresi quelli poi tolti:
#             la storia pubblicata resta leggibile. Non riscrive niente: dice soltanto che cosa c'è.
# I file binari versionati (immagini, .pyc, archivi) si leggono come fa «strings»: un .pyc porta il percorso del Mac su cui
# è stato compilato (rilievo della revisione di sicurezza del 15/11/2026, due .pyc pubblicati in ottobre).
# I nomi da cercare stanno in un file FUORI dal repository (una voce per riga, # per i commenti), perché pubblicarli
# sarebbe la stessa fuga che il controllo vuole evitare: $METIS_NOMI_VIETATI, oppure ~/.config/metis-dev/nomi-vietati.txt.
# Le voci si cercano come parole intere, senza distinguere maiuscole e minuscole.
# Uscita: 0 se è tutto pulito, 1 se c'è qualcosa da togliere, 2 se manca la lista dei nomi.

export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
NOMI="${METIS_NOMI_VIETATI:-$HOME/.config/metis-dev/nomi-vietati.txt}"
[ -s "$NOMI" ] || { echo "Manca la lista dei nomi da cercare: $NOMI (una voce per riga, fuori dal repository)." >&2; exit 2; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
grep -vE '^[[:space:]]*(#|$)' "$NOMI" > "$T/nomi"
SEGRETI='[0-9]{8,10}:[A-Za-z0-9_-]{35}|gsk_[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{10,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{30}|xox[abp]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY'
PERCORSI='/Users/[a-z][a-z0-9._-]*/|/home/[a-z][a-z0-9._-]*/'

# Le tre fonti: file versionati (con le modifiche già in stage), diff non ancora in commit, messaggi di tutta la storia.
git ls-files -z | xargs -0 grep -nIH '' 2>/dev/null > "$T/file"
# File binari versionati (grep -I li salta) e, con --storia, ogni file di tutta la storia: si leggono le righe dei file di
# testo e le sequenze stampabili dei binari (come «strings»), in Python per non inciampare nei byte non UTF-8.
STORIA=""; [ "${1:-}" = --storia ] && STORIA=1
git ls-files -z | STORIA="$STORIA" python3 -c '
import os, re, subprocess, sys
def righe(dati):
    if b"\0" not in dati[:8000]:
        try:
            return dati.decode("utf-8").splitlines()
        except UnicodeDecodeError:
            pass
    return [m.decode("ascii") for m in re.findall(rb"[\x20-\x7e]{6,}", dati)]
out = sys.stdout
for f in sys.stdin.read().split("\0"):
    if not f or not os.path.isfile(f):
        continue
    d = open(f, "rb").read()
    if d and b"\0" in d[:8000] or (d and not d.decode("utf-8", "ignore").encode() == d):
        for r in righe(d):
            out.write(f"binario {f}: {r}\n")
if os.environ.get("STORIA"):
    ogg = subprocess.run(["git", "rev-list", "--objects", "--all"], capture_output=True, text=True).stdout.splitlines()
    visti = set()
    for riga in ogg:
        h, _, nome = riga.partition(" ")
        if not nome or h in visti or nome == "tests/controlla-pubblicabile.sh":
            continue
        visti.add(h)
        if subprocess.run(["git", "cat-file", "-t", h], capture_output=True, text=True).stdout.strip() != "blob":
            continue
        d = subprocess.run(["git", "cat-file", "-p", h], capture_output=True).stdout
        for r in righe(d):
            out.write(f"storia {nome} ({h[:7]}): {r}\n")
' >> "$T/file"
git diff HEAD | grep -E '^\+[^+]' | sed 's/^/diff: /' > "$T/diff"
git log --format='commit %h: %B' > "$T/msg"
# Questo script e la sua lista di parole per le prove non contano: contengono i modelli, non i dati.
grep -v '^tests/controlla-pubblicabile.sh:' "$T/file" > "$T/file2"; mv "$T/file2" "$T/file"

ESITO=0
riporta() {  # riporta <titolo> <file con i risultati>
  if [ -s "$2" ]; then ESITO=1; echo "❌ $1:"; cut -c1-200 "$2" | sed 's/^/   /' | head -40
  else echo "✅ $1: niente"; fi
}
cat "$T/file" "$T/diff" "$T/msg" | grep -E "$SEGRETI" > "$T/r1"; riporta "segreti e chiavi" "$T/r1"
cat "$T/file" "$T/diff" "$T/msg" | grep -E "$PERCORSI" > "$T/r2"; riporta "percorsi di un Mac" "$T/r2"
cat "$T/file" "$T/diff" "$T/msg" | grep -iwFf "$T/nomi" > "$T/r3"; riporta "nomi della lista ($(wc -l < "$T/nomi" | tr -d ' ') voci)" "$T/r3"
exit $ESITO
