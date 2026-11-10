#!/bin/bash
# sessione-principale.sh — tiene sempre accesa la sessione principale di Claude del cliente, su un server.
# Il cliente la usa senza terminale: dall'app di Claude (Remote Control) e da Telegram (l'ascoltatore del bot le consegna
# i messaggi, con METIS_CONVERSAZIONE=sessione). Una sola sessione: i lavori lunghi li fa con i sottoagenti.
#
# Uso:
#   sessione-principale.sh guarda      il guardiano: crea la sessione tmux, avvia Claude, lo rilancia se si ferma (ogni 30 s).
#                                      Lo avvia un servizio sempre acceso: servizi.sh genera sessione sempre … guarda
#   sessione-principale.sh installa    genera e carica quel servizio; imposta METIS_CONVERSAZIONE=sessione
#   sessione-principale.sh stato       tmux e Claude ci sono? (uscita 1 se no)
#   sessione-principale.sh scrivi      legge un testo dallo stdin e lo consegna alla sessione
# Configurazione: METIS_SESSIONE_TMUX (default metis-principale), METIS_SESSIONE_NOME (nome nell'app di Claude, default
# «<prodotto> di <utente>»), METIS_CLAUDE_TOKEN_FILE (login con un token di lunga durata).
# La conversazione riprende sempre lo stesso session-id (in <cartella della configurazione>/sessione-id): un riavvio del
# server o di Claude non la perde. Registro: <METIS_LOG_DIR>/sessione.log. Per guardarla dal server: tmux attach -t <nome>.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "sessione: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
T="${METIS_SESSIONE_TMUX:-metis-principale}"
NOME="${METIS_SESSIONE_NOME:-$METIS_PRODOTTO di $(id -un)}"
SID_FILE="$CFG_DIR/sessione-id"
LOG="$METIS_LOG_DIR/sessione.log"
CLAUDE="${METIS_CLAUDE:-$(command -v claude || echo "$HOME/.local/bin/claude")}"
# Nessuna domanda che blocchi una sessione che nessuno guarda: niente suggerimenti di prompt.
IMPOSTAZIONI='{"promptSuggestionEnabled":false}'
mkdir -p "$METIS_LOG_DIR"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

claude_vivo() {
  local p; p=$(tmux list-panes -t "$T" -F '#{pane_pid}' 2>/dev/null | head -1)
  [ -n "$p" ] && pgrep -P "$p" -f claude >/dev/null 2>&1
}

consegna() {  # consegna <testo>: incolla nella sessione e invia (secondo Invio se il testo resta «Pasted text»)
  local b="metis-$$-$RANDOM"
  printf '%s' "$1" | tmux load-buffer -b "$b" - && tmux paste-buffer -d -b "$b" -t "$T"
  sleep 1; tmux send-keys -t "$T" Enter; sleep 2
  tmux capture-pane -p -t "$T" | tail -8 | grep -q 'Pasted text' && tmux send-keys -t "$T" Enter
  return 0
}

avvio() {
  cat <<EOF
Sei la sessione principale di $METIS_PRODOTTO per $(id -un), sempre accesa su un server. Il cliente ti scrive dall'app di Claude o da Telegram: i messaggi da Telegram arrivano qui con «[Telegram]» davanti e la risposta va mandata con il comando indicato nel messaggio, perché il cliente non vede questo schermo. Rispondi nello stesso canale da cui arriva il messaggio. Per i lavori lunghi usa un sottoagente e intanto resta disponibile. Rileggi ora le istruzioni del vault (CLAUDE.md) e lo stato attuale, poi aspetta.
EOF
}

lancia() {
  local sid az
  sid=""; [ -f "$SID_FILE" ] && sid=$(tr -d '[:space:]' < "$SID_FILE")
  if [ -n "$sid" ] && ls "$HOME/.claude/projects/"*/"$sid.jsonl" >/dev/null 2>&1; then az="--resume $sid"; log "riprendo la sessione ${sid:0:8}"
  else sid=$(python3 -c 'import uuid; print(uuid.uuid4())'); echo "$sid" > "$SID_FILE"; az="--session-id $sid"; log "sessione nuova ${sid:0:8}"; fi
  # Il token (se c'è) passa nell'ambiente della shell di tmux, non sulla riga di comando: non compare in ps né nello schermo.
  local pre="unset CLAUDE_CODE_OAUTH_TOKEN; "
  # Con il login completo (Remote Control, connettori) il token non si passa: lo scavalcherebbe (config.sh).
  if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ ! -s "$HOME/.claude/.credentials.json" ]; then
    tmux set-environment -t "$T" CLAUDE_CODE_OAUTH_TOKEN "$CLAUDE_CODE_OAUTH_TOKEN"
    pre="export CLAUDE_CODE_OAUTH_TOKEN=\"\$(tmux show-environment CLAUDE_CODE_OAUTH_TOKEN | cut -d= -f2-)\"; "
  else tmux set-environment -u -t "$T" CLAUDE_CODE_OAUTH_TOKEN 2>/dev/null; fi
  tmux send-keys -t "$T" "clear; $pre""cd \"$METIS_VAULT\" && \"$CLAUDE\" --dangerously-skip-permissions --settings '$IMPOSTAZIONI' --remote-control \"$NOME\" $az" Enter
  sleep 25
  if claude_vivo; then
    [ "${az%% *}" = --session-id ] && consegna "$(avvio)"
    log "Claude attivo"
  else log "Claude non partito dopo 25 s: riprovo al giro dopo"; fi
}

case "${1:-}" in
  guarda)
    log "guardiano avviato"
    while true; do
      if ! tmux has-session -t "$T" 2>/dev/null; then
        log "sessione tmux assente: la creo"
        tmux new-session -d -s "$T" -c "$METIS_VAULT" -x 200 -y 50; sleep 2; lancia
      elif ! claude_vivo; then
        log "Claude fermo: lo rilancio"; lancia
      fi
      sleep 30
    done ;;
  installa)
    command -v tmux >/dev/null || { echo "sessione: manca tmux (sudo apt install tmux)" >&2; exit 1; }
    bash "$METIS_ROOT/scripts/lib/servizi.sh" genera sessione sempre /bin/bash "$METIS_ROOT/scripts/sessione-principale.sh" guarda || exit 1
    bash "$METIS_ROOT/scripts/configura.sh" set METIS_CONVERSAZIONE sessione >/dev/null
    bash "$METIS_ROOT/scripts/lib/servizi.sh" carica sessione || exit 1
    echo "sessione: sessione principale «$NOME» sempre accesa (tmux $T); i messaggi del bot vanno a lei" ;;
  stato)
    if claude_vivo; then echo "✅ sessione principale attiva (tmux $T)"; else echo "❌ sessione principale ferma (tmux $T)"; exit 1; fi ;;
  scrivi)
    tmux has-session -t "$T" 2>/dev/null || { echo "sessione: $T assente" >&2; exit 1; }
    consegna "$(cat)" ;;
  *) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
