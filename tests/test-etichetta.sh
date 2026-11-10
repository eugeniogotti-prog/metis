#!/bin/bash
# test-etichetta.sh — mail nel vault con un'etichetta di Gmail (google.sh etichetta, scripts/gmail-etichetta.py) e il
# tipo «ogni N minuti» degli automatismi (launchd e systemd). Gmail e Google sono finti (un server locale): nessun account.
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(cd "$(mktemp -d)" && pwd -P)"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
trap '[ -n "${PID:-}" ] && { kill "$PID"; wait "$PID"; } 2>/dev/null; rm -rf "$T"' EXIT

V="$T/vault"; mkdir -p "$V/0 - Inbox" "$V/_Claude" "$T/cfg" "$T/oauth"
export METIS_CONFIG="$T/cfg/config" METIS_ROOT="$SRC" XDG_CONFIG_HOME="$T/xdg"
printf 'METIS_VAULT=%s\nMETIS_LOG_DIR=%s/log\nMETIS_LABEL=com.metis.prova\nMETIS_MEMORY_DIR=%s/mem\nMETIS_JOBS=\n' "$V" "$T" "$T" > "$METIS_CONFIG"
mkdir -p "$XDG_CONFIG_HOME/google-workspace-mcp"
echo '{"installed":{"client_id":"cid","client_secret":"sec"}}' > "$XDG_CONFIG_HOME/google-workspace-mcp/credentials.json"
echo '{"refresh_token":"rt","access_token":"vecchio"}' > "$XDG_CONFIG_HOME/google-workspace-mcp/tokens.json"
TOK_PRIMA=$(cat "$XDG_CONFIG_HOME/google-workspace-mcp/tokens.json")

# Gmail finto: etichette, due mail con «vault» (una con HTML e allegato), modify registrato.
cat > "$T/finto.py" <<'PY'
import base64, json, sys, http.server, urllib.parse
b = lambda s: base64.urlsafe_b64encode(s.encode()).decode().rstrip("=")
stato = {"labels": [{"id": "INBOX", "name": "INBOX"}], "lab": {"m1": [], "m2": []}, "log": []}
MSG = {
 "m1": {"id": "m1", "threadId": "t1", "snippet": "s", "payload": {"mimeType": "multipart/mixed", "headers": [
   {"name": "From", "value": "Paola Rinaldi <paola@esempio.it>"}, {"name": "To", "value": "cliente@esempio.it"},
   {"name": "Subject", "value": "Preventivo: corso/sicurezza"}, {"name": "Date", "value": "Mon, 10 Nov 2026 09:15:00 +0100"}],
   "parts": [{"mimeType": "text/plain", "body": {"data": b("Buongiorno,\nle mando il preventivo. Città è già pronta.")}},
             {"mimeType": "application/pdf", "filename": "preventivo.pdf", "body": {"size": 20480, "attachmentId": "a"}}]}},
 "m2": {"id": "m2", "threadId": "t2", "snippet": "s2", "payload": {"mimeType": "text/html", "headers": [
   {"name": "From", "value": "news@esempio.it"}, {"name": "Subject", "value": "Notizie"},
   {"name": "Date", "value": "Tue, 11 Nov 2026 08:00:00 +0000"}], "body": {"data": b("<p>Riga uno</p><p>Riga &amp; due</p>")}}},
}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def manda(self, c, d):
        x = json.dumps(d).encode(); self.send_response(c); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(x))); self.end_headers(); self.wfile.write(x)
    def corpo(self):
        n = int(self.headers.get("Content-Length") or 0); return self.rfile.read(n).decode() if n else ""
    def do_POST(self):
        p = urllib.parse.urlparse(self.path).path; c = self.corpo()
        if p == "/token":
            q = urllib.parse.parse_qs(c); stato["log"].append("token")
            return self.manda(200 if q.get("refresh_token") == ["rt"] else 400, {"access_token": "AT"} if q.get("refresh_token") == ["rt"] else {"error": "invalid_grant"})
        if self.headers.get("Authorization") != "Bearer AT": return self.manda(401, {})
        if p == "/labels":
            d = json.loads(c); l = {"id": "L" + str(len(stato["labels"])), "name": d["name"]}; stato["labels"].append(l)
            stato["log"].append("crea " + d["name"]); return self.manda(200, l)
        if p.endswith("/modify"):
            mid = p.split("/")[-2]; d = json.loads(c)
            stato["lab"][mid] = [x for x in stato["lab"][mid] if x not in d["removeLabelIds"]] + d["addLabelIds"]
            stato["log"].append("modify " + mid); return self.manda(200, {})
        self.manda(404, {})
    def do_GET(self):
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
        if u.path == "/stato": return self.manda(200, stato)
        if self.headers.get("Authorization") != "Bearer AT": return self.manda(401, {})
        if u.path == "/labels": return self.manda(200, {"labels": stato["labels"]})
        if u.path == "/messages":
            l = q["labelIds"][0]; return self.manda(200, {"messages": [{"id": k} for k, v in sorted(stato["lab"].items()) if l in v]})
        if u.path.startswith("/messages/"): return self.manda(200, MSG[u.path.split("/")[2]])
        self.manda(404, {})
    def do_PUT(self):   # solo per la prova: mette l'etichetta alle mail
        d = json.loads(self.corpo()); [stato["lab"][m].append(d["label"]) for m in d["msgs"]]; self.manda(200, {})
