#!/usr/bin/env python3
"""google-token.py — controlla l'autorizzazione Google del server locale SENZA avviarlo.

Perché: il server @dguido/google-workspace-mcp, se il token manca o è revocato, apre da solo la pagina di consenso nel
browser e aspetta; se il rinnovo fallisce con invalid_grant cancella anche il file dei token. Non ha un'opzione per
evitarlo (verificato sul codice della 3.4.4). Qui si rifà a mano il rinnovo che farebbe il server: se Google risponde con
un token d'accesso, l'autorizzazione è valida; altrimenti si dice perché e che cosa fare. Non scrive niente e non stampa
segreti.

Uso: google-token.py [--dir <cartella con credentials.json e tokens.json>]
     default: $XDG_CONFIG_HOME/google-workspace-mcp, altrimenti ~/.config/google-workspace-mcp
     (con un profilo: <cartella>/profiles/<nome>, che si passa con --dir).
Uscita: 0 valida · 1 da rifare (manca, scaduta, revocata) · 2 errore di rete o di Google (si riprova più tardi).
"""
import json, os, sys, urllib.error, urllib.parse, urllib.request

def esci(codice, msg):
    print(msg)
    sys.exit(codice)

d = None
if "--dir" in sys.argv:
    i = sys.argv.index("--dir")
    if i + 1 >= len(sys.argv): esci(2, "google-token: manca il valore di --dir")
    d = sys.argv[i + 1]
if not d:
    d = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "google-workspace-mcp")

try:
    cred = json.load(open(os.path.join(d, "credentials.json")))
except FileNotFoundError:
    esci(1, f"❌ credenziali OAuth assenti: {d}/credentials.json (google.sh credenziali-posta <file>)")
except ValueError:
    esci(1, f"❌ credenziali OAuth illeggibili: {d}/credentials.json")
c = cred.get("installed") or cred.get("web") or cred
cid, csec = c.get("client_id"), c.get("client_secret")
if not cid: esci(1, "❌ credenziali OAuth senza client_id: riscaricarle da Google Cloud (tipo «App desktop»)")

try:
    tok = json.load(open(os.path.join(d, "tokens.json")))
except FileNotFoundError:
    esci(1, f"❌ nessuna autorizzazione: manca {d}/tokens.json. Il cliente deve dare il consenso (google.sh account-posta)")
except ValueError:
    esci(1, f"❌ file dei token illeggibile: {d}/tokens.json")
rt = tok.get("refresh_token")
if not rt: esci(1, "❌ autorizzazione senza refresh_token: va rifatta (google.sh account-posta)")

dati = {"client_id": cid, "refresh_token": rt, "grant_type": "refresh_token"}
if csec: dati["client_secret"] = csec
req = urllib.request.Request("https://oauth2.googleapis.com/token", data=urllib.parse.urlencode(dati).encode(), method="POST")
try:
    with urllib.request.urlopen(req, timeout=20) as r:
        risp = json.load(r)
    if risp.get("access_token"):
        esci(0, "✅ autorizzazione Google valida (il rinnovo riesce)")
    esci(2, "⚠️ risposta di Google senza token d'accesso: riprovare più tardi")
except urllib.error.HTTPError as e:
    try: err = json.load(e).get("error", "")
    except Exception: err = ""
    if err == "invalid_grant":
        esci(1, "❌ autorizzazione revocata o scaduta (invalid_grant): va rifatta (google.sh account-posta). Se succede ogni 7 giorni, l'app su Google Cloud è ancora «in test»: va pubblicata")
    if err in ("invalid_client", "unauthorized_client"):
        esci(1, f"❌ credenziali OAuth non valide ({err}): il client è stato eliminato o cambiato su Google Cloud")
    esci(2, f"⚠️ Google ha risposto {e.code} {err}: riprovare più tardi")
except Exception as e:
    esci(2, f"⚠️ rete non raggiungibile ({type(e).__name__}): riprovare più tardi")
