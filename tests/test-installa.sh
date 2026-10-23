#!/bin/bash
# test-installa.sh — prova degli script d'installazione (blocchi 0-3) e degli hook guardia, valida-scrittura, pre-compact.
# Tutto in una mktemp -d; nessun vault reale, nessuna sessione di Claude.
# Uso: bash tests/test-installa.sh <cartella dei modelli>

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="${1:?uso: bash tests/test-installa.sh <cartella dei modelli>}"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
evento() {  # evento <strumento> <cwd> <tool_input JSON>
  printf '{"hook_event_name":"PreToolUse","tool_name":"%s","cwd":"%s","tool_input":%s}' "$1" "$2" "$3"
}
export METIS_CONFIG="$T/config"
V="$T/Studio Rossi"; mkdir -p "$V"

echo "0. Modelli nel plugin allineati alla fonte"
check "templates/memoria identico alla cartella dei modelli" 'diff -r "$ROOT/templates/memoria" "$MOD" >/dev/null'

echo "1. Configurazione"
bash "$ROOT/scripts/configura.sh" set METIS_VAULT "$V" >/dev/null
bash "$ROOT/scripts/configura.sh" set METIS_FONTI "$T/fonti" >/dev/null
bash "$ROOT/scripts/configura.sh" set METIS_MEMORY_DIR "$T/mem" >/dev/null
bash "$ROOT/scripts/configura.sh" set METIS_RUOLO_RISERVATA "_Privato" >/dev/null
bash "$ROOT/scripts/configura.sh" set METIS_JOBS "" >/dev/null
bash "$ROOT/scripts/configura.sh" aggiungi METIS_MODULI telegram >/dev/null; bash "$ROOT/scripts/configura.sh" aggiungi METIS_MODULI telegram >/dev/null
check "valore con spazi letto intero" '[ "$(bash "$ROOT/scripts/configura.sh" get METIS_VAULT)" = "$V" ]'
check "voce di lista aggiunta una volta sola" '[ "$(bash "$ROOT/scripts/configura.sh" get METIS_MODULI)" = "telegram" ]'
check "chiave non valida rifiutata" '! bash "$ROOT/scripts/configura.sh" set "METIS_A;B" x 2>/dev/null'
check "file di configurazione con permessi 600" '[ "$(stat -f %Lp "$METIS_CONFIG")" = 600 ]'

echo "2. Struttura (vault esistente, non PARA)"
mkdir -p "$T/esistente/Clienti/Rossi" "$T/esistente/.obsidian"; echo x > "$T/esistente/Clienti/Rossi/a.md"
A=$(bash "$ROOT/scripts/installa-struttura.sh" albero "$T/esistente")
check "albero: cartelle e conteggio note" 'printf "%s" "$A" | grep -q "Rossi/ (1)"'
check "albero: riconosce il vault di Obsidian" 'printf "%s" "$A" | grep -q "vault di Obsidian"'
check "albero: non scrive niente" '[ "$(find "$T/esistente" -type f | wc -l | tr -d " ")" = 1 ]'
bash "$ROOT/scripts/installa-struttura.sh" crea >/dev/null
check "crea: cartelle dei ruoli e fonti dell'Inbox" '[ -d "$V/0 - Inbox/Clippings" ] && [ -d "$V/_Claude" ] && [ -d "$T/fonti" ]'
check "controlla: tutti i ruoli presenti" 'bash "$ROOT/scripts/installa-struttura.sh" controlla >/dev/null'

