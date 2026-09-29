#!/bin/bash
# google.sh — modulo Google: posta, calendario e Drive.
# Due strade, che si completano:
#   - connettori di claude.ai (Gmail, Google Calendar, Google Drive) per le sessioni con il cliente: nessuna
#     installazione sul Mac, il cliente li attiva su claude.ai → Impostazioni → Connettori;
#   - server locale google-workspace-mcp per le routine automatiche, in sola lettura: non dipende dal login di
#     claude.ai e non può mandare niente. Richiede un progetto Google Cloud del cliente (credenziali OAuth).
# Uso:
#   google.sh connettori          controlla quali connettori claude.ai vede una sessione di Claude Code nel vault
#   google.sh credenziali <file>  copia il file delle credenziali OAuth scaricato da Google Cloud (600)
#   google.sh account             avvia l'autorizzazione dell'account nel browser (la fa il cliente)
#   google.sh routine             dichiara il server locale, in sola lettura, nella configurazione MCP delle routine
#   google.sh controlla           credenziali, account autorizzato, server pronto, configurazione delle routine
# Versione del server fissata: gli aggiornamenti del pacchetto si provano prima di cambiarla.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "google: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
PACCHETTO="google-workspace-mcp@2.3.6"
GDIR="${METIS_GOOGLE_DIR:-$HOME/.google-mcp}"
NPX="${METIS_NPX:-$(command -v npx || ls /opt/homebrew/bin/npx /usr/local/bin/npx 2>/dev/null | head -1)}"
CLAUDE="${METIS_CLAUDE:-claude}"
MCP_ROUTINE="$CFG_DIR/mcp-routine.json"
IMP="$METIS_ROOT/scripts/lib/impostazioni.py"

case "${1:-}" in
  connettori)
    # Una sessione minima nel vault; l'evento di avvio (stream-json) elenca i server MCP e il loro stato.
    OUT=$(cd "$METIS_VAULT" && printf 'Rispondi solo: ok' | "$CLAUDE" -p --output-format stream-json --verbose 2>/dev/null | head -5)
    python3 - "$OUT" <<'PY'
import json, sys
servers = []
for riga in sys.argv[1].splitlines():
    try: d = json.loads(riga)
    except ValueError: continue
    if d.get("type") == "system" and d.get("subtype") == "init":
        servers = d.get("mcp_servers", [])
        break
cerca = {"Gmail": "posta", "Calendar": "calendario", "Drive": "Drive"}
err = 0
for chiave, nome in cerca.items():
    # nell'evento di avvio i connettori si chiamano «claude.ai Gmail», «claude.ai Google Calendar», … (Claude Code 2.1.284)
    s = [x for x in servers if x.get("name", "").startswith("claude.ai") and chiave.lower() in x.get("name", "").lower()]
    if s and s[0].get("status") == "connected":
        print(f"✅ connettore {nome}: collegato ({s[0]['name']})")
    elif s:
        print(f"❌ connettore {nome}: {s[0].get('status')} — va autorizzato su claude.ai → Impostazioni → Connettori"); err = 1
    else:
        print(f"❌ connettore {nome}: non attivo — claude.ai → Impostazioni → Connettori"); err = 1
sys.exit(err)
PY
    ;;
  credenziali)
    F="${2:?manca il file delle credenziali scaricato da Google Cloud}"
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if "installed" in d else 1)' "$F" 2>/dev/null \
      || { echo "google: il file non è una credenziale OAuth per app desktop (manca «installed»)" >&2; exit 1; }
    mkdir -p "$GDIR"; chmod 700 "$GDIR"
    ( umask 077; cp "$F" "$GDIR/credentials.json" ); chmod 600 "$GDIR/credentials.json"
    echo "google: credenziali copiate in $GDIR/credentials.json (600). Il file scaricato si può cancellare." ;;
  account)
    [ -f "$GDIR/credentials.json" ] || { echo "google: prima le credenziali (google.sh credenziali <file>)" >&2; exit 1; }
    echo "google: si apre il browser; accedi con il tuo account Google e consenti l'accesso." >&2
    "$NPX" -y "$PACCHETTO" accounts add principale ;;
  routine)
    [ -n "$NPX" ] || { echo "google: manca node (brew install node)" >&2; exit 1; }
    python3 "$IMP" mcp "$MCP_ROUTINE" google "{\"type\":\"stdio\",\"command\":\"$NPX\",\"args\":[\"-y\",\"$PACCHETTO\",\"serve\",\"--read-only\"],\"env\":{}}"
    chmod 600 "$MCP_ROUTINE"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_ROUTINE_STRUMENTI "mcp__google"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI google
    echo "google: server locale in sola lettura dichiarato per le routine ($MCP_ROUTINE)" ;;
  controlla)
    ERR=0
    [ "$(stat -f %Lp "$GDIR/credentials.json" 2>/dev/null)" = 600 ] && echo "✅ credenziali OAuth presenti e protette" || { echo "❌ credenziali OAuth assenti o leggibili da altri ($GDIR/credentials.json)"; ERR=1; }
    if [ "$ERR" = 0 ]; then
      # «status» esce con 0 anche quando trova problemi (versione 2.3.6): si legge il testo.
      S=$("$NPX" -y "$PACCHETTO" status 2>&1)
      if printf '%s' "$S" | grep -qE 'issue\(s\) found|NOT found|No accounts'; then
        echo "❌ server locale non pronto: $(printf '%s' "$S" | grep -E '❌|⚠️' | tr '\n' ' ')"; ERR=1
      else echo "✅ server locale pronto"; fi
      "$NPX" -y "$PACCHETTO" accounts test-permissions >/dev/null 2>&1 && echo "✅ account autorizzato: permessi verificati" || { echo "❌ account non autorizzato o permessi mancanti (google.sh account)"; ERR=1; }
    fi
    grep -q '"google"' "$MCP_ROUTINE" 2>/dev/null && grep -q -- '--read-only' "$MCP_ROUTINE" && echo "✅ routine: server in sola lettura dichiarato" || { echo "❌ routine: server non dichiarato (google.sh routine)"; ERR=1; }
    exit "$ERR" ;;
  *) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
