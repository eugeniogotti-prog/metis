#!/bin/bash
# test-posta-locale.sh — modulo google, strada «posta locale» (decisione del 23/10/2026): guardia, permessi,
# controllo del token e controlli di gmail-bozza.mjs che precedono l'avvio del server. Nessuna rete, nessun server avviato.
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
mkdir -p "$T/vault" "$T/cfg"
export METIS_CONFIG="$T/cfg/config" CLAUDE_PLUGIN_ROOT="$SRC"
decisione() {  # decisione <strumento> → deny|ask|passa
  printf '{"tool_name":"%s","cwd":"%s","tool_input":{}}' "$1" "$T/vault" | bash "$SRC/hooks/guardia.sh" \
    | python3 -c 'import sys,json; s=sys.stdin.read(); print(json.loads(s)["hookSpecificOutput"]["permissionDecision"] if s.strip() else "passa")'
}
UUID=0a1b2c3d-0000-4000-8000-000000000000

echo "1. Guardia con la posta locale"
printf 'METIS_VAULT=%s\nMETIS_POSTA=locale\n' "$T/vault" > "$METIS_CONFIG"
check "connettore Gmail dell'app (UUID) rifiutato" '[ "$(decisione mcp__${UUID}__create_draft)" = deny ]'
check "connettore Gmail di Claude Code rifiutato" '[ "$(decisione mcp__claude_ai_Gmail__search_threads)" = deny ]'
check "calendario dell'app libero" '[ "$(decisione mcp__0a1b2c3d-1111-4000-8000-000000000001__list_events)" = passa ]'
check "bozza del server locale libera" '[ "$(decisione mcp__gmail-locale__draft_email)" = passa ]'
check "invio del server locale con conferma" '[ "$(decisione mcp__gmail-locale__send_email)" = ask ]'
echo "2. Guardia senza posta locale (default)"
printf 'METIS_VAULT=%s\n' "$T/vault" > "$METIS_CONFIG"
check "connettore Gmail libero" '[ "$(decisione mcp__${UUID}__create_draft)" = passa ]'
check "invio del connettore con conferma" '[ "$(decisione mcp__${UUID}__send_message)" = ask ]'
echo "2b. Guardia sulle cancellazioni (23/10/2026)"
check "cestino di Drive del connettore (UUID) con conferma" '[ "$(decisione mcp__${UUID}__trash_file)" = ask ]'
check "evento cancellato con conferma" '[ "$(decisione mcp__claude_ai_Google_Calendar__delete_event)" = ask ]'
check "bozza cancellata senza conferma" '[ "$(decisione mcp__gmail-locale__delete_draft)" = passa ] && [ "$(decisione mcp__claude_ai_Gmail__delete_draft)" = passa ]'
check "mail cancellata con conferma" '[ "$(decisione mcp__google-workspace__delete_email)" = ask ]'
check "cestino svuotato e cancellazione in blocco con conferma" '[ "$(decisione mcp__google-workspace__empty_trash)" = ask ] && [ "$(decisione mcp__google-workspace__batch_delete)" = ask ]'
check "file tolto con conferma" '[ "$(decisione mcp__drive__remove_file)" = ask ]'
check "bozza nuova libera" '[ "$(decisione mcp__gmail-locale__draft_email)" = passa ]'
check "lettura dei permessi libera" '[ "$(decisione mcp__google-workspace__get_sharing)" = passa ]'
check "elenco del cestino e ripristino liberi" '[ "$(decisione mcp__google-workspace__list_trash)" = passa ] && [ "$(decisione mcp__google-workspace__restore_from_trash)" = passa ]'
check "permesso tolto: resta libero come prima" '[ "$(decisione mcp__google-workspace__remove_permission)" = passa ]'

