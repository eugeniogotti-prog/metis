#!/bin/bash
# systemd.sh — gli automatismi di Metis su Linux: servizi e timer di systemd per l'utente (stessa interfaccia di launchd.sh).
# Uso:
#   systemd.sh genera <nome> sempre <comando> [argomenti...]        processo sempre acceso (riavviato se si ferma)
#   systemd.sh genera <nome> orari "<HH:MM HH:MM ...>" <comando> [argomenti...]   giri ad orari fissi, ogni giorno
#              (con un giorno davanti agli orari, «lun 07:30», solo quel giorno della settimana: lun mar mer gio ven sab dom)
#   systemd.sh carica <nome>        attiva (o riattiva) il servizio o il timer
#   systemd.sh scarica <nome>       lo ferma e lo disattiva (i file restano)
#   systemd.sh stato <nome>         dice se è attivo
#   systemd.sh esiste <nome>        esce con 0 se il servizio è stato generato
#   systemd.sh permanenza           esce con 0 se gli automatismi girano anche senza nessuno collegato (linger)
# File: <etichetta>.<nome>.service (e .timer per i giri a orario) in ~/.config/systemd/user (o in $METIS_SYSTEMD_DIR, per le prove).
# Di solito non si chiama direttamente: scripts/lib/servizi.sh sceglie fra launchd.sh (Mac) e questo (Linux).
# Requisito, una volta sola all'allestimento del server: sudo loginctl enable-linger <utente>. Senza, systemd ferma gli
# automatismi dell'utente quando l'ultima sessione SSH si chiude.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
AZ="${1:-}"; NOME="${2:-}"
SYSTEMCTL="${METIS_SYSTEMCTL:-systemctl}"
uso() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

if [ "$AZ" = permanenza ]; then
  [ -n "${METIS_LINGER:-}" ] && { [ "$METIS_LINGER" = yes ]; exit; }   # prove
  [ "$(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null)" = yes ]; exit
fi

