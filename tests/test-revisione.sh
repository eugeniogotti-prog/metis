#!/bin/bash
# test-revisione.sh — prova dei rimedi della revisione mensile (6/10/2026): segreti, portabilità macOS,
# sezioni «## Impegni», con-timeout. Ogni controllo del doctor nei due versi: tace sul vault sano, suona sul guasto.
# Si lancia con bash (una prova fatta in zsh ha dato un falso negativo). Tutto vive sotto una mktemp -d.
#
# Uso: bash tests/test-revisione.sh

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
ko()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

V="$T/Vault"; mkdir -p "$V"
export METIS_CONFIG="$T/config" METIS_LAUNCHAGENTS="$T/LaunchAgents"
mkdir -p "$METIS_LAUNCHAGENTS"
cat > "$METIS_CONFIG" <<EOF
METIS_VAULT=$V
METIS_FONTI=$T/Documenti
METIS_MEMORY_DIR=$T/mem
METIS_JOBS=
METIS_LOG_DIR=$T/log
METIS_LABEL=com.metis.prova
METIS_RUOLO_RISERVATA=Personale
EOF
bash "$ROOT/scripts/installa-struttura.sh" crea >/dev/null 2>&1
bash "$ROOT/scripts/installa-modelli.sh" templates/memoria "Luca Prova" >/dev/null 2>&1
CL="$V/_Claude"
doctor() { bash "$ROOT/scripts/doctor.sh" >/dev/null 2>"$T/doctor.err"; }
riga() { grep -E "$1" "$CL/doctor.md"; }
# segreti finti costruiti a pezzi, perché il repository non contenga stringhe con la forma di un segreto
TG="123456789:AA$(printf 'x%.0s' {1..34})"
GSK="gsk_$(printf 'y%.0s' {1..40})"

echo "1. Vault sano"
doctor
check "doctor senza errori su stderr" '[ ! -s "$T/doctor.err" ]'
check "segreti: tace" 'riga "✅ Nessun token o chiave in chiaro"'
check "portabilità: tace" 'riga "✅ Nessun comando GNU assente su macOS"'
check "LaunchAgent: nessuno installato, solo informazione" 'riga "ℹ️ Nessun LaunchAgent"'

echo "2. Guasti finti"
mkdir -p "$V/Personale" "$V/1 - Progetti/Rossi"
printf -- '---\ncreated_at: 2026-10-06\ntags:\n- tipo/appunti\nup:\n- x\n---\nIl bot: %s\n' "$TG" > "$V/1 - Progetti/Rossi/Appunti bot.md"
printf 'chiave %s\n' "$GSK" > "$V/Personale/chiavi.md"
printf '\n- Per sicurezza: timeout 30 find . -name x\n' >> "$V/CLAUDE.md"
for n in 2 4; do
  { printf -- '---\nstatus: attivo\n---\n# Stato\n'; for i in $(seq 1 $n); do printf '## Impegni\n- [x] fatto\n'; done; } > "$CL/stati/lavoro-$n.md"
done
cat > "$METIS_LAUNCHAGENTS/com.metis.prova.senza.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>com.metis.prova.senza</string><key>EnvironmentVariables</key><dict><key>PATH</key><string>/usr/bin:/bin</string></dict></dict></plist>
EOF
sed 's/senza/con/; s#/usr/bin:/bin#/opt/homebrew/bin:/usr/bin:/bin#' "$METIS_LAUNCHAGENTS/com.metis.prova.senza.plist" > "$METIS_LAUNCHAGENTS/com.metis.prova.con.plist"
doctor
check "doctor senza errori su stderr" '[ ! -s "$T/doctor.err" ]'
check "segreti: suona sulla nota con il token, senza stamparlo" 'riga "❌ Token o chiavi in chiaro in 1 note" | grep -q "Appunti bot.md" && ! grep -q "$TG" "$CL/doctor.md"'
check "segreti: la cartella riservata non si legge" '! grep -q "chiavi.md" "$CL/doctor.md"'
check "portabilità: suona su timeout in CLAUDE.md" 'riga "⚠️ Comandi GNU assenti su macOS in 1 punti" | grep -q "CLAUDE.md"'
check "LaunchAgent: suona su quello senza Homebrew, non sull'altro" 'riga "⚠️ LaunchAgent di Metis con PATH senza" | grep -q "senza" && ! riga "⚠️ LaunchAgent" | grep -q "prova.con"'
check "Impegni: 2 sezioni avviso" 'riga "⚠️ Stati con 2-3 sezioni" | grep -q "lavoro-2(2)"'
check "Impegni: 4 sezioni critico" 'riga "❌ Stati con più di 3 sezioni" | grep -q "lavoro-4(4)"'

echo "3. Oscuramento nelle trascrizioni"
J="$T/sessione.jsonl"
python3 - "$J" "$TG" <<'PY'
import json, sys
p, tg = sys.argv[1:]
righe = [{"type": "user", "timestamp": "2026-10-06T09:00:00Z", "message": {"content": "il token del bot è " + tg}},
         {"type": "assistant", "timestamp": "2026-10-06T09:00:05Z", "message": {"content": [{"type": "text", "text": "Uso: TOKEN=$(cat ~/.config/metis/telegram) nel comando."}]}}]
open(p, "w").write("\n".join(json.dumps(r) for r in righe) + "\n")
PY
OUT=$(python3 "$ROOT/scripts/trascrizione.py" "$J")
check "il token esce oscurato" 'printf "%s" "$OUT" | grep -q "\[TELEGRAM-OSCURATO\]" && ! printf "%s" "$OUT" | grep -q "$TG"'
check "TOKEN=\$(cat …) resta intatto" 'printf "%s" "$OUT" | grep -qF "TOKEN=\$(cat ~/.config/metis/telegram)"'

echo "4. con-timeout"
bash "$ROOT/scripts/con-timeout.sh" 1 sleep 3; RC=$?
check "scade: codice 142 (codice $RC)" '[ "$RC" -eq 142 ]'
bash "$ROOT/scripts/con-timeout.sh" 5 true; RC=$?
check "non scade: codice del comando (codice $RC)" '[ "$RC" -eq 0 ]'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
