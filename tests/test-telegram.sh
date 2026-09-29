#!/bin/bash
# test-telegram.sh — prova del bot di Metis contro un server finto del Bot API e di Groq, con un Claude finto.
# Nessun bot reale, nessuna chiave vera, nessuna sessione di Claude.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; PORTA=$((20000 + RANDOM % 20000))
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

# ambiente: configurazione, segreti, vault, server finto, Claude finto
mkdir -p "$T/cfg" "$T/vault/0 - Inbox" "$T/finto/file"
export METIS_CONFIG="$T/cfg/config"
printf 'METIS_VAULT=%s\nMETIS_LOG_DIR=%s/log\n' "$T/vault" "$T" > "$METIS_CONFIG"
( umask 077; printf 'TOKEN=123:finto\nCHAT_ID=4242\n' > "$T/cfg/telegram"; printf 'KEY=chiave-finta\n' > "$T/cfg/groq" )
echo '{}' > "$T/cfg/permessi-routine.json"
echo "123:finto" > "$T/finto/token.txt"
printf 'nota comprare il toner per lo studio' > "$T/finto/trascrizione.txt"
printf 'byte del vocale' > "$T/finto/file/voce1"; printf '%%PDF-1.4 finto' > "$T/finto/file/doc1"
cat > "$T/claude-finto" <<'EOF'
#!/bin/bash
PROMPT=$(cat); echo "$* | $(printf '%s' "$PROMPT" | tail -1)" >> "$(dirname "$0")/claude-chiamate.txt"
printf '{"result":"Risposta di prova a: %s","session_id":"sessione-1"}' "$(printf '%s' "$PROMPT" | tail -1)"
EOF
chmod +x "$T/claude-finto"
export METIS_TELEGRAM_API="http://127.0.0.1:$PORTA" METIS_GROQ_API="http://127.0.0.1:$PORTA" METIS_CLAUDE="$T/claude-finto"
python3 "$ROOT/tests/finto_telegram.py" "$T/finto" $PORTA & SRV=$!
trap 'kill $SRV 2>/dev/null; rm -rf "$T"' EXIT
sleep 1

upd() {  # upd <id> <chat> <campi JSON del messaggio>
  printf '{"update_id":%s,"message":{"message_id":%s,"date":1790000000,"chat":{"id":%s,"type":"private","first_name":"Anna"},%s}}' "$1" "$1" "$2" "$3"
}
TG="python3 $ROOT/scripts/telegram/metis_telegram.py"

echo "1. Invio"
$TG invia "Prova dal Mac" && ok "invio riuscito" || ko "invio riuscito"
check "messaggio arrivato alla chat del cliente" 'grep -q "\"chat_id\": \"4242\", \"text\": \"Prova dal Mac\"" "$T/finto/inviati.jsonl"'
LUNGO=$(python3 -c 'print("x"*9000)'); $TG invia "$LUNGO" >/dev/null
check "testo lungo spezzato in tre messaggi" '[ "$(grep -c "xxxxx" "$T/finto/inviati.jsonl")" = 3 ]'

