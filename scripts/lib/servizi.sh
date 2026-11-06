#!/bin/bash
# servizi.sh — gli automatismi di Metis, su Mac e su Linux: sceglie launchd.sh (Mac) o systemd.sh (Linux).
# Uso (uguale sui due sistemi):
#   servizi.sh genera <nome> sempre <comando> [argomenti...]
#   servizi.sh genera <nome> orari "<HH:MM ...>" <comando> [argomenti...]   («lun 07:30»: solo il lunedì)
#   servizi.sh carica | scarica | stato | esiste <nome>
#   servizi.sh file                 elenca i file degli automatismi di Metis (plist o servizi e timer)
#   servizi.sh tipo                 «LaunchAgent» o «servizio systemd» (per i messaggi)
# Il sistema si legge con uname; METIS_SISTEMA=Darwin|Linux lo forza, per le prove.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
case "$(metis_sistema)" in
  Darwin) B="$METIS_ROOT/scripts/lib/launchd.sh"; TIPO="LaunchAgent" ;;
  Linux)  B="$METIS_ROOT/scripts/lib/systemd.sh"; TIPO="servizio systemd" ;;
  *) echo "servizi: sistema non gestito ($(metis_sistema)): servono macOS o Linux con systemd" >&2; exit 2 ;;
esac
case "${1:-}" in
  tipo) echo "$TIPO" ;;
  file)
    metis_carica_config || { echo "servizi: ${METIS_ERRORE}" >&2; exit 2; }
    if [ "$TIPO" = LaunchAgent ]; then D="${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}"; for f in "$D/$METIS_LABEL".*.plist; do [ -f "$f" ] && echo "$f"; done
    else D="${METIS_SYSTEMD_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}"; for f in "$D/$METIS_LABEL".*.service "$D/$METIS_LABEL".*.timer; do [ -f "$f" ] && echo "$f"; done; fi
    exit 0 ;;
  *) exec bash "$B" "$@" ;;
esac
