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
#
# Strada «posta locale» (decisione del 23/10/2026): la posta delle sessioni passa dal server locale
# @dguido/google-workspace-mcp (versione fissata, solo Gmail), non dal connettore Gmail di claude.ai: il connettore non
# scarica né allega file, e nell'app i suoi nomi cambiano da un account all'altro, così che le regole per nome non lo
# prendono. Lettura, allegati e bozze senza conferma; invii, etichette e filtri con conferma; cancellazioni vietate
# (installa-permessi.sh con METIS_POSTA=locale); la guardia rifiuta il connettore Gmail. Calendar e Drive restano ai connettori.
# Il pacchetto ha il repository archiviato (marzo 2026): si fissa la versione, provata dal 3/2026 nel sistema di riferimento.
#   google.sh credenziali-posta <file>  copia le credenziali OAuth in ~/.config/google-workspace-mcp (600)
#   google.sh account-posta             consenso del cliente nel browser (una volta; di nuovo solo se revocato)
#   google.sh posta                     installa il server, lo dichiara nel vault, METIS_POSTA=locale, permessi
#   google.sh token                     controlla l'autorizzazione senza avviare il server (che altrimenti apre il browser)

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
PACCHETTO_POSTA="@dguido/google-workspace-mcp@3.4.4"
PDIR="${XDG_CONFIG_HOME:-$HOME/.config}/google-workspace-mcp"
NPM="${METIS_NPM:-$(command -v npm || ls /opt/homebrew/bin/npm /usr/local/bin/npm 2>/dev/null | head -1)}"
server_posta() { command -v google-workspace-mcp || ls /opt/homebrew/bin/google-workspace-mcp /usr/local/bin/google-workspace-mcp 2>/dev/null | head -1; }
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
    if [ "${METIS_POSTA:-connettori}" = locale ] && [ -n "$(server_posta)" ]; then
      # con la posta locale le routine usano lo stesso server e la stessa autorizzazione, in sola lettura: un solo consenso
      python3 "$IMP" mcp "$MCP_ROUTINE" google "{\"type\":\"stdio\",\"command\":\"$(server_posta)\",\"args\":[\"start\"],\"env\":{\"GOOGLE_WORKSPACE_READ_ONLY\":\"true\"}}"
    else
      python3 "$IMP" mcp "$MCP_ROUTINE" google "{\"type\":\"stdio\",\"command\":\"$NPX\",\"args\":[\"-y\",\"$PACCHETTO\",\"serve\",\"--read-only\"],\"env\":{}}"
    fi
    chmod 600 "$MCP_ROUTINE"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_ROUTINE_STRUMENTI "mcp__google"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI google
    echo "google: server locale in sola lettura dichiarato per le routine ($MCP_ROUTINE); da provare con l'account del cliente" ;;
  credenziali-posta)
    F="${2:?manca il file delle credenziali scaricato da Google Cloud}"
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if "installed" in d else 1)' "$F" 2>/dev/null \
      || { echo "google: il file non è una credenziale OAuth per app desktop (manca «installed»)" >&2; exit 1; }
    mkdir -p "$PDIR"; chmod 700 "$PDIR"
    ( umask 077; cp "$F" "$PDIR/credentials.json" ); chmod 600 "$PDIR/credentials.json"
    echo "google: credenziali copiate in $PDIR/credentials.json (600). Il file scaricato si può cancellare." ;;
  account-posta)
    [ -f "$PDIR/credentials.json" ] || { echo "google: prima le credenziali (google.sh credenziali-posta <file>)" >&2; exit 1; }
    S=$(server_posta); [ -n "$S" ] || { echo "google: prima il server (google.sh posta)" >&2; exit 1; }
    echo "google: si apre il browser; accedi con l'account Google del cliente e consenti l'accesso («app non verificata» → Avanzate)." >&2
    "$S" auth && python3 "$METIS_ROOT/scripts/google-token.py" --dir "$PDIR" ;;
  token)
    python3 "$METIS_ROOT/scripts/google-token.py" --dir "$PDIR" ;;
  posta)
    [ -n "$NPM" ] || { echo "google: manca node (brew install node)" >&2; exit 1; }
    S=$(server_posta)
    if [ -z "$S" ] || ! "$S" version 2>/dev/null | grep -q '3\.4\.4'; then
      "$NPM" install -g "$PACCHETTO_POSTA" >/dev/null || { echo "google: installazione di $PACCHETTO_POSTA non riuscita" >&2; exit 1; }
      S=$(server_posta)
    fi
    [ -n "$S" ] || { echo "google: server installato ma non trovato nel PATH" >&2; exit 1; }
    python3 "$IMP" mcp "$METIS_VAULT/.mcp.json" gmail-locale "{\"type\":\"stdio\",\"command\":\"$S\",\"args\":[\"start\"],\"env\":{\"GOOGLE_WORKSPACE_SERVICES\":\"gmail\"}}"
    python3 "$IMP" lista "$METIS_VAULT/.claude/settings.json" enabledMcpjsonServers gmail-locale >/dev/null
    bash "$METIS_ROOT/scripts/configura.sh" set METIS_POSTA locale
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI google
    bash "$METIS_ROOT/scripts/installa-permessi.sh"
    echo "google: posta dal server locale ($S, solo Gmail) dichiarata nel vault; il connettore Gmail resta attivo per Cowork e le chat, ma nel vault la guardia lo rifiuta"
    echo "google: poi google.sh credenziali-posta <file>, google.sh account-posta, google.sh controlla; sessione nuova del cliente" ;;
  controlla)
    ERR=0
    bash "$0" connettori || ERR=1
    if grep -q '"google"' "$MCP_ROUTINE" 2>/dev/null && ! grep -q 'GOOGLE_WORKSPACE_READ_ONLY' "$MCP_ROUTINE"; then   # server locale facoltativo (pacchetto delle routine): si controlla solo se dichiarato
      [ "$(stat -f %Lp "$GDIR/credentials.json" 2>/dev/null)" = 600 ] && echo "✅ server locale: credenziali OAuth presenti e protette" || { echo "❌ server locale: credenziali OAuth assenti o leggibili da altri ($GDIR/credentials.json)"; ERR=1; }
      S=$("$NPX" -y "$PACCHETTO" status 2>&1)   # «status» esce con 0 anche quando trova problemi: si legge il testo
      if printf '%s' "$S" | grep -qE 'issue\(s\) found|NOT found|No accounts'; then echo "❌ server locale non pronto: $(printf '%s' "$S" | grep -E '❌|⚠️' | tr '\n' ' ')"; ERR=1
      else echo "✅ server locale pronto"; fi
    fi
    if [ "${METIS_POSTA:-connettori}" = locale ]; then   # posta locale: server, credenziali, autorizzazione (senza avviarlo)
      S=$(server_posta)
      if [ -n "$S" ] && "$S" version 2>/dev/null | grep -q '3\.4\.4'; then echo "✅ posta locale: server $S (3.4.4)"; else echo "❌ posta locale: server assente o di un'altra versione (google.sh posta)"; ERR=1; fi
      [ "$(stat -f %Lp "$PDIR/credentials.json" 2>/dev/null)" = 600 ] && echo "✅ posta locale: credenziali OAuth presenti e protette" || { echo "❌ posta locale: credenziali assenti o leggibili da altri ($PDIR/credentials.json)"; ERR=1; }
      python3 "$METIS_ROOT/scripts/google-token.py" --dir "$PDIR"; RT=$?
      [ "$RT" = 0 ] || ERR=1
      grep -q '"gmail-locale"' "$METIS_VAULT/.mcp.json" 2>/dev/null && echo "✅ posta locale: server dichiarato nel vault" || { echo "❌ posta locale: server non dichiarato in $METIS_VAULT/.mcp.json (google.sh posta)"; ERR=1; }
    fi
    exit "$ERR" ;;
  *) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
