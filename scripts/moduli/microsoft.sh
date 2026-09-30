#!/bin/bash
# microsoft.sh — modulo Microsoft 365: posta e calendario Outlook, OneDrive, SharePoint, Teams, con il connettore
# Microsoft 365 di claude.ai (disponibile su tutti i piani Claude; serve un account Microsoft 365 aziendale).
# Serve l'IT una volta: un amministratore «Global» di Microsoft Entra concede il consenso per l'organizzazione; sui
# piani Team ed Enterprise l'amministratore Claude abilita anche il connettore. Di default il connettore legge soltanto.
# Uso:
#   microsoft.sh connettore   il connettore risulta collegato in una sessione di Claude Code nel vault?
#   microsoft.sh installa     legge dalla sessione i nomi degli strumenti del connettore; nelle regole delle routine
#                             ammette per nome quelli di lettura e nega quelli che scrivono (invio, risposta, creazione,
#                             modifica, cancellazione, spostamento, condivisione); modulo registrato
#   microsoft.sh controlla    come «connettore»; lo esegue ogni mattina il doctor
# I nomi degli strumenti non sono scritti qui: si leggono sul Mac del cliente, perché non è stato possibile vederli
# senza un account Microsoft 365 (29-30/9/2026). La classificazione lettura/scrittura è per nome: va riletta con il cliente.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "microsoft: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
CLAUDE="${METIS_CLAUDE:-claude}"
IMP="$METIS_ROOT/scripts/lib/impostazioni.py"
R="$CFG_DIR/permessi-routine.json"

avvio() {  # evento di avvio di una sessione minima nel vault (stream-json)
  (cd "$METIS_VAULT" && printf 'Rispondi solo: ok' | "$CLAUDE" -p --output-format stream-json --verbose 2>/dev/null | head -5)
}

case "${1:-}" in
  connettore|controlla)
    python3 - "$(avvio)" <<'PY2'
import json, sys
for riga in sys.argv[1].splitlines():
    try:
        d = json.loads(riga)
    except ValueError:
        continue
    if d.get("type") == "system" and d.get("subtype") == "init":
        s = [x for x in d.get("mcp_servers", []) if x.get("name", "").startswith("claude.ai") and "microsoft" in x.get("name", "").lower()]
        if s and s[0].get("status") == "connected":
            print("✅ connettore Microsoft 365: collegato (" + s[0]["name"] + ")"); sys.exit(0)
        if s:
            print("❌ connettore Microsoft 365: " + str(s[0].get("status")) + " — va autorizzato su claude.ai → Impostazioni → Connettori (e serve il consenso dell'IT)"); sys.exit(1)
        print("❌ connettore Microsoft 365: non attivo — claude.ai → Impostazioni → Connettori"); sys.exit(1)
print("❌ connettore Microsoft 365: sessione di controllo non riuscita"); sys.exit(1)
PY2
    ;;
  installa)
    STRUMENTI=$(avvio | python3 -c '
import json, re, sys
for riga in sys.stdin:
    try: d = json.loads(riga)
    except ValueError: continue
    if d.get("subtype") == "init":
        for t in d.get("tools", []):
            if t.startswith("mcp__claude_ai_") and "microsoft" in t.lower():
                az = t.rsplit("__", 1)[-1].lower()
                scrive = re.search(r"send|reply|forward|create|update|delete|remove|move|copy|share|post|upload|write|draft|respond|accept|decline|cancel|schedule", az)
                print(("S " if scrive else "L ") + t)
')
    [ -n "$STRUMENTI" ] || { echo "microsoft: nessuno strumento del connettore nella sessione (connettore non collegato?)" >&2; exit 1; }
    printf '%s\n' "$STRUMENTI" | while read -r tipo t; do
      if [ "$tipo" = S ]; then python3 "$IMP" lista "$R" permissions.deny "$t" >/dev/null
      else bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_ROUTINE_STRUMENTI "$t" >/dev/null; fi
    done
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI microsoft
    echo "microsoft: routine con il connettore in sola lettura ($(printf '%s\n' "$STRUMENTI" | grep -c '^L') strumenti ammessi, $(printf '%s\n' "$STRUMENTI" | grep -c '^S') negati)"
    echo "microsoft: rileggere con il cliente la classificazione:"; printf '%s\n' "$STRUMENTI" | sed 's/^L /  lettura:   /; s/^S /  scrittura: /' ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