echo "3. Permessi"
printf 'METIS_VAULT=%s\nMETIS_POSTA=locale\n' "$T/vault" > "$METIS_CONFIG"
bash "$SRC/scripts/installa-permessi.sh" >/dev/null
S="$T/vault/.claude/settings.json"; R="$T/cfg/permessi-routine.json"
q() { python3 -c "import json,sys; p=json.load(open(sys.argv[1]))['permissions']; sys.exit(0 if sys.argv[3] in p.get(sys.argv[2],[]) else 1)" "$@"; }
check "bozze e allegati senza conferma" 'q "$S" allow mcp__gmail-locale__draft_email && q "$S" allow mcp__gmail-locale__download_attachment'
check "invio in ask" 'q "$S" ask mcp__gmail-locale__send_email'
check "cancellazione vietata" 'q "$S" deny mcp__gmail-locale__delete_email'
check "gmail-bozza ammesso nelle sessioni" 'grep -q "gmail-bozza.mjs" "$S"'
check "routine: bozze e invii vietati" 'q "$R" deny mcp__gmail-locale__draft_email && q "$R" deny mcp__gmail-locale__send_email'
printf 'METIS_VAULT=%s\n' "$T/vault" > "$METIS_CONFIG"; rm -rf "$T/vault/.claude"
bash "$SRC/scripts/installa-permessi.sh" >/dev/null
check "senza posta locale nessuna regola gmail-locale" '! grep -q "gmail-locale" "$S"'

echo "4. Controllo del token senza avviare il server"
G="$T/g"; mkdir -p "$G"
python3 "$SRC/scripts/google-token.py" --dir "$G" >/dev/null; check "credenziali assenti → 1" '[ $? = 1 ]'
echo '{"installed":{"client_id":"x.apps.googleusercontent.com","client_secret":"s"}}' > "$G/credentials.json"
python3 "$SRC/scripts/google-token.py" --dir "$G" >/dev/null; check "token assente → 1" '[ $? = 1 ]'
echo '{"access_token":"a"}' > "$G/tokens.json"
python3 "$SRC/scripts/google-token.py" --dir "$G" >/dev/null; check "token senza refresh → 1" '[ $? = 1 ]'

echo "5. gmail-bozza.mjs: controlli prima del server"
if command -v node >/dev/null; then
  B="$SRC/scripts/gmail-bozza.mjs"; cd "$T"
  printf 'a' > uno.txt; mkdir -p x y; printf 'a' > x/doppio.txt; printf 'b' > y/doppio.txt
  out() { node "$B" "$@" 2>/dev/null; }
  check "nomi duplicati rifiutati" 'out --to a@b.it --subject s --body b --attach x/doppio.txt --attach y/doppio.txt | grep -q "stesso nome"'
  check "--draft-id rifiutato: le bozze non si riscrivono" 'out --to a@b.it --subject s --body b --draft-id r-1 --senza-thread | grep -q "non si riscrive"'
  check "--sostituisce senza --se-messaggio rifiutato" 'out --to a@b.it --subject s --body b --sostituisce r-1 --senza-thread | grep -q "se-messaggio"'
  check "--sostituisce senza scelta sul thread rifiutato" 'out --to a@b.it --subject s --body b --sostituisce r-1 --se-messaggio m | grep -q "senza-thread"'
  head -c 20000000 /dev/zero > grande.bin
  check "oltre 25 MB codificati rifiutato" 'out --to a@b.it --subject s --body b --attach grande.bin | grep -q "troppo grandi"'
  check "server assente: errore immediato" 'METIS_GMAIL_SERVER=/inesistente out --to a@b.it --subject s --body b | grep -q "non avviato\|non trovato"'
  check "token assente: si ferma prima di avviare il server" 'GOOGLE_WORKSPACE_MCP_TOKEN_PATH=$T/nessuno/tokens.json METIS_GMAIL_SERVER=/usr/bin/true out --to a@b.it --subject s --body b | grep -q "autorizzazione Google assente"'
  check "nessuno strumento d'invio nel recinto" '! grep -E "STRUMENTI = new Set" "$B" | grep -q send'
  check "hash SHA-256, non SHA-1" 'grep -q "sha256" "$B" && ! grep -q "sha1" "$B"'

  echo "6. gmail-bozza.mjs con la finta Gmail locale (nessun account, nessuna rete)"
  F="$T/finta"; mkdir -p "$F/tok"; echo '{"refresh_token":"finto"}' > "$F/tok/tokens.json"
  fg() { FINTO_GMAIL="$F" METIS_GMAIL_SERVER="$SRC/tests/finto_gmail.mjs" GOOGLE_WORKSPACE_MCP_TOKEN_PATH="$F/tok/tokens.json" node "$B" "$@" 2>/dev/null; }
  j() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }
  printf 'contenuto del verbale' > verbale.pdf; printf 'tabella' > tabella.xlsx
  R=$(fg --to a@b.it --subject "Verbale" --body "Testo di Claude" --attach verbale.pdf --thread-id thr9)
  check "bozza creata, allegato verificato per hash" '[ "$(echo "$R" | j "d[\"ok\"] and d[\"allegati\"][0][\"ok\"] and len(d[\"allegati\"][0][\"sha256\"])==64")" = True ]'
  check "la bozza resta nel thread indicato" '[ "$(echo "$R" | j "d[\"threadId\"]")" = thr9 ]'
  D1=$(echo "$R" | j 'd["draftId"]')
  # il cliente corregge la bozza in Gmail: cambia il testo, e Gmail cambia l'id del messaggio
  python3 - "$F/bozze.json" <<'PY'