echo "3. Memoria"
bash "$ROOT/scripts/installa-modelli.sh" "$MOD" "Anna Rossi" >/dev/null 2>"$T/im.err"
check "modelli installati senza errori" '[ ! -s "$T/im.err" ] && [ -f "$V/_Claude/profilo-nucleo.md" ]'
check "cartella riservata presente in CLAUDE.md" 'grep -q "_Privato/" "$V/CLAUDE.md"'
check "modello di stato copiato" '[ -f "$V/_Claude/stati/_template-stato.md" ]'
check "banco di prova: cartella dei casi e protocollo" '[ -d "$V/_Claude/banco-skill/impegni/casi" ] && grep -q "Banco di prova delle skill" "$V/_Claude/banco-skill/README.md"'
check "modelli nuovi: decisioni, routine di fine sessione, protocollo" '[ -f "$V/_Claude/decisioni.md" ] && [ -f "$V/_Claude/routine-fine-sessione.md" ] && grep -q "Persone\|Contatti\|Risorse" "$V/_Claude/protocollo-propagazione.md" && ! grep -q "{{" "$V/_Claude/protocollo-propagazione.md"'
check "modelli delle note nella cartella dei template, Templater intatto" 'T_="$V/_Extras/_Templates"; [ -f "$T_/daily-template.md" ] && grep -q "<% tp.file.title %>" "$T_/daily-template.md" && grep -q "\[\[Journal\]\]" "$T_/weekly-template.md"'
mkdir -p "$T/schede"; printf -- '---\ncreated_at: 2026-10-02\n---\n# Prova {{non toccare}}\n' > "$T/schede/materia-prova.md.txt"
bash "$ROOT/scripts/installa-modelli.sh" "$MOD" "Anna Rossi" "$T/schede" >"$T/sc.out" 2>&1
check "schede di partenza copiate in dominio/, senza sostituzioni" 'grep -q "{{non toccare}}" "$V/_Claude/dominio/materia-prova.md" && grep -q "1 schede" "$T/sc.out"'
bash "$ROOT/scripts/installa-modelli.sh" "$MOD" "Anna Rossi" "$T/schede" >"$T/sc2.out" 2>&1
check "schede di partenza: rilancio senza sovrascrivere" 'grep -q "0 schede" "$T/sc2.out"'
V3="$T/vault-con-claude"; mkdir -p "$V3"; echo "# Le mie regole" > "$V3/CLAUDE.md"
printf 'METIS_VAULT=%s\nMETIS_MEMORY_DIR=%s/mem3\n' "$V3" "$T" > "$T/c3"
METIS_CONFIG="$T/c3" bash "$ROOT/scripts/installa-modelli.sh" "$MOD" "Anna Rossi" >/dev/null 2>&1
check "CLAUDE.md del cliente intatto" '[ "$(cat "$V3/CLAUDE.md")" = "# Le mie regole" ]'
check "nucleo di Metis in CLAUDE.local.md, segnaposto sostituiti" 'grep -q "vault di Anna Rossi" "$V3/CLAUDE.local.md" && ! grep -q "{{Nome}}" "$V3/CLAUDE.local.md"'
check "senza cartella riservata la sezione è tolta" '! grep -q "## Cartella riservata" "$V3/CLAUDE.local.md"'

echo "4. Permessi"
mkdir -p "$V/.claude"; echo '{"permissions":{"allow":["Bash(npm test)"]},"model":"sonnet"}' > "$V/.claude/settings.json"
bash "$ROOT/scripts/installa-permessi.sh" >/dev/null
bash "$ROOT/scripts/installa-permessi.sh" >/dev/null
P="$V/.claude/settings.json"
check "regola del cliente conservata" 'grep -q "Bash(npm test)" "$P" && grep -q "\"model\": \"sonnet\"" "$P"'
check "copia del file del cliente fatta una volta" '[ -f "$P.prima-di-metis" ] && ! grep -q defaultMode "$P.prima-di-metis"'
check "nessuna regola doppia dopo due esecuzioni" '[ "$(python3 -c "import json;a=json.load(open(\"$P\"))[\"permissions\"][\"allow\"];print(len(a)-len(set(a)))")" = 0 ]'
check "lettura del plugin consentita" 'grep -q "Read(~/.claude/plugins/\*\*)" "$P"'
check "cartella riservata negata in lettura" 'grep -q "_Privato/\*\*)" "$P"'
check "sessioni senza richieste di permesso (decisione del 6/10)" 'python3 -c "import json,sys; sys.exit(0 if json.load(open(\"$P\"))[\"permissions\"][\"defaultMode\"]==\"bypassPermissions\" else 1)"'
check "divieti sulle cartelle delle credenziali" 'grep -q "Read(~/.ssh/\*\*)" "$P" && grep -q "Library/Keychains" "$P"'
R_=$(dirname "$METIS_CONFIG")/permessi-routine.json
check "routine sempre in acceptEdits" 'grep -q "\"defaultMode\": \"acceptEdits\"" "$R_"'
check "copia per le routine scritta" 'python3 -m json.tool "$T/permessi-routine.json" >/dev/null'

