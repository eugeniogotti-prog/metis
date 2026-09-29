#!/bin/bash
# verifica-dotazione.sh — blocco 0 dell'installazione: che cosa c'è sul Mac e che cosa manca per ciascun modulo.
# Uso: verifica-dotazione.sh [modulo ...]     (senza argomenti: le fondamenta e tutti i moduli)
# Moduli: fondamenta markitdown google telegram voce routine
# Uscita: una riga per requisito (✅ presente, ❌ manca, ⚠️ da guardare) e, in fondo, i moduli installabili.
# Codice: 0 se tutti i requisiti dei moduli chiesti ci sono, 1 altrimenti. Non installa niente.

set -uo pipefail
MODULI="${*:-fondamenta markitdown google telegram voce routine}"
MANCA=0
# Homebrew fuori dal PATH (tipico di launchd e di shell nuove): si cerca anche nei percorsi standard.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin"

riga() { printf '%s %-24s %s\n' "$1" "$2" "$3"; }
cmd() {  # cmd <nome> <comando> <come si installa>
  if command -v "$2" >/dev/null 2>&1; then riga "✅" "$1" "$(command -v "$2")"
  else riga "❌" "$1" "manca: $3"; MANCA=1; fi
}

for m in $MODULI; do
  echo "## $m"
  case "$m" in
    fondamenta)
      if [ "$(uname -s)" = "Darwin" ]; then riga "✅" "macOS" "$(sw_vers -productVersion 2>/dev/null)"
      else riga "❌" "macOS" "la v1 funziona solo su Mac ($(uname -s))"; MANCA=1; fi
      cmd "Claude Code" claude "https://claude.com/claude-code"
      if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        riga "⚠️" "chiave API esportata" "ANTHROPIC_API_KEY è impostata: Claude Code fatturerebbe sulla Console invece che sull'abbonamento"; MANCA=1
      else riga "✅" "chiave API esportata" "nessuna (si usa l'abbonamento)"; fi
      cmd "python3" python3 "xcode-select --install"
      cmd "jq" jq "brew install jq"
      cmd "git" git "xcode-select --install"
      if [ -d "/Applications/Obsidian.app" ]; then riga "✅" "Obsidian" "/Applications/Obsidian.app"
      else riga "⚠️" "Obsidian" "non trovato in /Applications: Metis funziona anche su una cartella di markdown, senza spostamenti che aggiornano i link"; fi
      if command -v obsidian >/dev/null 2>&1; then riga "✅" "CLI di Obsidian" "$(command -v obsidian)"
      else riga "⚠️" "CLI di Obsidian" "non registrata: Obsidian → Impostazioni → Generali → CLI"; fi
      cmd "Homebrew" brew "https://brew.sh" ;;
    markitdown)
      cmd "uv" uv "brew install uv" ;;
    google)
      cmd "node (npx)" npx "brew install node"
      riga "ℹ️" "connettori claude.ai" "si attivano da claude.ai → Impostazioni → Connettori; non si verificano da qui" ;;
    telegram)
      cmd "curl" curl "preinstallato su macOS"
      cmd "python3" python3 "xcode-select --install" ;;
    voce)
      cmd "ffmpeg" ffmpeg "brew install ffmpeg"
      cmd "curl" curl "preinstallato su macOS" ;;
    routine)
      cmd "launchctl" launchctl "preinstallato su macOS"
      riga "ℹ️" "Mac acceso" "le routine girano solo a Mac acceso agli orari scelti" ;;
    *) riga "❌" "$m" "modulo sconosciuto"; MANCA=1 ;;
  esac
  echo ""
done
exit "$MANCA"