import json,sys; p=sys.argv[1]; d=json.load(open(p)); b=d["bozze"][0]; b["text"]="Testo corretto dal cliente"; b["id"]="msg-cliente"; json.dump(d,open(p,"w"))
PY
  L=$(fg --leggi "$D1" --salva-in letta)
  check "--leggi riporta il testo com'è in Gmail" '[ "$(cat letta/corpo.txt)" = "Testo corretto dal cliente" ]'
  check "--leggi salva gli allegati della bozza, identici" 'cmp -s letta/allegati/verbale.pdf verbale.pdf'
  check "--leggi riporta il messageId attuale" '[ "$(echo "$L" | j "d[\"messageId\"]")" = msg-cliente ]'
  R2=$(fg --to a@b.it --subject "Verbale" --body-file letta/corpo.txt --attach letta/allegati/verbale.pdf --attach tabella.xlsx --sostituisce "$D1" --se-messaggio msg-vecchio --thread-id thr9)
  check "--sostituisce si ferma se la bozza è cambiata dopo la lettura" 'echo "$R2" | grep -q "cambiata dopo la lettura"'
  check "... e non crea nessuna bozza" '[ "$(python3 -c "import json; print(len(json.load(open(\"$F/bozze.json\"))[\"bozze\"]))")" = 1 ]'
  R3=$(fg --to a@b.it --subject "Verbale" --body-file letta/corpo.txt --attach letta/allegati/verbale.pdf --attach tabella.xlsx --sostituisce "$D1" --se-messaggio msg-cliente --thread-id thr9)
  check "--sostituisce: bozza nuova verificata, vecchia cancellata" '[ "$(echo "$R3" | j "d[\"ok\"] and d[\"sostituita\"]")" = "$D1" ]'
  check "... resta una sola bozza, con il testo del cliente e due allegati" '[ "$(python3 -c "import json; b=json.load(open(\"$F/bozze.json\"))[\"bozze\"]; print(len(b), b[0][\"text\"], len(b[0][\"allegati\"]))")" = "1 Testo corretto dal cliente 2" ]'
  check "nessun update nella finta Gmail" '! grep -q "update non ammesso" "$F/chiamate.log" && ! grep -q "^draft_email \"r-" "$F/chiamate.log"'
  D3=$(echo "$R3" | j 'd["draftId"]'); M3=$(echo "$R3" | j 'd["messageId"]')
  R4=$(FINTO_ALTERA=1 fg --to a@b.it --subject "Verbale" --body b --attach verbale.pdf --sostituisce "$D3" --se-messaggio "$M3" --thread-id thr9)
  check "hash diverso: uscita 1 e bozza vecchia NON cancellata" 'echo "$R4" | grep -q "NON è stata cancellata" && grep -q "\"draftId\":\"$D3\"" "$F/bozze.json"'
  check "--leggi di una bozza inesistente: errore chiaro" 'fg --leggi r-999 | grep -q "bozza non trovata"'
  check "--leggi con testo troncato dal server: non ok" 'FINTO_TRONCA=1 fg --leggi "$D3" | grep -q "troncato"'
else
  echo "  (node assente: sezioni 5 e 6 saltate)"
fi

echo; echo "posta locale: $PASS ok, $FAIL falliti"; [ "$FAIL" = 0 ]