echo "5. Guardia"
g() { evento "$1" "$2" "$3" | bash "$ROOT/hooks/guardia.sh"; }
check "riservata: Read bloccato" 'g Read "$V" "{\"file_path\":\"$V/_Privato/diario.md\"}" | grep -q "\"deny\""'
check "riservata: Grep sul percorso relativo bloccato" 'g Grep "$V" "{\"pattern\":\"x\",\"path\":\"_Privato/\"}" | grep -q "\"deny\""'
check "rm -rf: conferma" 'g Bash "$V" "{\"command\":\"rm -rf 1\\\\ -\\\\ Progetti/vecchio\"}" | grep -q "\"ask\""'
check "rm -r in una catena: conferma" 'g Bash "$V" "{\"command\":\"cd x && rm -r y\"}" | grep -q "\"ask\""'
check "rm semplice: passa" '[ -z "$(g Bash "$V" "{\"command\":\"rm file.tmp\"}")" ]'
check "obsidian delete: conferma" 'g Bash "$V" "{\"command\":\"obsidian delete file=Nota\"}" | grep -q "\"ask\""'
check "git push: conferma" 'g Bash "$V" "{\"command\":\"git push origin main\"}" | grep -q "\"ask\""'
check "sudo: bloccato" 'g Bash "$V" "{\"command\":\"sudo ls\"}" | grep -q "\"deny\""'
check "invio di posta: conferma" 'g mcp__claude_ai_Gmail__send_message "$V" "{\"to\":\"a@b.it\"}" | grep -q "\"ask\""'
check "risposta in un thread: conferma" 'g mcp__claude_ai_Gmail__reply "$V" "{}" | grep -q "\"ask\""'
check "bozza di posta: passa" '[ -z "$(g mcp__claude_ai_Gmail__create_draft "$V" "{}")" ]'
check "evento con invitati: conferma" 'g mcp__claude_ai_Google_Calendar__create_event "$V" "{\"summary\":\"x\",\"attendees\":[\"a@b.it\"]}" | grep -q "\"ask\""'
VUOTO="{\"summary\":\"x\",\"attendees\":[]}"
check "evento senza invitati: passa" '[ -z "$(g mcp__claude_ai_Google_Calendar__create_event "$V" "$VUOTO")" ] && [ -z "$(g mcp__claude_ai_Google_Calendar__create_event "$V" "{\"summary\":\"x\"}")" ]'
check "invitati aggiunti a un evento: conferma" 'g mcp__google-workspace-mcp__update_event "$V" "{\"attendees\":[{\"email\":\"a@b.it\"}]}" | grep -q "\"ask\""'
check "risposta a un invito: conferma" 'g mcp__claude_ai_Google_Calendar__respond_to_event "$V" "{}" | grep -q "\"ask\""'
check "condivisione di un file: conferma" 'g mcp__claude_ai_Google_Drive__share_file "$V" "{}" | grep -q "\"ask\""'
check "condivisione multipla: conferma" 'g mcp__google-workspace-mcp__batch_share "$V" "{}" | grep -q "\"ask\""'
check "lettura dei permessi di condivisione: passa" '[ -z "$(g mcp__google-workspace-mcp__get_sharing "$V" "{}")" ]'
APP=mcp__0a1b2c3d-0000-4000-8000-000000000000   # nome di un connettore nell'app di Claude (identificativo inventato)
check "app: invio di posta con il nome dell'app: conferma" 'g ${APP}__send_message "$V" "{\"to\":\"a@b.it\"}" | grep -q "\"ask\""'
check "app: bozza con il nome dell'app: passa" '[ -z "$(g ${APP}__create_draft "$V" "{}")" ]'
check "app: condivisione con il nome dell'app: conferma" 'g ${APP}__share_file "$V" "{}" | grep -q "\"ask\""'
check "lettura normale: passa" '[ -z "$(g Read "$V" "{\"file_path\":\"$V/CLAUDE.md\"}")" ]'
check "fuori dal vault: nessun intervento" '[ -z "$(g Bash "$T" "{\"command\":\"rm -rf x\"}")" ]'

