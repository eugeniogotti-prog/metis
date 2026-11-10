#!/bin/bash
# connettori.sh — quali connettori di claude.ai restano accesi nel vault del cliente, su un server.
# Con il login completo di Claude arrivano sul server TUTTI i connettori dell'account (posta, calendario, ma anche un broker,
# la musica, …) e i plugin sincronizzati. La sessione principale lavora senza richieste di permesso e ascolta Telegram:
# si tengono accesi solo i connettori che il lavoro prevede, decisi con il cliente.
# Si lancia come utente del cliente.
#
# Uso:
#   connettori.sh elenca                 i connettori dell'account, con lo stato nel vault (acceso / spento)
#   connettori.sh tieni "<n1>,<n2>,…"     tiene accesi solo questi (nome come in «elenca», senza «claude.ai »); spegne gli altri.
#                                        «tieni ""» li spegne tutti.
#   connettori.sh plugin                 disattiva i plugin sincronizzati dall'account (productivity, …), tranne Metis
# Effetto: «disabledMcpServers» del progetto del vault in ~/.claude.json (copia prima: ~/.claude.json.prima-dei-connettori).
# Vale dalla sessione successiva: dopo, si riavvia la sessione principale (tmux kill-session -t metis-principale).

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "connettori: ${METIS_ERRORE}" >&2; exit 2; }
V="$(cd "$METIS_VAULT" && pwd -P)"
elenco() { (cd "$V" && env -u CLAUDE_CODE_OAUTH_TOKEN bash "$METIS_ROOT/scripts/con-timeout.sh" 180 claude mcp list 2>/dev/null) | grep -oE '^claude\.ai [^:]+' | sed 's/^claude\.ai //' | sort -u; }

case "${1:-}" in
  elenca)
    L=$(elenco); [ -n "$L" ] || { echo "nessun connettore di claude.ai (login con il solo token? serve il login completo)"; exit 0; }
    python3 - "$V" <<PY
import json, os, sys
d = json.load(open(os.path.expanduser("~/.claude.json")))
spenti = set(d.get("projects", {}).get(sys.argv[1], {}).get("disabledMcpServers", []))
for n in """$L""".splitlines():
    print(("spento " if "claude.ai " + n in spenti else "acceso ") + n)
PY
    ;;
  tieni)
    TIENI="${2-}"; L=$(elenco); [ -n "$L" ] || { echo "connettori: nessun connettore trovato" >&2; exit 1; }
    cp ~/.claude.json ~/.claude.json.prima-dei-connettori 2>/dev/null; chmod 600 ~/.claude.json.prima-dei-connettori 2>/dev/null
    TIENI="$TIENI" ELENCO="$L" python3 - "$V" <<'PY'
import json, os, sys
p = os.path.expanduser("~/.claude.json"); d = json.load(open(p))
tutti = [n for n in os.environ["ELENCO"].splitlines() if n]
tieni = {x.strip().lower() for x in os.environ["TIENI"].split(",") if x.strip()}
ignoti = tieni - {n.lower() for n in tutti}
if ignoti: sys.exit("connettori: non esistono: " + ", ".join(sorted(ignoti)) + " (vedi: connettori.sh elenca)")
pr = d.setdefault("projects", {}).setdefault(sys.argv[1], {})
altri = [x for x in pr.get("disabledMcpServers", []) if not x.startswith("claude.ai ")]
pr["disabledMcpServers"] = sorted(set(altri) | {"claude.ai " + n for n in tutti if n.lower() not in tieni})
t = p + ".tmp"; json.dump(d, open(t, "w"), indent=2); os.chmod(t, 0o600); os.replace(t, p)
for n in tutti: print(("✅ acceso " if n.lower() in tieni else "⊘ spento ") + n)
PY
    [ $? = 0 ] || exit 1
    echo "connettori: vale dalla prossima sessione (tmux kill-session -t ${METIS_SESSIONE_TMUX:-metis-principale}: il guardiano la rilancia)" ;;
  plugin)
    claude plugin list 2>/dev/null | grep -oE '❯ [^ ]+' | sed 's/❯ //' | grep -v '^metis@' | while read -r p; do
      claude plugin disable "$p" >/dev/null 2>&1 && echo "⊘ plugin disattivato: $p"
    done; true ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
