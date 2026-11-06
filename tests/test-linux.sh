#!/bin/bash
# test-linux.sh — Metis su Linux: automatismi come servizi e timer di systemd per l'utente, controlli, aggiornamento.
# Due modi:
#   bash tests/test-linux.sh                 ovunque (anche sul Mac): METIS_SISTEMA=Linux e un systemctl finto
#   PROVA_VERA=1 bash tests/test-linux.sh    su Linux, con il systemd vero dell'utente: genera, carica, fa partire un giro
#                                            (con un Claude finto) e l'ascoltatore, poi toglie tutto. Serve il linger.
# Nessun login, nessuna sessione di Claude, nessun messaggio a Telegram.
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(cd "$(mktemp -d)" && pwd -P)"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
VERA="${PROVA_VERA:-}"
if [ -n "$VERA" ] && [ "$(uname -s)" != Linux ]; then echo "PROVA_VERA=1 solo su Linux"; exit 2; fi

# Plugin in una cartella con uno spazio nel nome: le righe ExecStart devono reggere le virgolette.
ROOT="$T/con spazio/plugin"; mkdir -p "$ROOT"
rsync -a --exclude .git --exclude prove "$SRC/" "$ROOT/"
for s in daily-digest weekly-digest; do mkdir -p "$ROOT/skills/$s"; [ -f "$ROOT/skills/$s/SKILL.md" ] || echo finta > "$ROOT/skills/$s/SKILL.md"; done
V="$T/vault"; mkdir -p "$V/0 - Inbox" "$V/_Claude" "$T/cfg"
cp "$SRC/templates/memoria/_Claude/_Claude.md.txt" "$V/_Claude/_Claude.md"
cp "$SRC/templates/memoria/_Claude/profilo-nucleo.md.txt" "$V/_Claude/profilo-nucleo.md"
export METIS_CONFIG="$T/cfg/config" METIS_ROOT="$ROOT"
LABEL="com.metis.prova$$"
cat > "$T/claude-finto" <<'EOF'
#!/bin/bash
cat > /dev/null; echo "$*" >> "$(dirname "$0")/claude-args.txt"
printf '{"result":"Digest scritto nella nota del giorno.","is_error":false}'
EOF
chmod +x "$T/claude-finto"
printf 'METIS_VAULT=%s\nMETIS_LOG_DIR=%s/log\nMETIS_LABEL=%s\nMETIS_MEMORY_DIR=%s/mem\nMETIS_JOBS=daily-digest weekly-digest\nMETIS_CLAUDE=%s\n' \
  "$V" "$T" "$LABEL" "$T" "$T/claude-finto" > "$METIS_CONFIG"
echo '{}' > "$T/cfg/permessi-routine.json"

if [ -n "$VERA" ]; then
  SD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  [ -z "${XDG_RUNTIME_DIR:-}" ] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  pulisci() {
    for u in "$SD/$LABEL".*.timer "$SD/$LABEL".*.service; do
      [ -f "$u" ] && systemctl --user disable --now "$(basename "$u")" >/dev/null 2>&1; rm -f "$u"
    done
    systemctl --user daemon-reload 2>/dev/null; rm -rf "$T"
  }
else
  export METIS_SISTEMA=Linux METIS_LINGER=yes
  SD="$T/systemd"; printf 'METIS_SYSTEMD_DIR=%s\n' "$SD" >> "$METIS_CONFIG"
  # systemctl finto: registra le chiamate e tiene lo stato (abilitato/attivo) in file
  cat > "$T/systemctl-finto" <<'EOF'
#!/bin/bash
D="$(dirname "$0")/stato-sc"; mkdir -p "$D"; echo "$*" >> "$(dirname "$0")/systemctl.txt"
[ "$1" = --user ] && shift
az="$1"; shift; [ "${1:-}" = --now ] && { now=1; shift; }
case "$az" in
  daemon-reload) exit 0 ;;
  enable) touch "$D/$1.en"; [ -n "${now:-}" ] && touch "$D/$1.on"; exit 0 ;;
  restart|start) touch "$D/$1.on"; exit 0 ;;
  disable) rm -f "$D/$1.en"; [ -n "${now:-}" ] && rm -f "$D/$1.on"; exit 0 ;;
  is-enabled) [ -f "$D/$1.en" ] ;;
  is-active) [ -f "$D/$1.on" ] ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$T/systemctl-finto"; export METIS_SYSTEMCTL="$T/systemctl-finto"
  pulisci() { rm -rf "$T"; }
fi
trap pulisci EXIT
S="$ROOT/scripts/lib/servizi.sh"

