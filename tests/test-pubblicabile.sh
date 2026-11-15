#!/bin/bash
# test-pubblicabile.sh — prova di tests/controlla-pubblicabile.sh in un repository finto: un binario con un percorso del
# Mac dentro (come un .pyc) va trovato; con --storia anche un binario già tolto dall'albero.
# Uso: bash tests/test-pubblicabile.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); echo "  ✅ $1"; else FAIL=$((FAIL+1)); echo "  ❌ $1"; fi; }
R="$T/repo"; mkdir -p "$R/tests"; cp "$ROOT/tests/controlla-pubblicabile.sh" "$R/tests/"
echo "Nessunonome" > "$T/nomi"; export METIS_NOMI_VIETATI="$T/nomi"
cd "$R" && git init -q && git config user.email p@p.invalid && git config user.name prova
echo "testo pulito" > a.md; git add -A; git commit -qm "primo"
check "repository pulito: esito 0" 'bash tests/controlla-pubblicabile.sh >/dev/null'
P_="/Us""ers/qualcuno/progetto/mappa.py"   # il percorso a pezzi, per non farlo trovare in questo file
printf '\000\001\002%s\000\003' "$P_" > m.pyc; git add -f m.pyc; git commit -qm "binario"
check "percorso del Mac dentro un binario versionato: trovato" '! bash tests/controlla-pubblicabile.sh > "$T/o1" && grep -q "binario m.pyc" "$T/o1"'
git rm -q m.pyc; git commit -qm "tolto"
check "binario tolto dall'albero: il controllo normale passa" 'bash tests/controlla-pubblicabile.sh >/dev/null'
check "con --storia il binario tolto si vede ancora" '! bash tests/controlla-pubblicabile.sh --storia > "$T/o2" && grep -q "storia m.pyc" "$T/o2"'
echo; echo "pubblicabile: $PASS ok, $FAIL falliti"; [ "$FAIL" = 0 ]
