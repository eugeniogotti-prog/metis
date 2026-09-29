#!/bin/bash
# test-routine-google.sh — moduli routine e google, con un Claude finto e un npx finto.
# Nessun LaunchAgent caricato, nessun login, nessuna sessione di Claude.
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

# copia del plugin con una skill finta di digest (le skill vere dei giri arrivano in un incremento successivo)
rsync -a --exclude .git --exclude prove "$SRC/" "$T/plugin/"; ROOT="$T/plugin"
mkdir -p "$ROOT/skills/daily-digest"; echo "finta" > "$ROOT/skills/daily-digest/SKILL.md"
mkdir -p "$T/vault/0 - Inbox" "$T/cfg"
export METIS_CONFIG="$T/cfg/config" METIS_LAUNCHAGENTS="$T/LA" METIS_ROOT="$ROOT"
printf 'METIS_VAULT=%s\nMETIS_LOG_DIR=%s/log\nMETIS_LABEL=com.metis.prova\nMETIS_MEMORY_DIR=%s/mem\n' "$T/vault" "$T" "$T" > "$METIS_CONFIG"
echo '{}' > "$T/cfg/permessi-routine.json"
cat > "$T/claude-finto" <<'EOF'
#!/bin/bash
cat > /dev/null; echo "$*" >> "$(dirname "$0")/claude-args.txt"
case "${ESITO_FINTO:-ok}" in
  ok) printf '{"result":"Digest scritto nella nota del giorno.\\nTre scadenze questa settimana.","is_error":false}' ;;
  errore) printf '{"result":"login scaduto","is_error":true}' ;;
  crash) exit 1 ;;
esac
EOF
chmod +x "$T/claude-finto"; export METIS_CLAUDE="$T/claude-finto"
OGGI=$(date +%F); D="$T/vault/Journal/$OGGI.md"

echo "1. Giro automatico (metis-agent)"
bash "$ROOT/scripts/metis-agent.sh" daily-digest >/dev/null
check "giro riuscito: riga 🤖 sotto # Memo" 'grep -A3 "^# Memo" "$D" | grep -q "🤖 .* daily-digest: Digest scritto"'
check "nota del giorno creata con frontmatter" 'head -1 "$D" | grep -q "^---" && grep -q "tipo/daily" "$D"'
check "resoconto nel log di sessione" 'grep -q "giro automatico daily-digest" "$T/vault/_Claude/sessioni/$OGGI.md"'
check "Claude lanciato con le regole delle routine e acceptEdits" 'grep -q -- "--settings $T/cfg/permessi-routine.json" "$T/claude-args.txt" && grep -q "acceptEdits" "$T/claude-args.txt"'
check "niente skip-permissions" '! grep -q "dangerously\|bypassPermissions" "$T/claude-args.txt"'
ESITO_FINTO=errore bash "$ROOT/scripts/metis-agent.sh" daily-digest >/dev/null 2>&1; RC=$?
check "errore dichiarato da Claude: codice 1 e riga ⚠️ metis-agent" '[ "$RC" = 1 ] && grep -q "⚠️ metis-agent .* daily-digest: fallito" "$D"'
ESITO_FINTO=crash bash "$ROOT/scripts/metis-agent.sh" daily-digest >/dev/null 2>&1
check "Claude che si ferma: riga ⚠️ metis-agent" '[ "$(grep -c "⚠️ metis-agent" "$D")" = 2 ]'
bash "$ROOT/scripts/metis-agent.sh" weekly-digest >/dev/null 2>&1; RC=$?
check "skill assente nel plugin: il giro non parte e lo dice" '[ "$RC" = 1 ] && grep -q "weekly-digest: non partito, la skill weekly-digest non è ancora nel plugin" "$D"'
mkdir -p "$ROOT/skills/inbox-processor"; echo finta > "$ROOT/skills/inbox-processor/SKILL.md"
N=$(wc -l < "$T/claude-args.txt")
bash "$ROOT/scripts/metis-agent.sh" inbox-processor >/dev/null
check "Inbox vuota: nessuna sessione di Claude" '[ "$(wc -l < "$T/claude-args.txt")" = "$N" ]'
echo "---" > "$T/vault/0 - Inbox/nota.md"
bash "$ROOT/scripts/metis-agent.sh" inbox-processor >/dev/null
check "Inbox con una nota: il giro parte" '[ "$(wc -l < "$T/claude-args.txt")" -gt "$N" ]'
bash "$ROOT/scripts/metis-agent.sh" sconosciuto >/dev/null 2>&1; check "lavoro sconosciuto rifiutato" '[ $? = 2 ]'

