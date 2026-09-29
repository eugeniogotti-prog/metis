#!/bin/bash
# installa-struttura.sh — blocco 1 dell'installazione: le cartelle del vault.
# Uso:
#   installa-struttura.sh albero <cartella>   stampa l'albero (tre livelli, conteggio delle note) per proporre la mappatura; non scrive niente
#   installa-struttura.sh crea                crea le cartelle dei ruoli mappati che mancano (configurazione in $METIS_CONFIG); non sposta niente
#   installa-struttura.sh controlla           verifica che ogni ruolo assegnato punti a una cartella esistente
# Decisione del 29/9: in un vault esistente le note non si spostano; PARA si propone solo per i vault nuovi.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"

case "${1:-}" in
  albero)
    D="${2:?manca la cartella}"; [ -d "$D" ] || { echo "cartella non trovata: $D" >&2; exit 2; }
    echo "Albero di $D (fino a tre livelli; fra parentesi le note .md contenute, a ogni profondità):"
    find "$D" -mindepth 1 -maxdepth 3 -type d -not -path '*/.*' 2>/dev/null | sort | while IFS= read -r d; do
      liv=$(( $(printf '%s' "${d#$D/}" | tr -cd '/' | wc -c) ))
      n=$(find "$d" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
      printf '%*s%s/ (%s)\n' $((liv*2)) '' "$(basename "$d")" "$n"
    done
    echo "Note alla radice: $(find "$D" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
    [ -f "$D/CLAUDE.md" ] && echo "Attenzione: c'è già un CLAUDE.md alla radice (si conserva come parte del cliente)."
    [ -d "$D/.obsidian" ] && echo "È un vault di Obsidian (.obsidian presente)."
    git -C "$D" rev-parse --show-toplevel >/dev/null 2>&1 && echo "Sta dentro un repository git: la memoria di Claude Code segue la radice del repository."
    exit 0 ;;
  crea|controlla)
    metis_carica_config || { echo "${METIS_ERRORE}" >&2; exit 2; }
    ERR=0
    for r in $METIS_RUOLI; do
      d=$(metis_ruolo "$r"); [ -n "$d" ] || continue
      if [ -d "$d" ]; then echo "✅ $r → ${d#$METIS_VAULT/}"
      elif [ "$1" = crea ]; then mkdir -p "$d" && echo "➕ $r → ${d#$METIS_VAULT/} (creata)"
      else echo "❌ $r → ${d#$METIS_VAULT/} (non esiste)"; ERR=1; fi
    done
    if [ "$1" = crea ]; then
      INBOX=$(metis_ruolo INBOX)
      for f in $METIS_INBOX_FONTI; do [ -d "$INBOX/$f" ] || { mkdir -p "$INBOX/$f" && echo "➕ Inbox/$f (creata)"; }; done
      mkdir -p "$METIS_FONTI" && echo "✅ cartella fonti: $METIS_FONTI"
    fi
    exit "$ERR" ;;
  *) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
