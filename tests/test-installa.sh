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
check "niente skip-permissions né bypass" '! grep -qi "bypass\|skip" "$P"'
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
check "lettura normale: passa" '[ -z "$(g Read "$V" "{\"file_path\":\"$V/CLAUDE.md\"}")" ]'
check "fuori dal vault: nessun intervento" '[ -z "$(g Bash "$T" "{\"command\":\"rm -rf x\"}")" ]'

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

echo "7. Compattazione"
printf '{"cwd":"%s","trigger":"auto"}' "$V" | bash "$ROOT/hooks/pre-compact.sh"
check "traccia salvata" 'grep -q "Note toccate nelle ultime tre ore" "$V/_Claude/cache/pre-compact.md"'
H=$(printf '{"cwd":"%s","source":"compact"}' "$V" | bash "$ROOT/hooks/session-orient.sh")
check "ripresa: traccia rimessa nel contesto" 'printf "%s" "$H" | grep -q "RIPRESA DOPO LA COMPATTAZIONE"'
H=$(printf '{"cwd":"%s","source":"startup"}' "$V" | bash "$ROOT/hooks/session-orient.sh")
check "avvio normale: nessuna traccia" '! printf "%s" "$H" | grep -q "RIPRESA DOPO"'

echo "8. Dotazione"
check "verifica-dotazione: sintassi e modulo sconosciuto segnalato" '! bash "$ROOT/scripts/verifica-dotazione.sh" inesistente >/dev/null'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