echo "2. Il doctor vede i giri falliti di ieri"
IERI=$(date -v-1d +%F); cp "$D" "$T/vault/Journal/$IERI.md"
mkdir -p "$T/vault/_Claude"; cp "$SRC/templates/memoria/_Claude/_Claude.md.txt" "$T/vault/_Claude/_Claude.md"
printf 'METIS_JOBS=daily-digest\n' >> "$METIS_CONFIG"
bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
check "doctor rosso con il giro fallito di ieri" 'grep -q "❌ Un giro automatico è fallito ieri" "$T/vault/_Claude/doctor.md"'

echo "3. Modulo routine"
printf 'METIS_JOBS=daily-digest inbox-processor weekly-digest\nMETIS_ORARI_INBOX_PROCESSOR=08:30 18:00\n' >> "$METIS_CONFIG"
bash "$ROOT/scripts/moduli/routine.sh" installa --senza-caricare >/dev/null
for j in doctor daily-digest inbox-processor weekly-digest; do
  check "LaunchAgent $j generato e valido" 'plutil -lint "$T/LA/com.metis.prova.$j.plist" >/dev/null'
done
check "doctor alle 06:45" '[ "$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:0:Hour" "$T/LA/com.metis.prova.doctor.plist")" = 6 ]'
check "orari dell'inbox dalla configurazione (08:30 e 18:00)" '[ "$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:1:Hour" "$T/LA/com.metis.prova.inbox-processor.plist")" = 18 ]'
check "weekly solo il lunedì" '[ "$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:0:Weekday" "$T/LA/com.metis.prova.weekly-digest.plist")" = 1 ]'
check "giro di Claude lanciato da metis-agent" '/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$T/LA/com.metis.prova.daily-digest.plist" | grep -q "metis-agent.sh"'
check "controlla: segnala i LaunchAgent non caricati" '! bash "$ROOT/scripts/moduli/routine.sh" controlla >/dev/null'

echo "4. Modulo google"
cat > "$T/npx-finto" <<'EOF'
#!/bin/bash
echo "$*" >> "$(dirname "$0")/npx-args.txt"
case "$*" in
  *" status") [ -f "$HOME_FINTA/.google-mcp/credentials.json" ] && echo "✅ Server is ready" || printf '❌ Credentials file NOT found\n⚠️  1 issue(s) found.\n' ;;
  *"test-permissions") exit 0 ;;
esac
exit 0
EOF
chmod +x "$T/npx-finto"; export METIS_NPX="$T/npx-finto" HOME_FINTA="$T/home" METIS_GOOGLE_DIR="$T/home/.google-mcp"
G="bash $ROOT/scripts/moduli/google.sh"
echo '{"web":{}}' > "$T/cred-web.json"; echo '{"installed":{"client_id":"x"}}' > "$T/cred.json"
check "credenziali di un tipo sbagliato rifiutate" '! $G credenziali "$T/cred-web.json" 2>/dev/null'
$G credenziali "$T/cred.json" >/dev/null
check "credenziali copiate con permessi 600" '[ "$(stat -f %Lp "$T/home/.google-mcp/credentials.json")" = 600 ]'
$G routine >/dev/null
M="$T/cfg/mcp-routine.json"
check "server delle routine in sola lettura, versione fissata" 'grep -q -- "--read-only" "$M" && grep -q "google-workspace-mcp@2.3.6" "$M"'
check "file MCP delle routine con permessi 600" '[ "$(stat -f %Lp "$M")" = 600 ]'
check "strumenti del server ammessi nelle routine" 'bash "$ROOT/scripts/configura.sh" get METIS_ROUTINE_STRUMENTI | grep -qw mcp__google'
check "controlla con tutto a posto: 0" '$G controlla >/dev/null'
rm "$T/home/.google-mcp/credentials.json"
check "controlla senza credenziali: fallisce" '! $G controlla >/dev/null'
: > "$T/claude-args.txt"; bash "$ROOT/scripts/metis-agent.sh" daily-digest >/dev/null
check "giro con il server Google e i suoi strumenti" 'grep -q -- "--mcp-config $M" "$T/claude-args.txt" && grep -q -- "--allowedTools mcp__google" "$T/claude-args.txt"'

echo "5. Il doctor controlla i moduli installati"
bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
check "google senza credenziali: avviso nel doctor" 'grep -q "⚠️ google: credenziali OAuth assenti" "$T/vault/_Claude/doctor.md"'
check "routine con LaunchAgent non caricati: avviso nel doctor" 'grep -q "⚠️ routine:" "$T/vault/_Claude/doctor.md"'
$G credenziali "$T/cred.json" >/dev/null; bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
check "google con le credenziali: controllo superato" 'grep -q "✅ google: controllo superato" "$T/vault/_Claude/doctor.md"'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