echo "5a. Guardia senza python3 (fallimento chiuso)"
mkdir -p "$T/senzapy"; printf '#!/bin/sh\nexit 1\n' > "$T/senzapy/python3"; chmod +x "$T/senzapy/python3"   # come il rimando di macOS
gs() { evento "$1" "$2" "$3" | PATH="$T/senzapy:$PATH" bash "$ROOT/hooks/guardia.sh"; }
check "senza python3: invio di posta: conferma" 'gs mcp__claude_ai_Gmail__send_message "$V" "{\"to\":\"a@b.it\"}" | grep -q "\"ask\""'
check "senza python3: condivisione con il nome dell'app: conferma" 'gs ${APP}__share_file "$V" "{}" | grep -q "\"ask\""'
check "senza python3: shell: conferma" 'gs Bash "$V" "{\"command\":\"ls\"}" | grep -q "\"ask\""'
check "senza python3: cartella riservata: bloccata" 'gs Read "$V" "{\"file_path\":\"$V/_Privato/diario.md\"}" | grep -q "\"deny\""'
check "senza python3: risposta in JSON valido" 'gs Bash "$V" "{\"command\":\"ls\"}" | python3 -m json.tool >/dev/null'
check "senza python3: lettura normale: passa" '[ -z "$(gs Read "$V" "{\"file_path\":\"$V/CLAUDE.md\"}")" ]'
check "senza python3: fuori dal vault: nessun intervento" '[ -z "$(gs Bash "$T" "{\"command\":\"rm -rf x\"}")" ]'

echo "5b. Guardia: ricerche nella shell e cartella riservata"
r() { g Bash "$V" "$(python3 -c 'import json,sys; print(json.dumps({"command": sys.argv[1]}))' "$1")"; }
check "grep -r su tutto il vault: bloccato" 'r "grep -r segreto ." | grep -q "\"deny\""'
check "grep -rn senza percorso: bloccato" 'r "grep -rn segreto" | grep -q "\"deny\""'
check "grep -r con il percorso assoluto del vault: bloccato" 'r "grep -r segreto \"$V\"" | grep -q "\"deny\""'
check "find dalla radice: bloccato" 'r "find . -name *.md" | grep -q "\"deny\""'
check "rg senza percorso: bloccato" 'r "rg segreto" | grep -q "\"deny\""'
check "grep -r in una sottocartella: ammesso" '[ -z "$(r "grep -rn segreto \"1 - Progetti/\"")" ]'
check "grep -r con --exclude-dir della cartella: ammesso" '[ -z "$(r "grep -r --exclude-dir=_Privato segreto .")" ]'
check "find con -not -path della cartella: ammesso" '[ -z "$(r "find . -not -path *_Privato* -name x.md")" ]'
check "rg con -g !cartella: ammesso" '[ -z "$(r "rg -g !_Privato segreto")" ]'
check "grep non ricorsivo in una pipe: ammesso" '[ -z "$(r "cat CLAUDE.md | grep Metis")" ]'
check "find su un'altra cartella del disco: ammesso" '[ -z "$(r "find /tmp -name x")" ]'
check "find -L su un'altra cartella del disco: ammesso (falso allarme del 6/10)" '[ -z "$(r "find -L /tmp -maxdepth 2 -type f")" ]'
check "find -L dalla radice del vault: bloccato" 'r "find -L . -type f" | grep -q "\"deny\""'
check "find avvolto in con-timeout dalla radice: bloccato" 'r "bash /x/scripts/con-timeout.sh 90 find . -name x" | grep -q "\"deny\""'
check "grep -r avvolto in con-timeout e env: bloccato" 'r "env LC_ALL=C bash /x/scripts/con-timeout.sh 30 grep -r segreto ." | grep -q "\"deny\""'
check "find avvolto in con-timeout su un'altra cartella: ammesso" '[ -z "$(r "bash /x/scripts/con-timeout.sh 90 find -L /tmp -type f")" ]'

