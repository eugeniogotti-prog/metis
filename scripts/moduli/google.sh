#!/bin/bash
# google.sh — modulo Google: posta, calendario e Drive.
# Strada principale (decisione del 30/9/2026): i connettori di claude.ai (Gmail, Google Calendar, Google Drive), per
# le sessioni con il cliente e per le routine. Nessuna installazione sul Mac: il cliente li attiva su claude.ai →
# Impostazioni → Connettori. Nelle routine si ammettono per nome solo gli strumenti di lettura e si negano quelli che
# scrivono (invii, risposte, cestino, eventi, condivisioni, bozze): un giro automatico legge e basta.
# Rischio noto: i connettori nelle routine funzionano finché il login di Claude Code con l'abbonamento resta valido;
# il controllo, eseguito ogni mattina dal doctor, se ne accorge.
# Strada facoltativa, da provare con l'account vero del cliente prima di usarla: il server locale google-workspace-mcp,
# in sola lettura, con un progetto Google Cloud del cliente (sottocomandi credenziali, account, server).
# Uso:
#   google.sh installa            regole delle routine per i connettori; modulo registrato
#   google.sh connettori          quali connettori vede una sessione di Claude Code nel vault
#   google.sh controlla           connettori collegati (e server locale, se dichiarato)
#   google.sh credenziali <file>  [server locale] copia le credenziali OAuth scaricate da Google Cloud (600)
#   google.sh account             [server locale] autorizzazione dell'account nel browser (la fa il cliente)
#   google.sh server              [server locale] dichiara il server, in sola lettura, per le routine

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

# Strumenti dei connettori di claude.ai (nomi letti il 30/9/2026 dall'elenco degli strumenti di Claude Code).
# Valgono per Claude Code, dove girano le routine; nell'app di Claude gli stessi strumenti hanno un altro nome
# (docs/procedura-installazione.md, «Connettori e protezioni nell'app di Claude»).
LEGGE="mcp__claude_ai_Gmail__search_threads mcp__claude_ai_Gmail__get_thread mcp__claude_ai_Gmail__get_message mcp__claude_ai_Gmail__list_labels mcp__claude_ai_Google_Calendar__list_calendars mcp__claude_ai_Google_Calendar__list_events mcp__claude_ai_Google_Calendar__get_event mcp__claude_ai_Google_Calendar__search_events mcp__claude_ai_Google_Drive__search_files mcp__claude_ai_Google_Drive__read_file_content mcp__claude_ai_Google_Drive__get_file_metadata mcp__claude_ai_Google_Drive__list_recent_files mcp__claude_ai_Google_Drive__download_file_content"
SCRIVE="mcp__claude_ai_Gmail__send_message mcp__claude_ai_Gmail__reply mcp__claude_ai_Gmail__forward mcp__claude_ai_Gmail__create_draft mcp__claude_ai_Gmail__update_draft mcp__claude_ai_Gmail__delete_draft mcp__claude_ai_Gmail__trash_message mcp__claude_ai_Gmail__trash_thread mcp__claude_ai_Gmail__mark_message_spam mcp__claude_ai_Gmail__mark_thread_spam mcp__claude_ai_Google_Calendar__create_event mcp__claude_ai_Google_Calendar__update_event mcp__claude_ai_Google_Calendar__delete_event mcp__claude_ai_Google_Calendar__respond_to_event mcp__claude_ai_Google_Drive__create_file mcp__claude_ai_Google_Drive__update_file mcp__claude_ai_Google_Drive__copy_file mcp__claude_ai_Google_Drive__trash_file mcp__claude_ai_Google_Drive__share_file"
R="$CFG_DIR/permessi-routine.json"

case "${1:-}" in
  installa)
    for t in $SCRIVE; do python3 "$IMP" lista "$R" permissions.deny "$t" >/dev/null; done
    for t in $LEGGE; do bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_ROUTINE_STRUMENTI "$t" >/dev/null; done
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI google
    echo "google: routine con i connettori di claude.ai in sola lettura ($(echo $LEGGE | wc -w | tr -d ' ') strumenti ammessi, $(echo $SCRIVE | wc -w | tr -d ' ') negati)"
    echo "google: controllo → google.sh connettori (i connettori si attivano su claude.ai → Impostazioni → Connettori)" ;;
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
  server)
    [ -n "$NPX" ] || { echo "google: manca node (brew install node)" >&2; exit 1; }
    python3 "$IMP" mcp "$MCP_ROUTINE" google "{\"type\":\"stdio\",\"command\":\"$NPX\",\"args\":[\"-y\",\"$PACCHETTO\",\"serve\",\"--read-only\"],\"env\":{}}"
    chmod 600 "$MCP_ROUTINE"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_ROUTINE_STRUMENTI "mcp__google"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI google
    echo "google: server locale in sola lettura dichiarato per le routine ($MCP_ROUTINE); da provare con l'account del cliente" ;;
  controlla)
    ERR=0
    bash "$0" connettori || ERR=1
    if grep -q '"google"' "$MCP_ROUTINE" 2>/dev/null; then   # server locale facoltativo: si controlla solo se dichiarato
      [ "$(stat -f %Lp "$GDIR/credentials.json" 2>/dev/null)" = 600 ] && echo "✅ server locale: credenziali OAuth presenti e protette" || { echo "❌ server locale: credenziali OAuth assenti o leggibili da altri ($GDIR/credentials.json)"; ERR=1; }
      S=$("$NPX" -y "$PACCHETTO" status 2>&1)   # «status» esce con 0 anche quando trova problemi: si legge il testo
      if printf '%s' "$S" | grep -qE 'issue\(s\) found|NOT found|No accounts'; then echo "❌ server locale non pronto: $(printf '%s' "$S" | grep -E '❌|⚠️' | tr '\n' ' ')"; ERR=1
      else echo "✅ server locale pronto"; fi
    fi
    exit "$ERR" ;;
  *) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
