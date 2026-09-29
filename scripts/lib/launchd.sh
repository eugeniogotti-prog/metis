#!/bin/bash
# launchd.sh — genera e carica i LaunchAgent di Metis.
# Uso:
#   launchd.sh genera <nome> sempre <comando> [argomenti...]        processo sempre acceso (KeepAlive), es. l'ascoltatore del bot
#   launchd.sh genera <nome> orari "<HH:MM HH:MM ...>" <comando> [argomenti...]   giri ad orari fissi, ogni giorno
#   launchd.sh carica <nome>        carica (o ricarica) il LaunchAgent nella sessione dell'utente
#   launchd.sh scarica <nome>       lo ferma e lo toglie dalla sessione (il file resta)
#   launchd.sh stato <nome>         dice se è caricato
# Etichetta: $METIS_LABEL.<nome>; file in ~/Library/LaunchAgents (o in $METIS_LAUNCHAGENTS, per le prove).
# Il PATH dei LaunchAgent non contiene Homebrew: si aggiunge qui. I log vanno in $METIS_LOG_DIR/<nome>.log.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "launchd: ${METIS_ERRORE}" >&2; exit 2; }
DIR="${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}"
AZ="${1:-}"; NOME="${2:-}"
[ -n "$NOME" ] && [[ "$NOME" =~ ^[a-z0-9-]+$ ]] || { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
ETICHETTA="$METIS_LABEL.$NOME"; PLIST="$DIR/$ETICHETTA.plist"

case "$AZ" in
  genera)
    TIPO="${3:-}"; shift 3
    ORARI=""; [ "$TIPO" = orari ] && { ORARI="$1"; shift; }
    [ "$TIPO" = sempre ] || [ "$TIPO" = orari ] || { echo "launchd: tipo «$TIPO» sconosciuto (sempre|orari)" >&2; exit 2; }
    [ $# -ge 1 ] || { echo "launchd: manca il comando" >&2; exit 2; }
    mkdir -p "$DIR" "$METIS_LOG_DIR"
    export ETICHETTA PLIST TIPO ORARI METIS_LOG_DIR NOME CFG="${METIS_CONFIG:-$HOME/.config/metis/config}"
    python3 - "$@" <<'PY'
import os, plistlib, sys
e = os.environ
d = {
    "Label": e["ETICHETTA"],
    "ProgramArguments": sys.argv[1:],
    "EnvironmentVariables": {
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + os.path.expanduser("~/.local/bin"),
        "METIS_CONFIG": e["CFG"], "LANG": "it_IT.UTF-8", "LC_ALL": "it_IT.UTF-8",
    },
    "StandardOutPath": os.path.join(e["METIS_LOG_DIR"], e["NOME"] + ".log"),
    "StandardErrorPath": os.path.join(e["METIS_LOG_DIR"], e["NOME"] + ".log"),
    "WorkingDirectory": os.path.expanduser("~"),
}
if e["TIPO"] == "sempre":
    d["KeepAlive"] = True; d["RunAtLoad"] = True; d["ThrottleInterval"] = 30
else:
    d["StartCalendarInterval"] = [{"Hour": int(o.split(":")[0]), "Minute": int(o.split(":")[1])} for o in e["ORARI"].split()]
with open(e["PLIST"], "wb") as f:
    plistlib.dump(d, f)
print(f"launchd: {e['PLIST']}")
PY
    plutil -lint "$PLIST" >/dev/null || { echo "launchd: plist non valido" >&2; exit 1; } ;;
  carica)
    [ -f "$PLIST" ] || { echo "launchd: manca $PLIST (prima: genera)" >&2; exit 1; }
    launchctl bootout "gui/$(id -u)/$ETICHETTA" 2>/dev/null
    launchctl bootstrap "gui/$(id -u)" "$PLIST" && echo "launchd: $ETICHETTA caricato" ;;
  scarica)
    launchctl bootout "gui/$(id -u)/$ETICHETTA" 2>/dev/null && echo "launchd: $ETICHETTA fermato" || echo "launchd: $ETICHETTA non era caricato" ;;
  stato)
    if launchctl print "gui/$(id -u)/$ETICHETTA" >/dev/null 2>&1; then echo "caricato"; else echo "non caricato"; exit 1; fi ;;
  *) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
