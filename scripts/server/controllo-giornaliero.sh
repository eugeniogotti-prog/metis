#!/bin/bash
# controllo-giornaliero.sh — ogni mattina su un server: accessi, sessione, bot, spazio, sincronizzazione. Se qualcosa non va,
# o un accesso scade entro METIS_PREAVVISO_GIORNI (default 7), manda un messaggio al cliente su Telegram con il rimedio.
# Se va tutto bene non scrive al cliente: lascia una riga nel registro.
#
# Uso:
#   controllo-giornaliero.sh [--muto]     il controllo (--muto: niente Telegram, solo l'uscita a schermo)
#   controllo-giornaliero.sh installa     il giro di ogni mattina (METIS_ORARI_CONTROLLO, default 07:15)
# Uscita: 0 tutto a posto · 1 qualcosa da fare.
# Registro: <METIS_LOG_DIR>/controllo.log; scadenza del login di Claude, un valore al giorno: <METIS_LOG_DIR>/scadenze.log
# (serve a vedere se la scadenza si sposta in avanti da sola con l'uso).

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "controllo: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
CLAUDE="${METIS_CLAUDE:-$(command -v claude || echo "$HOME/.local/bin/claude")}"
SRV="$METIS_ROOT/scripts/lib/servizi.sh"
PRE="${METIS_PREAVVISO_GIORNI:-7}"
OGGI=$(date +%s)
mkdir -p "$METIS_LOG_DIR"

if [ "${1:-}" = installa ]; then
  bash "$SRV" genera controllo orari "${METIS_ORARI_CONTROLLO:-07:15}" /bin/bash "$METIS_ROOT/scripts/server/controllo-giornaliero.sh" || exit 1
  bash "$SRV" carica controllo; exit $?
fi
MUTO=""; [ "${1:-}" = --muto ] && MUTO=1

OK=(); PROBLEMI=(); SISTEMATI=()
ok() { OK+=("$1"); }; problema() { PROBLEMI+=("$1"); }; sistemato() { SISTEMATI+=("$1"); }
# Principio (10/11/2026): ciò che si ripara senza decisioni si ripara qui, e al cliente arriva il rendiconto, non la domanda.
giorni_a() { echo $(( ($1 - OGGI) / 86400 )); }   # giorni da oggi a un istante (secondi)

# --- Claude: login completo (Remote Control, connettori) ---------------------------------------------------------
if [ -s "$HOME/.claude/.credentials.json" ]; then
  ST=$(env -u CLAUDE_CODE_OAUTH_TOKEN "$CLAUDE" auth status 2>/dev/null)
  SCAD=$(printf '%s' "$ST" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("loginExpiresAt") or "")
except Exception: print("")')
  if ! printf '%s' "$ST" | grep -q '"loggedIn": true'; then
    problema "Il login di Claude non è più valido: l'app non raggiunge la sessione. Scrivi /accesso a questo bot per rifarlo."
  elif [ -n "$SCAD" ]; then
    echo "$(date +%F) $SCAD" >> "$METIS_LOG_DIR/scadenze.log"
    read -r T GG <<< "$(python3 -c 'import sys,datetime; d=datetime.datetime.fromisoformat(sys.argv[1].replace("Z","+00:00")); print(int(d.timestamp()), d.astimezone().strftime("%d/%m"))' "$SCAD")"
    G=$(giorni_a "$T")
    if [ "$G" -le "$PRE" ]; then problema "Il login di Claude scade fra $G giorni ($GG). Scrivi /accesso a questo bot per rinnovarlo: ti mando un link, autorizzi e mi rimandi il codice."
    else ok "login di Claude valido ancora $G giorni"; fi
  else ok "login di Claude valido (scadenza non dichiarata)"; fi
fi
# --- Claude: un giro vero, con l'accesso che usano i giri ------------------------------------------------------------
if printf 'Rispondi solo: ok' | bash "$METIS_ROOT/scripts/con-timeout.sh" 120 "$CLAUDE" -p --model haiku >/dev/null 2>&1; then ok "Claude risponde"
else problema "Claude non risponde ai giri automatici (login o abbonamento): scrivi /accesso a questo bot, o avvisa chi ti assiste."; fi
# --- token di riserva (claude setup-token, un anno dal salvataggio) -------------------------------------------------
if [ -n "${METIS_CLAUDE_TOKEN_FILE:-}" ] && [ -f "$METIS_CLAUDE_TOKEN_FILE" ]; then
  G=$(giorni_a $(( $(metis_mtime "$METIS_CLAUDE_TOKEN_FILE") + 365 * 86400 )))
  if [ "$G" -le "$((PRE + 7))" ]; then problema "Il token di riserva di Claude scade fra circa $G giorni: chi ti assiste lo rinnova (login-claude.sh token)."
  else ok "token di riserva: circa $G giorni"; fi
