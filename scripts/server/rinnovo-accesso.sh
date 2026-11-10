#!/bin/bash
# rinnovo-accesso.sh — rifà il login completo di Claude (claude auth login) su un server, guidato da Telegram, senza terminale.
# Lo usa l'ascoltatore del bot quando il cliente scrive «/accesso»:
#   1. avvia   lancia claude auth login in una sessione tmux a parte (metis-accesso), larga 400 colonne, ne cattura il link
#              di autorizzazione e lo stampa. Il bot lo manda al cliente.
#   2. codice  legge dallo stdin il codice che il cliente ha copiato dalla pagina e rimandato al bot, lo scrive nel login in
#              attesa, controlla che il login sia valido e riavvia la sessione principale, che così riparte con il login nuovo.
#   stato      dice se c'è un login in attesa del codice.
# Il codice non passa dalla riga di comando e non finisce nei registri. Il registro della sessione di login (che contiene il
# link) sta in <cartella della configurazione>/accesso.log con permessi 600 e si cancella alla fine.
# Uscite: 0 riuscito · 1 non riuscito (il messaggio dice perché).

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "accesso: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
CLAUDE="${METIS_CLAUDE:-$(command -v claude || echo "$HOME/.local/bin/claude")}"
T="metis-accesso"; L="$CFG_DIR/accesso.log"
pulito() { sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][^\x07]*\x07//g' "$L" 2>/dev/null | tr -d '\r'; }

case "${1:-}" in
  avvia)
    command -v tmux >/dev/null && command -v script >/dev/null || { echo "Sul server mancano tmux o script."; exit 1; }
    tmux kill-session -t "$T" 2>/dev/null
    ( umask 077; : > "$L" )
    tmux new-session -d -s "$T" -x 400 -y 50 "env -u CLAUDE_CODE_OAUTH_TOKEN script -q -f -c '\"$CLAUDE\" auth login' \"$L\""
    for _ in $(seq 60); do
      U=$(pulito | grep -oE 'https://[^ ]*(oauth|authorize)[^ ]*' | awk '{ if (length($0) > length(m)) m = $0 } END { print m }')
      [ -n "$U" ] && break; sleep 0.5
    done
    if [ -z "${U:-}" ]; then tmux kill-session -t "$T" 2>/dev/null; rm -f "$L"; echo "Il login di Claude non è partito: riprova fra qualche minuto o avvisa chi ti assiste."; exit 1; fi
    echo "$U" ;;
  codice)
    tmux has-session -t "$T" 2>/dev/null || { echo "Nessun login in attesa: scrivi di nuovo /accesso."; exit 1; }
    C=$(tr -d '[:space:]'); [ -n "$C" ] || { echo "Codice vuoto."; exit 1; }
    B="metis-codice-$$"; printf '%s' "$C" | tmux load-buffer -b "$B" - && tmux paste-buffer -d -b "$B" -t "$T"
    sleep 1; tmux send-keys -t "$T" Enter
    for _ in $(seq 40); do tmux has-session -t "$T" 2>/dev/null || break; sleep 0.5; done
    tmux kill-session -t "$T" 2>/dev/null; rm -f "$L"
    if env -u CLAUDE_CODE_OAUTH_TOKEN "$CLAUDE" auth status 2>/dev/null | grep -q '"loggedIn": true'; then
      S=$(env -u CLAUDE_CODE_OAUTH_TOKEN "$CLAUDE" auth status 2>/dev/null | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("loginExpiresAt") or "")
except Exception: print("")')
      # La sessione principale riparte con il login nuovo (il guardiano la rilancia sulla stessa conversazione).
      tmux kill-session -t "${METIS_SESSIONE_TMUX:-metis-principale}" 2>/dev/null
      echo "Login di Claude rinnovato${S:+, valido fino al $(python3 -c 'import sys,datetime; print(datetime.datetime.fromisoformat(sys.argv[1].replace("Z","+00:00")).astimezone().strftime("%d/%m/%Y"))' "$S")}. La sessione riparte entro un minuto."
    else echo "Il codice non è stato accettato: scrivi di nuovo /accesso e usa il codice nuovo (vale una volta sola)."; exit 1; fi ;;
  stato)
    tmux has-session -t "$T" 2>/dev/null && echo "login in attesa del codice" || { echo "nessun login in attesa"; exit 1; } ;;
  *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
