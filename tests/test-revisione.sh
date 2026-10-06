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

echo "4b. Proposta della revisione mensile all'avvio"
G=$(date +%d); G=${G#0}; MP=$(date -v-1m +%Y-%m)
H=$(echo "{\"cwd\":\"$V\"}" | bash "$ROOT/hooks/session-orient.sh")
if [ "$G" -le 10 ]; then
  check "nei primi 10 giorni: proposta della revisione di $MP" 'printf "%s" "$H" | grep -q "revisione delle tracce di $MP"'
  mkdir -p "$CL/revisioni/$MP"; echo "rinuncia" > "$CL/revisioni/$MP/RINUNCIA.md"
  H=$(echo "{\"cwd\":\"$V\"}" | bash "$ROOT/hooks/session-orient.sh")
  check "dopo la rinuncia: nessuna proposta" '! printf "%s" "$H" | grep -q "revisione delle tracce"'
else
  check "dopo il giorno 10: nessuna proposta" '! printf "%s" "$H" | grep -q "revisione delle tracce"'
fi

echo "5. Tracce per la revisione mensile"
PRJ="$T/projects"; SL=$(cd "$V" && pwd -P | sed 's/[^A-Za-z0-9]/-/g'); mkdir -p "$PRJ/$SL" "$PRJ/$SL-1---Progetti"
python3 - "$PRJ/$SL/aaaaaaaa-1111.jsonl" "$TG" <<'PY'
import json, sys
p, tg = sys.argv[1:]
r = [{"type": "user", "timestamp": "2099-01-05T09:00:00Z", "message": {"content": "ecco il token " + tg}},
     {"type": "assistant", "timestamp": "2099-01-05T09:00:05Z", "message": {"content": [{"type": "text", "text": "Ricevuto."}]}},
     {"type": "user", "timestamp": "2099-02-01T09:00:00Z", "message": {"content": "messaggio del mese dopo"}}]
open(p, "w").write("\n".join(json.dumps(x) for x in r) + "\n")
PY
cp "$PRJ/$SL/aaaaaaaa-1111.jsonl" "$PRJ/$SL-1---Progetti/bbbbbbbb-2222.jsonl"
OUTR=$(METIS_CLAUDE_PROJECTS="$PRJ" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; python3 "$0/scripts/revisione-tracce.py" prepara 2099-01' "$ROOT")
C="$HOME/Library/Caches/metis/revisione-2099-01"
check "due sessioni del mese, anche da una sottocartella del vault" 'printf "%s" "$OUTR" | grep -q "2 sessioni del 2099-01"'
check "token oscurato, messaggio del mese dopo escluso" '! grep -rq "$TG" "$C/tracce" && grep -rq "TELEGRAM-OSCURATO" "$C/tracce" && ! grep -rq "mese dopo" "$C/tracce"'
check "niente dentro il vault" '! grep -rq "Ricevuto" "$V"'
python3 "$ROOT/scripts/revisione-tracce.py" pulisci 2099-01 >/dev/null
check "pulizia: cartella temporanea cancellata" '[ ! -d "$C" ]'

echo "6. Assenze dichiarate senza ricerca (hook di validazione)"
scrivi_stato() {  # scrivi_stato <testo nuovo> → codice dell'hook
  printf '%s\n' "$1" > "$CL/stati/prova-assenze.md"
  python3 -c 'import json,sys; print(json.dumps({"tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}}))' "$CL/stati/prova-assenze.md" "$1" \
    | bash "$ROOT/hooks/valida-scrittura.sh" 2>"$T/hook.err"; echo $?
}
check "assenza senza ricerca: avviso" '[ "$(scrivi_stato "La mail di Bianchi non risulta.")" = 2 ] && grep -q "\[assenza\]" "$T/hook.err"'
check "assenza con ricerca dichiarata: silenzio" '[ "$(scrivi_stato "La mail di Bianchi non risulta: cercato nella posta inviata, 60 giorni.")" = 0 ]'
check "affermazione di merito: silenzio" '[ "$(scrivi_stato "La norma non prevede una proroga del termine.")" = 0 ]'
check "fuori da stati, dominio e sessioni: silenzio" 'mkdir -p "$V/1 - Progetti/X"; printf -- "---\ncreated_at: 2026-10-06\ntags:\n- tipo/appunti\nup:\n- x\n---\nLa mail non risulta.\n" > "$V/1 - Progetti/X/n.md"; python3 -c "import json,sys; print(json.dumps({\"tool_input\": {\"file_path\": sys.argv[1], \"content\": \"La mail non risulta.\"}}))" "$V/1 - Progetti/X/n.md" | bash "$ROOT/hooks/valida-scrittura.sh" 2>/dev/null'
rm -f "$CL/stati/prova-assenze.md"

echo "7. Ascolto del telefono"
PL="$METIS_LAUNCHAGENTS/com.metis.prova.telegram.plist"; ST="$T/telegram-stato.json"
sezione_ascolto() { sed -n '/^### Ascolto del telefono/,/^### /p' "$CL/doctor.md"; }
doctor
check "senza ascoltatore installato: nessuna sezione" '! grep -q "Ascolto del telefono" "$CL/doctor.md"'
cp "$METIS_LAUNCHAGENTS/com.metis.prova.con.plist" "$PL"; echo '{}' > "$ST"
METIS_TELEGRAM_STATO="$ST" METIS_ASCOLTO_PROCESSO=1 doctor
check "battito fresco: ok" 'sezione_ascolto | grep -q "✅ Ascoltatore del bot attivo"'
touch -t "$(date -v-3H +%Y%m%d%H%M)" "$ST"
METIS_TELEGRAM_STATO="$ST" METIS_ASCOLTO_PROCESSO=1 METIS_WAKETIME=$(( $(date +%s) - 86400 )) doctor
check "battito di 3 ore fa, Mac sveglio da un giorno: critico" 'sezione_ascolto | grep -q "❌ Ascoltatore del bot fermo"'
METIS_TELEGRAM_STATO="$ST" METIS_ASCOLTO_PROCESSO=1 METIS_WAKETIME=$(( $(date +%s) - 120 )) doctor
check "battito vecchio ma Mac appena svegliato: solo informazione" 'sezione_ascolto | grep -q "ℹ️ Ascoltatore del bot: Mac svegliato" && ! sezione_ascolto | grep -q "❌"'
METIS_TELEGRAM_STATO="$ST" METIS_ASCOLTO_PROCESSO=0 doctor
check "processo assente: critico" 'sezione_ascolto | grep -q "❌ L.ascoltatore del bot non gira"'
rm -f "$PL"

echo "8. Copertura del digest"
OGGI_=$(date +%F); mkdir -p "$CL/cache"
for g in 1 2; do echo "$(date -v-${g}d +%F)|documenti|tempo scaduto" >> "$CL/cache/digest-copertura.log"; done
doctor
check "fonte saltata 2 giorni su 7: silenzio" 'grep -q "✅ Digest: nessuna fonte saltata" "$CL/doctor.md"'
echo "$OGGI_|Documenti|tempo scaduto" >> "$CL/cache/digest-copertura.log"; echo "$(date -v-20d +%F)|posta|login" >> "$CL/cache/digest-copertura.log"
doctor
check "fonte saltata 3 giorni su 7: avviso, solo per quella" 'grep -q "⚠️ Digest: la fonte «documenti» è saltata in 3 giorni" "$CL/doctor.md" && ! grep -q "fonte «posta»" "$CL/doctor.md"'

echo "9. Consolidamento delle sezioni Impegni"
SC="$CL/stati/da-riunire.md"
printf -- '---\nstatus: attivo\n---\n# Stato\n## Dove siamo\nok\n## Impegni\n- [ ] Primo | 2026-10-20 | palla:me\n\n**Fatti:**\n- [x] Vecchio ✅ 2026-09-01\n\n## 2026-10-01 — voce\n## Impegni\n- [ ] Secondo | 2026-10-21 | palla:me\n  - dettaglio del secondo\n- [x] Chiuso nella voce ✅ 2026-10-01\n## 2026-10-02 — voce\n## Impegni aperti\n- [ ] Primo | 2026-10-20 | palla:me\n' > "$SC"
cp "$SC" "$T/prima.md"
P1=$(METIS_CL="$CL" python3 "$ROOT/scripts/impegni-consolida.py" "$SC")
check "prova: non scrive, dice 3 → 1 e aperti 3 → 3, segnala il doppione" 'cmp -s "$SC" "$T/prima.md" && printf "%s" "$P1" | grep -q "sezioni 3 → 1; aperti 3 → 3" && printf "%s" "$P1" | grep -q "possibile doppione"'
METIS_CL="$CL" python3 "$ROOT/scripts/impegni-consolida.py" --scrivi --istanza cli:prova "$SC" >/dev/null
check "scritto: una sola sezione, aperti invariati, figlia con il suo blocco" '[ "$(grep -c "^## Impegni" "$SC")" = 1 ] && [ "$(grep -c "^- \[ \]" "$SC")" = 3 ] && grep -A1 "^- \[ \] Secondo" "$SC" | grep -q "dettaglio del secondo"'
check "chiusi lasciati nella voce, marcatore e copia di prima in archivio" 'grep -B2 "Chiuso nella voce" "$SC" | grep -q "sezione consolidata" && grep -q "aggiornato da cli:prova" "$SC" && ls "$CL"/archivio/stati-prima-del-consolidamento-*/da-riunire.md >/dev/null'
rm -f "$SC"

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