echo "6. Validazione delle scritture"
w() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" | bash "$ROOT/hooks/valida-scrittura.sh" 2>"$T/w.err"; echo $?; }
printf 'testo\n' > "$V/1 - Progetti/nuda.md"
printf -- '---\ncreated_at: 2026-09-29\ntags:\n- appunti\nup:\n- x\n---\n' > "$V/1 - Progetti/tag.md"
printf -- '---\ncreated_at: 2026-09-29\ntags:\n- tipo/appunti\nup:\n- x\n---\n' > "$V/1 - Progetti/buona.md"
check "nota senza frontmatter: avviso a Claude (codice 2)" '[ "$(w "$V/1 - Progetti/nuda.md")" = 2 ] && grep -q "Frontmatter mancante" "$T/w.err"'
check "tag senza prefisso: avviso" '[ "$(w "$V/1 - Progetti/tag.md")" = 2 ] && grep -q "Tag senza prefisso: appunti" "$T/w.err"'
check "nota a norma: nessun avviso" '[ "$(w "$V/1 - Progetti/buona.md")" = 0 ]'
check "CLAUDE.md: ignorato" '[ "$(w "$V/CLAUDE.md")" = 0 ]'
check "file nella cartella di Claude: ignorato" '[ "$(w "$V/_Claude/correzioni.md")" = 0 ]'
mkdir -p "$V/.claude/skills/prova"; printf 'testo\n' > "$V/.claude/skills/prova/SKILL.md"
check "skill del progetto in .claude: ignorata" '[ "$(w "$V/.claude/skills/prova/SKILL.md")" = 0 ]'

