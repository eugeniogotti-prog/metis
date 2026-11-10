#!/bin/bash
# test-sync.sh — modulo sync con rclone vero su due cartelle locali (il «cloud» è una cartella con il remoto «:local:»).
# Serve rclone (1.66 o successivo); senza, la prova si salta.
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v rclone >/dev/null || { echo "rclone assente: prova saltata"; exit 0; }
T="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
mkdir -p "$T/vault" "$T/cloud" "$T/cfg"
export METIS_CONFIG="$T/cfg/config" METIS_ROOT="$SRC" METIS_SYNC_SENZA_REMOTI=1 METIS_SYNC_VERSIONI="$T/versioni"
printf 'METIS_VAULT=%s\nMETIS_LOG_DIR=%s/log\nMETIS_LABEL=com.metis.prova\nMETIS_MEMORY_DIR=%s/mem\n' "$T/vault" "$T" "$T" > "$METIS_CONFIG"
S="bash $SRC/scripts/moduli/sync.sh"
C="$T/cloud"; L="$T/locale"

echo "== Coppia e primo giro"
echo "nel cloud" > "$C/a.md"; mkdir -p "$C/sotto"; echo x > "$C/sotto/b.md"; echo t > "$C/~\$bozza.docx"
check "remoto senza «:» rifiutato" '! $S aggiungi "$C" "$L" 2>/dev/null'
$S aggiungi ":local:$C" "$L" >/dev/null
check "aggiunta (e cartella locale creata)" '[ -d "$L" ] && grep -q "$L" "$T/cfg/sync-coppie"'
check "aggiungere due volte non duplica" '$S aggiungi ":local:$C" "$L" >/dev/null; [ "$(grep -c . "$T/cfg/sync-coppie")" = 1 ]'
$S giro; RC=$?
check "primo giro riuscito" '[ $RC = 0 ] && [ -f "$T/cfg/sync-ultimo" ]'
check "file del cloud arrivati" '[ -f "$L/a.md" ] && [ -f "$L/sotto/b.md" ]'
check "file temporaneo di Word escluso" '[ ! -e "$L/~\$bozza.docx" ]'

echo "== Nei due versi"
echo "dal server" > "$L/nuovo.md"; echo "cambiato nel cloud" > "$C/a.md"; touch -t 202601010000 "$L/sotto/b.md"
$S giro
check "nuovo file del server nel cloud" '[ -f "$C/nuovo.md" ]'
check "modifica del cloud sul server" 'grep -q "cambiato nel cloud" "$L/a.md"'
check "versione precedente conservata" 'grep -rq "nel cloud" "$T/versioni"'

echo "== Conflitto"
sleep 1; echo "server" > "$L/a.md"; sleep 1; echo "cloud più recente" > "$C/a.md"
$S giro
check "vince il più recente" 'grep -q "cloud più recente" "$L/a.md"'
check "l'altra versione resta con sync-conflict nel nome" 'ls "$L" "$C" | grep -q sync-conflict'
OUT=$($S controlla 2>&1)
check "controlla vede il conflitto e l'ultimo giro" 'echo "$OUT" | grep -q "in conflitto" && echo "$OUT" | grep -q "ultimo giro riuscito"'

echo "== Togliere"
$S togli "$L" >/dev/null
check "coppia tolta, file rimasti" '! grep -q "$L" "$T/cfg/sync-coppie" && [ -f "$L/a.md" ]'
check "giro senza coppie: esce con 0" '$S giro'

echo ""; echo "Risultato: $PASS passati, $FAIL falliti"
[ "$FAIL" = 0 ]