echo "1. Strato degli automatismi"
check "su Linux si usano i servizi systemd" '[ "$(bash "$S" tipo)" = "servizio systemd" ]'
check "funzioni portabili: data, permessi e dimensione di un file" 'source "$ROOT/scripts/lib/config.sh"; f="$T/cfg/config"; chmod 600 "$f"; [ "$(metis_permessi "$f")" = 600 ] && [ "$(metis_mtime "$f")" -gt 1600000000 ] && [ "$(metis_dimensione "$f")" -gt 10 ] && [ "$(metis_giorno_file "$f")" = "$(date +%F)" ]'

echo "2. Giri automatici (routine.sh)"
printf 'METIS_ORARI_DAILY_DIGEST=07:00 12:30\n' >> "$METIS_CONFIG"
OUT=$(bash "$ROOT/scripts/moduli/routine.sh" installa 2>&1); RC=$?
check "installazione riuscita" '[ "$RC" = 0 ]' || echo "$OUT" | sed 's/^/     /'
SV="$SD/$LABEL.daily-digest.service"; TM="$SD/$LABEL.daily-digest.timer"; TW="$SD/$LABEL.weekly-digest.timer"
check "servizio e timer per il doctor e per ogni giro" '[ -f "$SD/$LABEL.doctor.timer" ] && [ -f "$TM" ] && [ -f "$TW" ] && [ -f "$SV" ]'
check "due orari: due righe OnCalendar" 'grep -q "^OnCalendar=\*-\*-\* 07:00:00$" "$TM" && grep -q "^OnCalendar=\*-\*-\* 12:30:00$" "$TM"'
check "sintesi del lunedì solo il lunedì" 'grep -q "^OnCalendar=Mon \*-\*-\* 07:30:00$" "$TW"'
check "giro saltato recuperato dopo un riavvio (Persistent)" 'grep -q "^Persistent=true$" "$TM"'
check "ExecStart tra virgolette, con lo spazio nel percorso" 'grep -qF "ExecStart=\"/bin/bash\" \"$ROOT/scripts/metis-agent.sh\" \"daily-digest\"" "$SV"'
check "configurazione, lingua e registro nel servizio" 'grep -qF "METIS_CONFIG=$METIS_CONFIG" "$SV" && grep -q "LANG=C.UTF-8" "$SV" && grep -qF "StandardOutput=append:$T/log/daily-digest.log" "$SV"'
check "giro a orario: servizio oneshot, senza riavvio" 'grep -q "^Type=oneshot$" "$SV" && ! grep -q "^Restart=" "$SV"'
check "controllo dei giri superato" 'bash "$ROOT/scripts/moduli/routine.sh" controlla >/dev/null'

echo "3. Ascoltatore di Telegram (telegram.sh)"
bash "$ROOT/scripts/moduli/telegram.sh" ascoltatore >/dev/null 2>&1
ST="$SD/$LABEL.telegram.service"
check "servizio sempre acceso, riavviato se si ferma" 'grep -q "^Type=simple$" "$ST" && grep -q "^Restart=always$" "$ST" && grep -q "^RestartSec=30$" "$ST" && grep -q "^WantedBy=default.target$" "$ST"'
check "nessun timer per l'ascoltatore" '[ ! -f "$SD/$LABEL.telegram.timer" ]'
check "l'ascoltatore lancia lo script del bot" 'grep -qF "\"$ROOT/scripts/telegram/metis_telegram.py\" \"ascolta\"" "$ST"'
check "servizi.sh file elenca i sette file" '[ "$(bash "$S" file | wc -l | tr -d " ")" = 7 ]'

if [ -z "$VERA" ]; then
  check "caricamento: timer abilitato e acceso" 'grep -q "^--user enable --now $LABEL.daily-digest.timer$" "$T/systemctl.txt"'
  check "caricamento dell'ascoltatore: servizio abilitato e riavviato" 'grep -q "^--user enable $LABEL.telegram.service$" "$T/systemctl.txt" && grep -q "^--user restart $LABEL.telegram.service$" "$T/systemctl.txt"'
  bash "$S" scarica weekly-digest >/dev/null
  check "togliere un giro: timer disabilitato e fermato" 'grep -q "^--user disable --now $LABEL.weekly-digest.timer$" "$T/systemctl.txt" && ! bash "$S" stato weekly-digest >/dev/null'
  bash "$S" carica weekly-digest >/dev/null
