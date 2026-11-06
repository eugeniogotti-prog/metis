#!/bin/bash
# verifica-dotazione.sh — blocco 0 dell'installazione: che cosa c'è sul computer e che cosa manca per ciascun modulo.
# Sistemi: macOS, oppure Linux (Ubuntu) con systemd, per un server. METIS_SISTEMA=Darwin|Linux lo forza, per le prove.
# Uso: verifica-dotazione.sh [modulo ...]     (senza argomenti: le fondamenta e tutti i moduli)
# Moduli: fondamenta markitdown docx google microsoft telegram voce routine
# Uscita: una riga per requisito (✅ presente, ❌ manca, ⚠️ da guardare) e, in fondo, i moduli installabili.
# Codice: 0 se tutti i requisiti dei moduli chiesti ci sono, 1 altrimenti. Non installa niente.

set -uo pipefail
MODULI="${*:-fondamenta markitdown google telegram voce routine}"
MANCA=0
# Homebrew fuori dal PATH (tipico di launchd e di shell nuove): si cerca anche nei percorsi standard.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin"

SIS="${METIS_SISTEMA:-$(uname -s)}"
# come <comando-mac> <comando-linux>: il comando da dare al cliente per installare ciò che manca
come() { if [ "$SIS" = Linux ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
riga() { printf '%s %-24s %s\n' "$1" "$2" "$3"; }
cmd() {  # cmd <nome> <comando> <come si installa>
  if command -v "$2" >/dev/null 2>&1; then riga "✅" "$1" "$(command -v "$2")"
  else riga "❌" "$1" "manca: $3"; MANCA=1; fi
}

for m in $MODULI; do
  echo "## $m"
  case "$m" in
    fondamenta)
      case "$SIS" in
        Darwin) riga "✅" "macOS" "$(sw_vers -productVersion 2>/dev/null)" ;;
        Linux)
          riga "✅" "Linux" "$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-}")"
          if command -v systemctl >/dev/null 2>&1; then riga "✅" "systemd" "$(systemctl --version 2>/dev/null | head -1)"
          else riga "❌" "systemd" "serve per gli automatismi: Metis su Linux usa i timer di systemd"; MANCA=1; fi ;;
        *) riga "❌" "sistema" "Metis funziona su macOS e su Linux con systemd ($SIS)"; MANCA=1 ;;
      esac
      cmd "Claude Code" claude "https://claude.com/claude-code"
      if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        riga "⚠️" "chiave API esportata" "ANTHROPIC_API_KEY è impostata: Claude Code fatturerebbe sulla Console invece che sull'abbonamento"; MANCA=1
      else riga "✅" "chiave API esportata" "nessuna (si usa l'abbonamento)"; fi
      cmd "python3" python3 "$(come "xcode-select --install" "sudo apt install python3")"
      cmd "jq" jq "$(come "brew install jq" "sudo apt install jq")"
      cmd "git" git "$(come "xcode-select --install" "sudo apt install git")"
      if [ "$SIS" = Linux ]; then
        riga "ℹ️" "Obsidian" "non gira su un server: Claude scrive sui file e dice quando i collegamenti fra note non sono aggiornati; spostamenti e rinomine dal Mac"
        if bash "$(dirname "$0")/lib/systemd.sh" permanenza; then riga "✅" "automatismi permanenti" "linger attivo per $(id -un)"
        else riga "⚠️" "automatismi permanenti" "senza linger si fermano quando si chiude l'ultima sessione SSH: sudo loginctl enable-linger $(id -un)"; fi
      else
        if [ -d "/Applications/Obsidian.app" ]; then riga "✅" "Obsidian" "/Applications/Obsidian.app"
        else riga "⚠️" "Obsidian" "non trovato in /Applications: Metis funziona anche su una cartella di markdown, senza spostamenti che aggiornano i link"; fi
        if command -v obsidian >/dev/null 2>&1; then riga "✅" "CLI di Obsidian" "$(command -v obsidian)"
        else riga "⚠️" "CLI di Obsidian" "non registrata: Obsidian → Impostazioni → Generali → CLI"; fi
        cmd "Homebrew" brew "https://brew.sh"
      fi ;;
    markitdown)
      cmd "uv" uv "$(come "brew install uv" "curl -LsSf https://astral.sh/uv/install.sh | sh")" ;;
    docx)
      cmd "pandoc" pandoc "$(come "brew install pandoc" "sudo apt install pandoc")"
      cmd "python3" python3 "$(come "xcode-select --install" "sudo apt install python3")" ;;
    microsoft)
      riga "ℹ️" "connettore Microsoft 365" "si attiva da claude.ai → Impostazioni → Connettori; serve il consenso di un amministratore Entra e un account Microsoft 365 aziendale" ;;
    google)
      riga "ℹ️" "connettori claude.ai" "si attivano da claude.ai → Impostazioni → Connettori; il controllo è google.sh connettori"
      command -v npx >/dev/null 2>&1 && riga "✅" "node (npx)" "per il server locale facoltativo" || riga "ℹ️" "node (npx)" "serve solo al server locale facoltativo: $(come "brew install node" "sudo apt install nodejs npm")" ;;
    telegram)
      cmd "curl" curl "$(come "preinstallato su macOS" "sudo apt install curl")"
      cmd "python3" python3 "$(come "xcode-select --install" "sudo apt install python3")" ;;
    voce)
      cmd "ffmpeg" ffmpeg "$(come "brew install ffmpeg" "sudo apt install ffmpeg")"
      cmd "curl" curl "$(come "preinstallato su macOS" "sudo apt install curl")" ;;
    routine)
      if [ "$SIS" = Linux ]; then
        cmd "systemctl" systemctl "Metis su Linux usa i timer di systemd"
        riga "ℹ️" "server acceso" "le routine girano anche senza nessuno collegato, se c'è il linger (vedi fondamenta)"
      else
        cmd "launchctl" launchctl "preinstallato su macOS"
        riga "ℹ️" "Mac acceso" "le routine girano solo a Mac acceso agli orari scelti"
      fi ;;
    *) riga "❌" "$m" "modulo sconosciuto"; MANCA=1 ;;
  esac
  echo ""
done
exit "$MANCA"