metis_carica_config || { echo "systemd: ${METIS_ERRORE}" >&2; exit 2; }
DIR="${METIS_SYSTEMD_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}"
[ -n "$NOME" ] && [[ "$NOME" =~ ^[a-z0-9-]+$ ]] || uso
ETICHETTA="$METIS_LABEL.$NOME"; SERVIZIO="$DIR/$ETICHETTA.service"; TIMER="$DIR/$ETICHETTA.timer"
# Senza una sessione di login (giro lanciato da cron, sudo -u) systemctl --user non trova il gestore: gli si indica.
[ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$(id -u)" ] && export XDG_RUNTIME_DIR="/run/user/$(id -u)"
sc() { "$SYSTEMCTL" --user "$@"; }

case "$AZ" in
  genera)
    TIPO="${3:-}"; shift 3
    ORARI=""; [ "$TIPO" = orari ] && { ORARI="$1"; shift; }
    [ "$TIPO" = sempre ] || [ "$TIPO" = orari ] || { echo "systemd: tipo «$TIPO» sconosciuto (sempre|orari)" >&2; exit 2; }
    [ $# -ge 1 ] || { echo "systemd: manca il comando" >&2; exit 2; }
    mkdir -p "$DIR" "$METIS_LOG_DIR"
    export ETICHETTA SERVIZIO TIMER TIPO ORARI METIS_LOG_DIR NOME METIS_PRODOTTO CFG="${METIS_CONFIG:-$HOME/.config/metis/config}"
    python3 - "$@" <<'PY' || exit 1
import os, sys
e = os.environ
def q(s):  # un argomento di ExecStart: tra virgolette; «%» e «$» sono speciali per systemd
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%").replace("$", "$$") + '"'
def v(s):  # un valore di Environment= o di un percorso: «%» raddoppiato
    return s.replace("%", "%%")
log = v(os.path.join(e["METIS_LOG_DIR"], e["NOME"] + ".log"))
path = "/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:" + os.path.expanduser("~/.local/bin")
prod = e.get("METIS_PRODOTTO") or "Metis"
righe = [
    "[Unit]", f"Description={prod}: {e['NOME']}", "",
    "[Service]",
    "Type=" + ("simple" if e["TIPO"] == "sempre" else "oneshot"),
    "ExecStart=" + " ".join(q(a) for a in sys.argv[1:]),
    "WorkingDirectory=%h",
    f'Environment="PATH={v(path)}" "METIS_CONFIG={v(e["CFG"])}" "LANG=C.UTF-8" "LC_ALL=C.UTF-8"',
    f"StandardOutput=append:{log}", f"StandardError=append:{log}",
]
if e["TIPO"] == "sempre":
    righe += ["Restart=always", "RestartSec=30", "", "[Install]", "WantedBy=default.target"]
with open(e["SERVIZIO"], "w") as f: f.write("\n".join(righe) + "\n")
print(f"systemd: {e['SERVIZIO']}")
if e["TIPO"] == "orari":
    giorni = {"lun": "Mon", "mar": "Tue", "mer": "Wed", "gio": "Thu", "ven": "Fri", "sab": "Sat", "dom": "Sun"}
    parti = e["ORARI"].split()
    gs = [giorni[x] for x in parti if x in giorni]
    ore = [x for x in parti if x not in giorni]
    for o in ore:
        h, m = o.split(":")
        if not (h.isdigit() and m.isdigit() and int(h) < 24 and int(m) < 60): sys.exit(f"systemd: orario non valido «{o}»")
    if not ore: sys.exit("systemd: mancano gli orari")
    pre = ",".join(gs) + " " if gs else ""
    t = ["[Unit]", f"Description={prod}: {e['NOME']} (orari)", "", "[Timer]"]
    t += [f"OnCalendar={pre}*-*-* {int(o.split(':')[0]):02d}:{int(o.split(':')[1]):02d}:00" for o in ore]
    t += ["Persistent=true", f"Unit={os.path.basename(e['SERVIZIO'])}", "", "[Install]", "WantedBy=timers.target"]
    with open(e["TIMER"], "w") as f: f.write("\n".join(t) + "\n")
    print(f"systemd: {e['TIMER']}")
else:
    try: os.remove(e["TIMER"])   # da orari a sempre: il timer vecchio non serve più
    except FileNotFoundError: pass
PY
    if command -v systemd-analyze >/dev/null 2>&1 && [ -z "${METIS_SYSTEMCTL:-}" ]; then
      F=("$SERVIZIO"); [ -f "$TIMER" ] && F+=("$TIMER")
      # Si controlla la sintassi; i messaggi sul gestore di sistema non riguardano i file di Metis.
      ERRV=$(SYSTEMD_LOG_LEVEL=err systemd-analyze --user verify "${F[@]}" 2>&1 | grep -F "$ETICHETTA" || true)
      [ -z "$ERRV" ] || { echo "systemd: file non validi: $ERRV" >&2; exit 1; }
    fi ;;
  carica)
    [ -f "$SERVIZIO" ] || { echo "systemd: manca $SERVIZIO (prima: genera)" >&2; exit 1; }
    [ "${METIS_SENZA_CARICARE:-}" = 1 ] && { echo "systemd: $ETICHETTA non caricato (prova: METIS_SENZA_CARICARE=1)"; exit 0; }
    sc daemon-reload || { echo "systemd: gestore dell'utente non raggiungibile (manca il linger? sudo loginctl enable-linger $(id -un))" >&2; exit 1; }
    if [ -f "$TIMER" ]; then
      sc enable --now "$ETICHETTA.timer" >/dev/null 2>&1 && sc restart "$ETICHETTA.timer" && echo "systemd: $ETICHETTA caricato (timer)"
    else
      sc enable "$ETICHETTA.service" >/dev/null 2>&1 && sc restart "$ETICHETTA.service" && echo "systemd: $ETICHETTA caricato"
    fi ;;
  scarica)
    U="$ETICHETTA.service"; [ -f "$TIMER" ] && U="$ETICHETTA.timer"
    if sc is-enabled "$U" >/dev/null 2>&1 || sc is-active "$U" >/dev/null 2>&1; then
      sc disable --now "$U" >/dev/null 2>&1; echo "systemd: $ETICHETTA fermato"
    else echo "systemd: $ETICHETTA non era caricato"; fi ;;
  stato)
    [ "${METIS_SENZA_CARICARE:-}" = 1 ] && { echo "non caricato (prova)"; exit 1; }
    U="$ETICHETTA.service"; [ -f "$TIMER" ] && U="$ETICHETTA.timer"
    if sc is-enabled "$U" >/dev/null 2>&1 && sc is-active "$U" >/dev/null 2>&1; then echo "caricato"; else echo "non caricato"; exit 1; fi ;;
  esiste)
    [ -f "$SERVIZIO" ] ;;
  *) uso ;;
esac
