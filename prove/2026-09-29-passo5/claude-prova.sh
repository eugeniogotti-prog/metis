#!/bin/bash
# claude-prova.sh — una sessione non interattiva di Claude Code nel vault di prova, con il plugin Metis.
# Uso: bash claude-prova.sh <file di uscita> [--continue] < prompt
#   Il prompt si passa sullo stdin. Con --continue riprende l'ultima conversazione nel vault.
# Impostazioni utente escluse (niente hook né plugin dell'utente della macchina). Il CLAUDE.md globale
# dell'utente viene comunque caricato da Claude Code: vale per tutte le sessioni della prova, prima e dopo.
set -uo pipefail
QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USCITA="${1:?file di uscita}"; shift
export METIS_CONFIG="$QUI/config"
# Il plugin si carica da una copia fuori dal repository: Claude Code tratta come «sensitive» ogni file
# dentro la cartella di un plugin caricato, e il vault di prova sta dentro il repository.
COPIA="${TMPDIR:-/tmp}/metis-plugin-prova"
rsync -a --delete --exclude .git --exclude prove "$QUI/../../" "$COPIA/"
cd "$QUI/vault" || exit 2
claude -p "$@" \
  --plugin-dir "$COPIA" \
  --setting-sources project,local \
  --permission-mode acceptEdits \
  --add-dir "$QUI/documenti" --add-dir "$QUI/lavoro" --add-dir "$COPIA/skills" \
  --allowedTools "Write" "Edit" "Bash(ls:*)" "Bash(wc:*)" "Bash(grep:*)" "Bash(date:*)" \
  > "$USCITA" 2>&1
echo "uscita $? → $USCITA ($(wc -c < "$USCITA") byte)"