else
  check "timer attivi nel systemd vero" 'systemctl --user is-active "$LABEL.daily-digest.timer" >/dev/null && systemctl --user is-active "$LABEL.weekly-digest.timer" >/dev/null'
  check "prossimo giro del lunedì calcolato da systemd" 'systemctl --user list-timers "$LABEL.weekly-digest.timer" --no-legend | grep -q "^Mon"'
  OGGI=$(date +%F)
  systemctl --user start "$LABEL.daily-digest.service"
  check "un giro vero partito da systemd scrive nella nota del giorno" 'grep -q "🤖 .* daily-digest: Digest scritto" "$V/Journal/$OGGI.md"'
  check "il giro ha scritto il suo registro" 'grep -q "rc=0" "$T/log/daily-digest.log"'
  sleep 3
  check "l'ascoltatore (senza bot configurato) viene tenuto in vita da systemd" 'systemctl --user show "$LABEL.telegram.service" -p NRestarts --value | grep -qE "^[0-9]+$" && systemctl --user is-enabled "$LABEL.telegram.service" >/dev/null'
  bash "$S" scarica telegram >/dev/null
  check "ascoltatore fermato e disabilitato" '! systemctl --user is-active "$LABEL.telegram.service" >/dev/null && ! systemctl --user is-enabled "$LABEL.telegram.service" >/dev/null'
  check "systemd-analyze non trova errori nei file" '[ -z "$(SYSTEMD_LOG_LEVEL=err systemd-analyze --user verify "$SV" "$TM" "$TW" 2>&1 | grep -F "$LABEL")" ]'
fi

echo "4. Doctor"
bash "$ROOT/scripts/doctor.sh" >/dev/null 2>"$T/doctor.err"
DM="$V/_Claude/doctor.md"
check "doctor senza errori dello script" '[ ! -s "$T/doctor.err" ]' || sed 's/^/     /' "$T/doctor.err" | head -5
check "automatismi riconosciuti come servizi systemd caricati" 'grep -q "servizio systemd $LABEL.daily-digest caricato" "$DM"'
check "linger controllato" 'grep -q "anche senza nessuno collegato" "$DM"'
check "niente controllo del PATH di Homebrew su Linux" '! grep -q "LaunchAgent" "$DM"'
if [ -z "$VERA" ]; then
  METIS_LINGER=no bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
  check "senza linger: allarme rosso con il comando" 'grep -q "sudo loginctl enable-linger" "$DM"'
fi

echo "5. Controllo d'installazione"
OUT=$(bash "$ROOT/scripts/verifica-dotazione.sh" fondamenta docx routine 2>&1)
check "Linux accettato, niente Homebrew né Obsidian richiesti" 'printf "%s" "$OUT" | grep -q "✅ Linux" && ! printf "%s" "$OUT" | grep -q "Homebrew" && printf "%s" "$OUT" | grep -q "ℹ️ Obsidian"'
check "routine su Linux: systemctl al posto di launchctl" 'printf "%s" "$OUT" | grep -q "systemctl" && ! printf "%s" "$OUT" | grep -q "launchctl"'
if [ -z "$VERA" ]; then
  check "comandi di Ubuntu per ciò che manca" 'PATH=/usr/bin:/bin METIS_SISTEMA=Linux bash "$ROOT/scripts/verifica-dotazione.sh" docx 2>&1 | grep -qE "✅ pandoc|sudo apt install pandoc"'
fi

echo "6. Aggiornamento da una copia vecchia (aggiorna.sh)"
VEC="$T/vecchia/Metis"; mkdir -p "$VEC/scripts" "$VEC/.claude-plugin"
cp "$ROOT/.claude-plugin/plugin.json" "$VEC/.claude-plugin/"; cp "$ROOT/scripts/metis-agent.sh" "$VEC/scripts/"
sed -i.bak "s|$ROOT/scripts/metis-agent.sh|$VEC/scripts/metis-agent.sh|" "$SV" && rm -f "$SV.bak"
check "preparazione: il servizio punta alla copia vecchia" 'grep -qF "$VEC/scripts/metis-agent.sh" "$SV"'
OUT=$(bash "$ROOT/scripts/aggiorna.sh" controlla 2>&1)
check "controlla vede la copia vecchia nel servizio" 'printf "%s" "$OUT" | grep -qF "$VEC"'
OUT=$(METIS_AGGIORNA_PROVA=1 bash "$ROOT/scripts/aggiorna.sh" esegui 2>&1); [ -n "${VEDI:-}" ] && printf "%s\n" "$OUT"
check "esegui riallinea il servizio a questa copia" 'grep -qF "\"$ROOT/scripts/metis-agent.sh\"" "$SV" && ! grep -qF "$VEC" "$SV"' || printf '%s\n' "$OUT" | tail -8 | sed 's/^/     /'
check "dopo l'aggiornamento nessun riferimento alla copia vecchia" 'printf "%s" "$OUT" | grep -q "puntano a questa copia"'
check "copia di sicurezza con il servizio" 'ls "$T/cfg/backup"/aggiorna-*/file/ 2>/dev/null | grep -q "daily-digest.service"'

echo ""
echo "Risultato: $PASS ok, $FAIL falliti"
[ "$FAIL" = 0 ]