s = http.server.HTTPServer(("127.0.0.1", 0), H); print(s.server_port, flush=True); s.serve_forever()
PY
python3 "$T/finto.py" > "$T/porta" & PID=$!
for _ in $(seq 50); do [ -s "$T/porta" ] && break; sleep 0.1; done
P=$(cat "$T/porta"); U="http://127.0.0.1:$P"
export METIS_GOOGLE_TOKEN_URL="$U/token" METIS_GMAIL_API="$U"
G="bash $SRC/scripts/moduli/google.sh"
E="$V/0 - Inbox/Email"
stato() { curl -s "$U/stato"; }

echo "== Giro di prova senza etichetta in Gmail"
OUT=$($G etichetta --prova 2>&1); RC=$?
check "--prova: esce con 0" '[ $RC = 0 ]'
check "--prova: etichetta assente, non creata" 'echo "$OUT" | grep -q "assente" && ! stato | grep -q "crea vault"'

echo "== Primo giro vero: crea l'etichetta, nessuna mail"
OUT=$($G etichetta 2>&1); RC=$?
check "giro senza mail: esce con 0 e non scrive righe" '[ $RC = 0 ] && [ -z "$OUT" ]'
check "etichetta «vault» creata in Gmail" 'stato | grep -q "crea vault"'
check "nessuna cartella Email creata senza mail" '[ ! -d "$E" ]'
LID=$(stato | python3 -c 'import json,sys; print([l["id"] for l in json.load(sys.stdin)["labels"] if l["name"]=="vault"][0])')
curl -s -X PUT -d "{\"label\":\"$LID\",\"msgs\":[\"m1\",\"m2\"]}" "$U/x" >/dev/null

echo "== --prova con due mail etichettate"
OUT=$($G etichetta --prova 2>&1)
check "--prova elenca le due mail" '[ "$(echo "$OUT" | grep -c PROVA)" = 2 ]'
check "--prova non scrive e non cambia etichette" '[ ! -d "$E" ] && ! stato | grep -q modify'

echo "== Giro vero con due mail"
OUT=$($G etichetta 2>&1); RC=$?
check "esce con 0" '[ $RC = 0 ]'
check "due note in Email/" '[ "$(ls "$E" | grep -c "\.md$")" = 2 ]'
N1=$(ls "$E" | grep "Preventivo" | head -1)
check "nome: data, «Email», oggetto senza «/» e «:», mittente" '[ "$N1" = "2026-11-10 Email Preventivo corso sicurezza — Paola Rinaldi.md" ]'
F1="$E/$N1"
check "frontmatter: tag, up, source, gmail_id" 'grep -q "^- contenuto/email" "$F1" && grep -q "^- '"'"'\[\[0 - Inbox\]\]'"'"'" "$F1" && grep -q "^source: Gmail" "$F1" && grep -q "^gmail_id: m1$" "$F1"'
check "testo in chiaro con gli accenti" 'grep -q "Città è già pronta" "$F1"'
check "allegato elencato, non scaricato" 'grep -q "preventivo.pdf (application/pdf, 20 KB)" "$F1"'
check "link al thread" 'grep -q "mail.google.com/mail/u/0/#all/t1" "$F1"'
F2="$E/$(ls "$E" | grep Notizie)"
check "mail solo HTML convertita in testo" 'grep -q "Riga & due" "$F2" && ! grep -q "<p>" "$F2"'
check "etichetta cambiata su tutte e due (vault → vault-fatto)" '[ "$(stato | grep -o "modify m[12]" | sort -u | wc -l | tr -d " ")" = 2 ] && stato | grep -q "crea vault-fatto"'
check "riga di riepilogo nel registro" 'echo "$OUT" | grep -q "2 mail con l.etichetta «vault»: 2 note nuove"'
check "file dei token non toccato" '[ "$(cat "$XDG_CONFIG_HOME/google-workspace-mcp/tokens.json")" = "$TOK_PRIMA" ]'

echo "== Giro interrotto prima di cambiare l'etichetta: niente doppioni"
curl -s -X PUT -d "{\"label\":\"$LID\",\"msgs\":[\"m1\"]}" "$U/x" >/dev/null
$G etichetta >/dev/null 2>&1
check "la mail già scritta non si riscrive" '[ "$(ls "$E" | grep -c "\.md$")" = 2 ]'
check "ma l'etichetta si cambia lo stesso" '[ "$(stato | grep -o "modify m1" | wc -l | tr -d " ")" = 2 ]'

echo "== Etichetta configurabile"
echo "METIS_ETICHETTA_VAULT=archivio-mail" >> "$METIS_CONFIG"
$G etichetta >/dev/null 2>&1
check "METIS_ETICHETTA_VAULT: crea «archivio-mail»" 'stato | grep -q "crea archivio-mail"'

