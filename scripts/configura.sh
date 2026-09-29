#!/bin/bash
# configura.sh — legge e scrive la configurazione di Metis, una chiave alla volta.
# Uso:
#   configura.sh get CHIAVE            stampa il valore (vuoto se assente)
#   configura.sh set CHIAVE valore     scrive o sostituisce la riga CHIAVE=valore
#   configura.sh aggiungi CHIAVE voce  aggiunge una voce a una lista separata da spazi, se manca (es. METIS_MODULI)
#   configura.sh mostra                stampa la configurazione senza commenti
# File: $METIS_CONFIG, oppure ~/.config/metis/config (creato con permessi 600 se manca).
# Accetta solo chiavi METIS_[A-Z0-9_]+; il valore si scrive su una riga, senza a capo.

set -uo pipefail
CFG="${METIS_CONFIG:-$HOME/.config/metis/config}"
AZIONE="${1:-}"; CHIAVE="${2:-}"
valida() { [[ "$1" =~ ^METIS_[A-Z0-9_]+$ ]] || { echo "configura: chiave non valida: $1" >&2; exit 2; }; }

if [ ! -f "$CFG" ]; then
  mkdir -p "$(dirname "$CFG")"
  ( umask 077; printf '# Configurazione di Metis. Una riga CHIAVE=valore; si legge e non si esegue.\n' > "$CFG" )
fi

case "$AZIONE" in
  get)
    valida "$CHIAVE"
    grep -E "^$CHIAVE=" "$CFG" | tail -1 | cut -d= -f2- ;;
  set)
    valida "$CHIAVE"; VALORE="${3-}"
    case "$VALORE" in *$'\n'*) echo "configura: il valore non può andare a capo" >&2; exit 2 ;; esac
    TMP=$(mktemp "$CFG.XXXXXX")
    grep -vE "^$CHIAVE=" "$CFG" > "$TMP"
    printf '%s=%s\n' "$CHIAVE" "$VALORE" >> "$TMP"
    chmod 600 "$TMP"; mv "$TMP" "$CFG"
    echo "configura: $CHIAVE impostata" ;;
  aggiungi)
    valida "$CHIAVE"; VOCE="${3:?manca la voce}"
    ATTUALE=$(bash "$0" get "$CHIAVE")
    case " $ATTUALE " in *" $VOCE "*) echo "configura: $VOCE già presente in $CHIAVE"; exit 0 ;; esac
    bash "$0" set "$CHIAVE" "$(printf '%s %s' "$ATTUALE" "$VOCE" | sed 's/^ //')" ;;
  mostra)
    grep -vE '^[[:space:]]*(#|$)' "$CFG" ;;
  *)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