echo "2. Ascolto: smistamento"
{
  echo "["
  upd 1 4242 '"text":"nota: richiamare il commercialista per il 730"'; echo ","
  upd 2 4242 '"text":"https://www.esempio.it/articolo"'; echo ","
  upd 3 4242 '"text":"Testo inoltrato da un collega","forward_date":1790000000'; echo ","
  upd 4 4242 '"document":{"file_id":"doc1","file_name":"preventivo.pdf"},"caption":"preventivo del fornitore"'; echo ","
  upd 5 4242 '"voice":{"file_id":"voce1","duration":4}'; echo ","
  upd 6 4242 '"text":"Che cosa ho in scadenza questa settimana?"'; echo ","
  upd 7 9999 '"text":"messaggio di un estraneo"'; echo ","
  upd 8 4242 '"text":"E la settimana dopo?"'
  echo "]"
} > "$T/finto/aggiornamenti.json"
$TG ascolta --una-volta; RC=$?
check "giro dell'ascoltatore concluso (codice $RC)" '[ "$RC" = 0 ]'
I="$T/vault/0 - Inbox"
check "«nota:» → nota in Inbox/telegram, senza la parola nota" 'grep -rlq "^richiamare il commercialista" "$I/telegram"'
check "link → nota in Inbox/telegram" 'grep -rlq "https://www.esempio.it/articolo" "$I/telegram"'
check "inoltrato → nota in Inbox/telegram" 'grep -rlq "Testo inoltrato da un collega" "$I/telegram"'
check "documento → file in Inbox/files" '[ -f "$I/files/preventivo.pdf" ]'
check "documento → nota con il percorso del file" 'grep -rlq "preventivo.pdf" "$I/telegram"'
check "vocale che comincia con «nota» → Inbox/voicenotes" 'grep -rlq "comprare il toner" "$I/voicenotes"'
check "trascrizione chiamata con la chiave" 'grep -q "\"auth\": \"Bearer chiave-finta\"" "$T/finto/chiamate.jsonl"'
check "note con frontmatter e tag con prefisso" '! grep -rL -e "^- contenuto/" "$I/telegram" "$I/voicenotes" | grep -q .'
check "testo normale → conversazione con Claude" 'grep -q "Che cosa ho in scadenza" "$T/claude-chiamate.txt"'
check "risposta di Claude tornata nella chat" 'grep -q "Risposta di prova a: Che cosa ho in scadenza" "$T/finto/inviati.jsonl"'
check "secondo messaggio: stessa conversazione ripresa" 'grep "E la settimana dopo" "$T/claude-chiamate.txt" | grep -q -- "--resume sessione-1"'
check "Claude lanciato con le regole delle routine" 'grep -q -- "--settings" "$T/claude-chiamate.txt"'
check "messaggio di un estraneo ignorato" '! grep -q "estraneo" "$T/claude-chiamate.txt" && ! grep -rq "estraneo" "$I"'
check "estraneo registrato nel log" 'grep -q "ignorato un messaggio dalla chat 9999" "$T/log/telegram.log"'
check "nessuna risposta mandata all'estraneo" '! grep -q "\"chat_id\": \"9999\"" "$T/finto/inviati.jsonl"'

echo "3. Ripresa dopo il riavvio"
N1=$(wc -l < "$T/claude-chiamate.txt")
$TG ascolta --una-volta >/dev/null
check "gli stessi messaggi non vengono rielaborati" '[ "$(wc -l < "$T/claude-chiamate.txt")" = "$N1" ]'

echo "4. Sicurezza dei segreti"
chmod 644 "$T/cfg/telegram"
check "file del token leggibile da altri: rifiutato" '! $TG invia "x" 2>/dev/null'
chmod 600 "$T/cfg/telegram"
printf 'TOKEN=999:sbagliato\nCHAT_ID=4242\n' > "$T/cfg/telegram"; chmod 600 "$T/cfg/telegram"
check "token sbagliato: errore, nessun invio" '! $TG invia "x" 2>/dev/null'

echo "5. Vocale senza la parola «nota»: va in conversazione"
printf 'TOKEN=123:finto\nCHAT_ID=4242\n' > "$T/cfg/telegram"; chmod 600 "$T/cfg/telegram"
printf 'quali sono le scadenze di ottobre' > "$T/finto/trascrizione.txt"
echo "[$(upd 9 4242 '"voice":{"file_id":"voce1","duration":3}')]" > "$T/finto/aggiornamenti.json"
$TG ascolta --una-volta >/dev/null
check "trascrizione mandata a Claude" 'grep -q "quali sono le scadenze di ottobre" "$T/claude-chiamate.txt"'
check "risposta con «Ho capito»" 'grep -q "Ho capito: «quali sono le scadenze di ottobre»" "$T/finto/inviati.jsonl"'