fi
# --- sessione principale e bot ----------------------------------------------------------------------------------------
if bash "$SRV" esiste sessione 2>/dev/null; then
  if bash "$METIS_ROOT/scripts/sessione-principale.sh" stato >/dev/null 2>&1; then ok "sessione principale attiva"
  else
    bash "$SRV" carica sessione >/dev/null 2>&1; sleep "${METIS_ATTESA_RIAVVIO:-60}"   # il guardiano ricrea tmux e Claude
    if bash "$METIS_ROOT/scripts/sessione-principale.sh" stato >/dev/null 2>&1; then sistemato "la sessione principale era ferma: l'ho riavviata"
    else problema "La sessione principale è ferma e non riparte da sola: avvisa chi ti assiste."; fi
  fi
fi
if bash "$SRV" esiste telegram 2>/dev/null; then
  if bash "$SRV" stato telegram >/dev/null 2>&1; then ok "ascoltatore del bot attivo"
  else
    bash "$SRV" carica telegram >/dev/null 2>&1; sleep 5
    bash "$SRV" stato telegram >/dev/null 2>&1 && sistemato "il bot era fermo: l'ho riavviato" || problema "L'ascoltatore del bot è fermo e non riparte: avvisa chi ti assiste."
  fi
fi
# --- Google (posta locale) --------------------------------------------------------------------------------------------
if [ "${METIS_POSTA:-}" = locale ]; then
  R=$(python3 "$METIS_ROOT/scripts/google-token.py" 2>&1); case $? in
    0) ok "autorizzazione Google valida" ;;
    1) problema "L'autorizzazione di Google non vale più: la posta non arriva. Avvisa chi ti assiste ($R)." ;;
    *) ok "Google non raggiungibile ora, si riprova domani" ;;
  esac
fi
# --- sincronizzazione dei file (sync.sh scrive l'ora dell'ultimo giro riuscito) ---------------------------------------
if [ -f "$CFG_DIR/sync-ultimo" ]; then
  ORE=$(( (OGGI - $(cat "$CFG_DIR/sync-ultimo")) / 3600 ))
  if [ "$ORE" -gt 26 ]; then
    if bash "$METIS_ROOT/scripts/moduli/sync.sh" giro >/dev/null 2>&1; then sistemato "la sincronizzazione era ferma da $ORE ore: l'ho rifatta"
    else problema "I file non si sincronizzano da $ORE ore e il nuovo tentativo non è riuscito: avvisa chi ti assiste."; fi
  else ok "sincronizzazione riuscita $ORE ore fa"; fi
fi
# --- spazio ------------------------------------------------------------------------------------------------------------
USO=$(df -P "$HOME" | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ "${USO:-0}" -ge "${METIS_SPAZIO_MAX:-85}" ]; then problema "Il disco del server è pieno al $USO%: avvisa chi ti assiste."; else ok "disco al $USO%"; fi

# --- esito ---------------------------------------------------------------------------------------------------------
{
  echo "[$(date '+%Y-%m-%d %H:%M')] ${#OK[@]} a posto, ${#SISTEMATI[@]} sistemate, ${#PROBLEMI[@]} da fare"
  for x in "${OK[@]}"; do echo "  ✅ $x"; done
  for x in ${SISTEMATI[@]+"${SISTEMATI[@]}"}; do echo "  🔧 $x"; done
  for x in ${PROBLEMI[@]+"${PROBLEMI[@]}"}; do echo "  ❌ $x"; done
} | tee -a "$METIS_LOG_DIR/controllo.log"
if [ $(( ${#PROBLEMI[@]} + ${#SISTEMATI[@]} )) -gt 0 ] && [ -z "$MUTO" ] && bash "$SRV" esiste telegram 2>/dev/null; then
  {
    [ ${#SISTEMATI[@]} -gt 0 ] && { echo "Controllo del mattino: ho sistemato ${#SISTEMATI[@]} cose."; for x in "${SISTEMATI[@]}"; do echo "- $x"; done; }
    [ ${#PROBLEMI[@]} -gt 0 ] && { echo "Da fare (${#PROBLEMI[@]}):"; for x in "${PROBLEMI[@]}"; do echo "- $x"; done; }
  } | python3 "$METIS_ROOT/scripts/telegram/metis_telegram.py" invia >/dev/null 2>&1 || echo "  (messaggio Telegram non riuscito)"
fi
[ ${#PROBLEMI[@]} -gt 0 ] && exit 1
exit 0
