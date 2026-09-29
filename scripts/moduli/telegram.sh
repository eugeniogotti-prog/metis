#!/bin/bash
# telegram.sh — modulo Telegram: il bot del cliente.
# Uso:
#   telegram.sh token          legge il token del bot dallo stdin (non si vede a schermo) e lo salva in ~/.config/metis/telegram (600)
#   telegram.sh chat           dopo che il cliente ha scritto al bot: trova la sua chat privata e la salva
#   telegram.sh prova          manda un messaggio di prova alla chat del cliente (unico destinatario ammesso)
#   telegram.sh ascoltatore [--senza-caricare]   genera il LaunchAgent sempre acceso che ascolta il bot e lo carica
#   telegram.sh installa       i passi sopra in fila, fermandosi a quello che manca
#   telegram.sh controlla      token valido, chat salvata, file protetti, ascoltatore caricato
# Il bot scrive solo alla chat del cliente e ascolta solo lei.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "telegram: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
SEG="$CFG_DIR/telegram"
TG=(python3 "$METIS_ROOT/scripts/telegram/metis_telegram.py")
API="${METIS_TELEGRAM_API:-https://api.telegram.org}"

scrivi_segreto() {  # scrivi_segreto CHIAVE valore
  ( umask 077; touch "$SEG" ); chmod 600 "$SEG"
  grep -v "^$1=" "$SEG" > "$SEG.tmp" 2>/dev/null; printf '%s=%s\n' "$1" "$2" >> "$SEG.tmp"
  chmod 600 "$SEG.tmp"; mv "$SEG.tmp" "$SEG"
}
leggi_segreto() { grep "^$1=" "$SEG" 2>/dev/null | tail -1 | cut -d= -f2-; }
token_valido() { "${TG[@]}" verifica >/dev/null 2>&1; [ $? -ne 1 ]; }   # 0 tutto a posto, 2 manca solo la chat
chat_salvata() { "${TG[@]}" verifica >/dev/null 2>&1; }

case "${1:-}" in
  token)
    echo "Incolla il token che ti ha dato @BotFather e premi Invio:" >&2
    IFS= read -rs T; echo >&2
    [[ "$T" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || { echo "telegram: non sembra un token di bot (numero:lettere)" >&2; exit 1; }
    scrivi_segreto TOKEN "$T"
    token_valido && echo "telegram: token salvato e valido" || { echo "telegram: token salvato, ma Telegram non lo riconosce" >&2; exit 1; } ;;
  chat)
    OUT=$("${TG[@]}" trova-chat) || { echo "telegram: nessun messaggio privato al bot. Scrivi «ciao» al bot dal telefono e rilancia." >&2; exit 1; }
    N=$(printf '%s\n' "$OUT" | grep -c .)
    [ "$N" = 1 ] || { echo "telegram: più chat hanno scritto al bot; scegli la tua:" >&2; printf '%s\n' "$OUT" >&2; exit 1; }
    scrivi_segreto CHAT_ID "$(printf '%s' "$OUT" | cut -f1)"
    echo "telegram: chat salvata ($(printf '%s' "$OUT" | cut -f2))" ;;
  prova)
    "${TG[@]}" invia "Messaggio di prova di $METIS_PRODOTTO: il bot funziona." && echo "telegram: messaggio di prova mandato" ;;
  ascoltatore)
    bash "$METIS_ROOT/scripts/lib/launchd.sh" genera telegram sempre /usr/bin/python3 "$METIS_ROOT/scripts/telegram/metis_telegram.py" ascolta || exit 1
    [ "${2:-}" = --senza-caricare ] || bash "$METIS_ROOT/scripts/lib/launchd.sh" carica telegram ;;
  installa)
    V=$("${TG[@]}" verifica 2>&1)
    case "$V" in *"token assente"*) echo "telegram: manca il token → telegram.sh token"; exit 1 ;; esac
    token_valido || { echo "telegram: il token salvato non è valido → telegram.sh token"; exit 1; }
    chat_salvata || bash "$0" chat || exit 1
    bash "$0" prova || exit 1
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI telegram
    echo "telegram: uscita pronta. Per l'Inbox dal telefono e la conversazione: telegram.sh ascoltatore" ;;
  controlla)
    ERR=0
    V=$("${TG[@]}" verifica 2>&1); RC=$?
    [ "$RC" = 0 ] && echo "✅ $(printf '%s' "$V" | head -1); chat del cliente salvata" || { echo "❌ $(printf '%s' "$V" | tr '\n' ' ')"; ERR=1; }
    if [ -f "${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}/$METIS_LABEL.telegram.plist" ]; then
      bash "$METIS_ROOT/scripts/lib/launchd.sh" stato telegram >/dev/null && echo "✅ ascoltatore caricato" || { echo "❌ ascoltatore generato ma non caricato"; ERR=1; }
    else echo "ℹ️ ascoltatore non installato: il bot manda soltanto (livello 1)"; fi
    exit "$ERR" ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