echo "6. Script del modulo telegram (configurazione guidata)"
export METIS_LAUNCHAGENTS="$T/LaunchAgents"
rm -f "$T/cfg/telegram"
M="bash $ROOT/scripts/moduli/telegram.sh"
check "installa senza token: si ferma e dice che cosa manca" '$M installa | grep -q "manca il token"'
check "token non valido nella forma: rifiutato" '! printf "non-un-token\n" | $M token 2>/dev/null'
check "token sbagliato per Telegram: segnalato" '! printf "555:sbagliato\n" | $M token 2>/dev/null'
printf '123:finto\n' | $M token >/dev/null 2>&1
check "token giusto: salvato con permessi 600" '[ "$(stat -f %Lp "$T/cfg/telegram")" = 600 ] && grep -q "^TOKEN=123:finto" "$T/cfg/telegram"'
echo "[$(upd 20 4242 '"text":"ciao"')]" > "$T/finto/aggiornamenti.json"
check "chat trovata dal primo messaggio" '$M chat >/dev/null && grep -q "^CHAT_ID=4242" "$T/cfg/telegram"'
check "installa: prova mandata e modulo registrato" '$M installa >/dev/null && grep -q "Messaggio di prova di" "$T/finto/inviati.jsonl" && bash "$ROOT/scripts/configura.sh" get METIS_MODULI | grep -qw telegram'
check "ascoltatore: LaunchAgent generato e valido (non caricato)" '$M ascoltatore --senza-caricare >/dev/null && plutil -lint "$T/LaunchAgents/"*.telegram.plist >/dev/null'
check "LaunchAgent sempre acceso, con PATH di Homebrew e configurazione" 'grep -q "<key>KeepAlive</key>" "$T/LaunchAgents/"*.telegram.plist && grep -q "/opt/homebrew/bin" "$T/LaunchAgents/"*.telegram.plist && grep -q "$METIS_CONFIG" "$T/LaunchAgents/"*.telegram.plist'
check "controlla: segnala l'ascoltatore non caricato" '! $M controlla | grep -q "✅ ascoltatore" && $M controlla | grep -q "generato ma non caricato"'

echo "7. Script del modulo voce"
rm -f "$T/cfg/groq"
V="bash $ROOT/scripts/moduli/voce.sh"
check "controlla senza chiave: segnala" '! $V controlla >/dev/null'
printf 'chiave-finta\n' | $V chiave >/dev/null 2>&1
printf 'silenzio' > "$T/finto/trascrizione.txt"
check "chiave salvata con permessi 600" '[ "$(stat -f %Lp "$T/cfg/groq")" = 600 ]'
check "controlla: trascrizione vera di un secondo di audio" '$V controlla | grep -q "trascrizione riuscita"'
printf 'chiave-sbagliata\n' | $V chiave >/dev/null 2>&1
check "chiave sbagliata: controllo fallito" '! $V controlla >/dev/null'

echo "8. Segreti letti da file esistenti, senza copiarli"
mkdir -p "$T/esterni"; ( umask 077; printf '123:finto\n' > "$T/esterni/tok"; printf '4242\n' > "$T/esterni/chat"; printf 'ALTRO=x\nGROQ_API_KEY=chiave-finta\n' > "$T/esterni/.env" )
rm -f "$T/cfg/telegram" "$T/cfg/groq"
printf 'METIS_TELEGRAM_TOKEN_FILE=%s\nMETIS_TELEGRAM_CHAT_FILE=%s\nMETIS_GROQ_FILE=%s\n' "$T/esterni/tok" "$T/esterni/chat" "$T/esterni/.env" >> "$METIS_CONFIG"
: > "$T/finto/inviati.jsonl"
check "verifica: token valido e chat salvata, senza mostrarli" '$TG verifica | grep -q "token valido" && ! $TG verifica | grep -q "123:finto"'
check "invio con il token letto dal file" '$TG invia "via file" && grep -q "via file" "$T/finto/inviati.jsonl"'
check "chiave Groq presa dalla variabile che contiene GROQ" 'bash "$ROOT/scripts/moduli/voce.sh" controlla 2>/dev/null | grep -q "trascrizione riuscita"'
chmod 644 "$T/esterni/tok"
check "file del token troppo aperto: rifiutato" '! $TG invia "x" 2>/dev/null'
chmod 600 "$T/esterni/tok"
check "nessuna copia dei segreti nella cartella di configurazione" '[ ! -e "$T/cfg/telegram" ] && [ ! -e "$T/cfg/groq" ]'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
