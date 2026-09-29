#!/bin/bash
# routine.sh — modulo routine: i giri automatici ad orari fissi, a Mac acceso.
# Uso:
#   routine.sh installa [--senza-caricare]   genera e carica i LaunchAgent dei lavori scelti (METIS_JOBS)
#   routine.sh prova <lavoro>                esegue subito un giro (controllo di riuscita)
#   routine.sh controlla                     LaunchAgent generati e caricati; ultimo giro riuscito
#   routine.sh togli <lavoro>                ferma un lavoro (il file resta, si ricarica con installa)
# Lavori e orari di default (si cambiano con METIS_ORARI_<LAVORO> nella configurazione, orari HH:MM separati da spazi):
#   doctor 06:45 · daily-digest 07:00 · inbox-processor 09:00 13:00 17:00 · daily-sera 21:00 · weekly-digest (lunedì) 07:30
# Il doctor è uno script; gli altri sono giri di Claude (metis-agent.sh).

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "routine: ${METIS_ERRORE}" >&2; exit 2; }
L="$METIS_ROOT/scripts/lib/launchd.sh"

orari() {  # orari <lavoro>: dalla configurazione o i default
  local v="METIS_ORARI_$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"
  if [ -n "${!v:-}" ]; then echo "${!v}"; return; fi
  case "$1" in
    doctor) echo "06:45" ;; daily-digest) echo "07:00" ;; inbox-processor) echo "09:00 13:00 17:00" ;;
    daily-sera) echo "21:00" ;; weekly-digest) echo "07:30" ;;
  esac
}

case "${1:-}" in
  installa)
    for j in doctor $METIS_JOBS; do
      if [ "$j" = doctor ]; then
        bash "$L" genera doctor orari "$(orari doctor)" /bin/bash "$METIS_ROOT/scripts/doctor.sh" || exit 1
      else
        bash "$L" genera "$j" orari "$(orari "$j")" /bin/bash "$METIS_ROOT/scripts/metis-agent.sh" "$j" || exit 1
      fi
      # Il weekly gira solo il lunedì: si aggiunge Weekday agli orari generati.
      [ "$j" = weekly-digest ] && /usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:0:Weekday integer 1" \
        "${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}/$METIS_LABEL.weekly-digest.plist" >/dev/null
      [ "${2:-}" = --senza-caricare ] || bash "$L" carica "$j"
    done
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI routine ;;
  prova)
    J="${2:?manca il lavoro}"
    if [ "$J" = doctor ]; then bash "$METIS_ROOT/scripts/doctor.sh"; else bash "$METIS_ROOT/scripts/metis-agent.sh" "$J"; fi ;;
  controlla)
    ERR=0
    for j in doctor $METIS_JOBS; do
      P="${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}/$METIS_LABEL.$j.plist"
      if [ ! -f "$P" ]; then echo "❌ $j: LaunchAgent non generato"; ERR=1; continue; fi
      if bash "$L" stato "$j" >/dev/null; then echo "✅ $j: caricato ($(orari "$j"))"; else echo "❌ $j: generato ma non caricato"; ERR=1; fi
    done
    exit "$ERR" ;;
  togli)
    bash "$L" scarica "${2:?manca il lavoro}" ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
