#!/bin/bash
# pre-compact.sh — hook PreCompact di Metis: prima che Claude Code compatti la conversazione, salva una traccia
# di ciò che si stava facendo, che l'hook di avvio rimette nel contesto quando la sessione riparte (source=compact).
# Traccia: note del vault toccate nelle ultime tre ore, ultime righe del log di sessione di oggi, stati toccati oggi.
# File: <cartella di Claude>/cache/pre-compact.md (sovrascritto a ogni compattazione). Solo dentro il vault configurato.

export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
METIS_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
INPUT=$(cat 2>/dev/null)
metis_carica_config || exit 0
CWD=$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
metis_dentro_vault "${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}" || exit 0

mkdir -p "$METIS_CL/cache"
OUT="$METIS_CL/cache/pre-compact.md"
OGGI=$(date '+%Y-%m-%d')
{
  echo "# Traccia prima della compattazione ($(date '+%Y-%m-%d %H:%M'))"
  echo ""
  echo "## Note toccate nelle ultime tre ore"
  find "$METIS_VAULT" -name '*.md' -mmin -180 -not -path '*/.obsidian/*' -not -path "$METIS_CL/cache/*" 2>/dev/null \
    | sed "s|^$METIS_VAULT/|- |" | head -30
  echo ""
  echo "## Stati toccati oggi"
  find "$METIS_CL/stati" -maxdepth 1 -name '*.md' -newermt "$OGGI" 2>/dev/null | sed "s|^$METIS_VAULT/|- |"
  if [ -f "$METIS_CL/sessioni/$OGGI.md" ]; then
    echo ""
    echo "## Ultime righe del log di sessione di oggi"
    tail -20 "$METIS_CL/sessioni/$OGGI.md"
  fi
} > "$OUT"
exit 0