echo "6b. Sola lettura, Inbox senza sottocartelle, tetto con CLAUDE.local.md"
bash "$ROOT/scripts/configura.sh" set METIS_SOLA_LETTURA "Giurisprudenza|Studio/Modelli" >/dev/null
bash "$ROOT/scripts/installa-permessi.sh" >/dev/null
check "cartelle in sola lettura: scrittura negata" 'grep -q "Edit(/$V/Giurisprudenza/\*\*)" "$P" && grep -q "Write(/$V/Studio/Modelli/\*\*)" "$P"'
check "regola d'invio Telegram assente senza il modulo" '! grep -q "metis_telegram.py invia" "$P"'
printf 'METIS_VAULT=%s\nMETIS_INBOX_FONTI=\nMETIS_MEMORY_DIR=%s/m4\n' "$T/v4" "$T" > "$T/c4"; mkdir -p "$T/v4"
METIS_CONFIG="$T/c4" bash "$ROOT/scripts/installa-struttura.sh" crea >/dev/null
check "Inbox senza sottocartelle quando METIS_INBOX_FONTI è vuoto" '[ -d "$T/v4/0 - Inbox" ] && [ -z "$(ls "$T/v4/0 - Inbox")" ]'
M3=$(METIS_CONFIG="$T/c3" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; metis_misura "CLAUDE.md del vault"' "$ROOT")
check "tetto di CLAUDE.md: misura anche CLAUDE.local.md" '[ "$M3" = "$(cat "$V3/CLAUDE.md" "$V3/CLAUDE.local.md" | wc -m | tr -d " ")" ]'

echo "7. Compattazione"
printf '{"cwd":"%s","trigger":"auto"}' "$V" | bash "$ROOT/hooks/pre-compact.sh"
check "traccia salvata" 'grep -q "Note toccate nelle ultime tre ore" "$V/_Claude/cache/pre-compact.md"'
H=$(printf '{"cwd":"%s","source":"compact"}' "$V" | bash "$ROOT/hooks/session-orient.sh")
check "ripresa: traccia rimessa nel contesto" 'printf "%s" "$H" | grep -q "RIPRESA DOPO LA COMPATTAZIONE"'
H=$(printf '{"cwd":"%s","source":"startup"}' "$V" | bash "$ROOT/hooks/session-orient.sh")
check "avvio normale: nessuna traccia" '! printf "%s" "$H" | grep -q "RIPRESA DOPO"'

echo "7b. Modulo markitdown"
echo '{"mcpServers":{"mio":{"command":"x"}}}' > "$V/.mcp.json"
bash "$ROOT/scripts/moduli/markitdown.sh" installa >/dev/null; bash "$ROOT/scripts/moduli/markitdown.sh" installa >/dev/null
check "server dichiarato e server del cliente conservato" 'python3 -c "import json,sys;d=json.load(open(\"$V/.mcp.json\"))[\"mcpServers\"];sys.exit(0 if set(d)=={\"mio\",\"markitdown\"} else 1)"'
check "strumento consentito una volta sola" '[ "$(grep -c convert_to_markdown "$V/.claude/settings.json")" = 1 ]'
check "modulo registrato nella configurazione" 'bash "$ROOT/scripts/configura.sh" get METIS_MODULI | grep -qw markitdown'

echo "7b. Sessioni chiuse senza «chiudi sessione»"
PR="$T/progetti"; export METIS_CLAUDE_PROJECTS="$PR"
PD="$PR/$(cd "$V" && pwd -P | sed 's/[^A-Za-z0-9]/-/g')"; mkdir -p "$PD"
IERI=$(date -v-1d +%F); VECCHIO=$(date -v-10d +%F)
printf '%s\n' '{"type":"user","timestamp":"'"$IERI"'T09:00:00Z","message":{"content":"prepara la nota sul bando"}}' '{"type":"assistant","timestamp":"'"$IERI"'T09:00:05Z","message":{"content":[{"type":"text","text":"Nota scritta in Progetti."},{"type":"tool_use","name":"Write"}]}}' '{"type":"user","timestamp":"'"$IERI"'T09:01:00Z","message":{"content":"<system-reminder>interno</system-reminder>"}}' > "$PD/aaa-ieri.jsonl"
touch -t "$(date -v-1d +%Y%m%d)1200" "$PD/aaa-ieri.jsonl"
cp "$PD/aaa-ieri.jsonl" "$PD/bbb-vecchia.jsonl"; touch -t "$(date -v-10d +%Y%m%d)1200" "$PD/bbb-vecchia.jsonl"
cp "$PD/aaa-ieri.jsonl" "$PD/ccc-corrente.jsonl"; touch -t "$(date -v-1d +%Y%m%d)1300" "$PD/ccc-corrente.jsonl"
H=$(printf '{"cwd":"%s","source":"startup","session_id":"ccc-corrente"}' "$V" | bash "$ROOT/hooks/session-orient.sh")
check "sessione di ieri senza log: segnalata con il comando per ricostruirla" 'printf "%s" "$H" | grep -q "Sessione del $IERI chiusa senza «chiudi sessione»" && printf "%s" "$H" | grep -q "aaa-ieri.jsonl"'
check "sessione corrente esclusa" '! printf "%s" "$H" | grep -q "ccc-corrente.jsonl"'
check "sessione più vecchia di sette giorni ignorata" '! printf "%s" "$H" | grep -q "bbb-vecchia"'
echo "log" > "$V/_Claude/sessioni/$IERI.md"
H=$(printf '{"cwd":"%s","source":"startup","session_id":"ccc-corrente"}' "$V" | bash "$ROOT/hooks/session-orient.sh")
check "con il log del giorno: nessuna segnalazione" '! printf "%s" "$H" | grep -q "chiusa senza"'
rm "$V/_Claude/sessioni/$IERI.md"
TR=$(python3 "$ROOT/scripts/trascrizione.py" "$PD/aaa-ieri.jsonl" --giorno "$IERI")
check "trascrizione leggibile: utente, Claude e strumenti, senza avvisi di sistema" 'printf "%s" "$TR" | grep -q "Utente: prepara la nota sul bando" && printf "%s" "$TR" | grep -q "Claude: Nota scritta" && printf "%s" "$TR" | grep -q "strumento: Write" && ! printf "%s" "$TR" | grep -q "interno"'
check "trascrizione filtrata per giorno" '[ -z "$(python3 "$ROOT/scripts/trascrizione.py" "$PD/aaa-ieri.jsonl" --giorno "$VECCHIO")" ]'
check "permesso per lo script di ricostruzione" 'grep -q "trascrizione.py" "$P"'
unset METIS_CLAUDE_PROJECTS

echo "8. Dotazione"
check "verifica-dotazione: sintassi e modulo sconosciuto segnalato" '! bash "$ROOT/scripts/verifica-dotazione.sh" inesistente >/dev/null'

echo "9. Intestazioni di skill, comandi e agenti"
# L'app di Claude rifiuta il plugin se un'intestazione contiene parentesi angolari («description cannot contain XML tags»).
ANGOLARI=$(python3 - "$ROOT" <<'PY2'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
for f in sorted(p for d in ("skills", "commands", "agents") for p in (root / d).rglob("*.md")):
    t = f.read_text(encoding="utf-8")
    if not t.startswith("---\n"): continue
    for riga in t.split("\n---", 1)[0].splitlines()[1:]:
        r = re.sub(r":\s*>[-+]?\s*$", ":", riga)   # «description: >» è un blocco YAML, non una parentesi
        if "<" in r or ">" in r: print(f"{f.relative_to(root)}: {riga[:80]}")
PY2
)
[ -n "$ANGOLARI" ] && printf '%s\n' "$ANGOLARI" | sed 's/^/     /'
check "nessuna parentesi angolare nelle intestazioni (l'app rifiuterebbe il plugin)" '[ -z "$ANGOLARI" ]'

echo "10. Una cartella per lavoro: skill allineate alla regola di CLAUDE.md"
check "inbox-processor: un file ricevuto va nella _IN del lavoro, mai nella radice" 'grep "file ricevuto" "$ROOT/skills/inbox-processor/SKILL.md" | grep -q "_IN/" && grep "file ricevuto" "$ROOT/skills/inbox-processor/SKILL.md" | grep -q "nella radice della cartella fonti non va"'
check "installa: le cartelle dei lavori nascono al primo lavoro" 'grep -q "nascono al primo lavoro" "$ROOT/skills/installa/references/blocco-0-dotazione.md"'
check "archiviazione: la cartella su disco resta intera dov'è" 'grep -q "la cartella su disco resta dov.è" "$ROOT/skills/archiviazione/SKILL.md"'
check "Word da consegnare: nella _OUT del lavoro" 'grep -q "_OUT/YYYY-MM-DD" "$ROOT/skills/installa/references/moduli.md"'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