echo "== Autorizzazione revocata"
echo '{"refresh_token":"revocato"}' > "$XDG_CONFIG_HOME/google-workspace-mcp/tokens.json"
OUT=$($G etichetta 2>&1); RC=$?
check "esce con 1 e dice come rimediare" '[ $RC = 1 ] && echo "$OUT" | grep -q "account-posta"'
rm "$XDG_CONFIG_HOME/google-workspace-mcp/tokens.json"
OUT=$($G etichetta 2>&1); RC=$?
check "senza token: esce con 1" '[ $RC = 1 ] && echo "$OUT" | grep -q "credenziali-posta"'
OUT=$($G etichetta-installa 2>&1); RC=$?
check "etichetta-installa senza autorizzazione: si ferma" '[ $RC = 1 ] && [ ! -e "$T/systemd" ]'

echo "== Tipo «ogni N minuti»: systemd (Linux simulato)"
echo "$TOK_PRIMA" > "$XDG_CONFIG_HOME/google-workspace-mcp/tokens.json"
cat > "$T/sc" <<'EOF'
#!/bin/bash
D="$(dirname "$0")/st"; mkdir -p "$D"; [ "$1" = --user ] && shift; az="$1"; shift; [ "${1:-}" = --now ] && shift
case "$az" in enable|restart|start) touch "$D/$1" ;; disable) rm -f "$D/$1" ;; is-enabled|is-active) [ -f "$D/$1" ] ;; *) exit 0 ;; esac
EOF
chmod +x "$T/sc"
printf 'METIS_SYSTEMD_DIR=%s/systemd\n' "$T" >> "$METIS_CONFIG"
sed -i.bak 's|^METIS_ETICHETTA_VAULT=.*||' "$METIS_CONFIG"; echo "METIS_ETICHETTA_MINUTI=15" >> "$METIS_CONFIG"
OUT=$(METIS_SISTEMA=Linux METIS_SYSTEMCTL="$T/sc" $G etichetta-installa 2>&1); RC=$?
TM="$T/systemd/com.metis.prova.gmail-etichetta.timer"; SV="$T/systemd/com.metis.prova.gmail-etichetta.service"
check "etichetta-installa: esce con 0" '[ $RC = 0 ]'
check "timer ogni 15 minuti" 'grep -q "^OnUnitActiveSec=15min$" "$TM" && grep -q "^OnActiveSec=1min$" "$TM" && ! grep -q OnCalendar "$TM"'
check "servizio oneshot che lancia google.sh etichetta" 'grep -q "^Type=oneshot" "$SV" && grep -q "google.sh\" \"etichetta\"" "$SV"'
check "timer caricato" '[ -f "$T/st/com.metis.prova.gmail-etichetta.timer" ]'
OUT=$(METIS_SISTEMA=Linux METIS_SYSTEMCTL="$T/sc" $G controlla 2>&1)
check "controlla: giro caricato" 'echo "$OUT" | grep -q "✅ mail con l.etichetta «vault»: giro caricato"'
METIS_SISTEMA=Linux METIS_SYSTEMCTL="$T/sc" $G etichetta-togli >/dev/null 2>&1
check "etichetta-togli: timer fermato" '[ ! -f "$T/st/com.metis.prova.gmail-etichetta.timer" ]'
OUT=$(METIS_SISTEMA=Linux METIS_SYSTEMCTL="$T/sc" bash "$SRC/scripts/lib/servizi.sh" genera x ogni 0 /bin/true 2>&1); RC=$?
check "«ogni 0» rifiutato" '[ $RC = 2 ]'
OUT=$(METIS_SISTEMA=Linux METIS_SYSTEMCTL="$T/sc" bash "$SRC/scripts/lib/servizi.sh" genera x ogni 07:00 /bin/true 2>&1); RC=$?
check "«ogni 07:00» rifiutato" '[ $RC = 2 ]'

if [ "$(uname -s)" = Darwin ]; then
  echo "== Tipo «ogni N minuti»: launchd (Mac, senza caricare)"
  printf 'METIS_LAUNCHAGENTS=%s/la\n' "$T" >> "$METIS_CONFIG"
  OUT=$(METIS_SENZA_CARICARE=1 METIS_LAUNCHAGENTS="$T/la" $G etichetta-installa 2>&1); RC=$?
  PL="$T/la/com.metis.prova.gmail-etichetta.plist"
  check "plist generato e valido" '[ $RC = 0 ] && plutil -lint "$PL" >/dev/null'
  check "StartInterval 900 secondi, RunAtLoad, niente orari" '[ "$(plutil -extract StartInterval raw "$PL")" = 900 ] && [ "$(plutil -extract RunAtLoad raw "$PL")" = true ] && ! plutil -extract StartCalendarInterval raw "$PL" >/dev/null 2>&1'
fi

echo ""; echo "Risultato: $PASS passati, $FAIL falliti"
[ "$FAIL" = 0 ]
