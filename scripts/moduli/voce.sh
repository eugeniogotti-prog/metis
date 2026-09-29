#!/bin/bash
# voce.sh — modulo voce: un vocale mandato al bot diventa testo (Groq, whisper-large-v3).
# Uso:
#   voce.sh chiave      legge la chiave di Groq dallo stdin (non si vede a schermo) e la salva in ~/.config/metis/groq (600)
#   voce.sh controlla   ffmpeg presente, chiave protetta, una trascrizione vera di un secondo di silenzio
# Richiede il modulo telegram con l'ascoltatore acceso. L'audio passa dai server di Telegram e di Groq: va detto al cliente.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "voce: ${METIS_ERRORE}" >&2; exit 2; }
SEG="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")/groq"
# Se la configurazione indica un file esistente con la chiave (METIS_GROQ_FILE), si controlla quello: nessuna copia.
G_FILE="$(bash "$METIS_ROOT/scripts/configura.sh" get METIS_GROQ_FILE 2>/dev/null)"; [ -n "$G_FILE" ] && SEG="${G_FILE/#\~/$HOME}"

case "${1:-}" in
  chiave)
    echo "Incolla la chiave API di Groq (console.groq.com → API Keys) e premi Invio:" >&2
    IFS= read -rs K; echo >&2
    [ -n "$K" ] || { echo "voce: chiave vuota" >&2; exit 1; }
    ( umask 077; printf 'KEY=%s\n' "$K" > "$SEG" ); chmod 600 "$SEG"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI voce
    echo "voce: chiave salvata" ;;
  controlla)
    ERR=0
    command -v ffmpeg >/dev/null 2>&1 || [ -x /opt/homebrew/bin/ffmpeg ] && echo "✅ ffmpeg presente" || { echo "❌ manca ffmpeg (brew install ffmpeg)"; ERR=1; }
    [ "$(stat -f %Lp "$SEG" 2>/dev/null)" = 600 ] && echo "✅ chiave di Groq protetta (600)" || { echo "❌ chiave di Groq assente o leggibile da altri: $SEG"; ERR=1; }
    if [ "$ERR" = 0 ]; then
      OUT=$(python3 "$METIS_ROOT/scripts/telegram/metis_telegram.py" prova-trascrizione 2>&1) && echo "✅ $OUT" || { echo "❌ trascrizione non riuscita: $(printf '%s' "$OUT" | tail -1)"; ERR=1; }
    fi
    exit "$ERR" ;;
  *) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
