#!/bin/bash
# test-aggiorna.sh — prova dell'aggiornamento di un'installazione esistente (aggiorna.sh) e del segnale all'avvio.
# Costruisce in una cartella temporanea un vault installato con Metis 0.3.2 (gli script di quella versione, estratti da
# git), con routine e Telegram simulati e contenuto «del cliente»; poi mette la copia attuale dove la metterebbe l'app di
# Claude e la aggiorna da lì. Non tocca nessun vault, configurazione o LaunchAgent reale: niente viene caricato in launchd.
# Uso: bash tests/test-aggiorna.sh

set -u
export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(cd "$(mktemp -d)" && pwd -P)"; trap '[ -n "${TIENI:-}" ] && echo "cartella della prova lasciata: $T" || rm -rf "$T"' EXIT   # TIENI=1 per guardarci dentro
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
ko()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else ko "$1"; fi; }

VECCHIA_REV=63ab3e8   # Versione 0.3.2
git -C "$ROOT" cat-file -e "$VECCHIA_REV^{commit}" 2>/dev/null || { echo "commit $VECCHIA_REV (0.3.2) non trovato: serve il repository completo"; exit 2; }

# --- 1. Le due copie: la vecchia, come la strada senza GitHub (~/Metis), e la nuova, nella cartella dell'app --------------
OLD="$T/casa/Metis"; NEW="$T/casa/Library/Application Support/Claude/local-agent-mode-sessions/a/b/cowork_plugins/marketplaces/local-desktop-app-uploads/metis"
mkdir -p "$OLD" "$NEW"
git -C "$ROOT" archive "$VECCHIA_REV" | tar -x -C "$OLD"
( cd "$ROOT" && git ls-files | tar -cf - -T - ) | tar -x -C "$NEW"   # i file del repository come sono adesso
cp "$ROOT/scripts/aggiorna.sh" "$NEW/scripts/aggiorna.sh"; cp "$ROOT/hooks/session-orient.sh" "$NEW/hooks/session-orient.sh"  # anche se non ancora in git
check "copia vecchia 0.3.2" 'grep -q "\"0.3.2\"" "$OLD/.claude-plugin/plugin.json"'

# --- 2. Installazione fatta con la 0.3.2 ---------------------------------------------------------------------------------
export HOME="$T/casa" METIS_CONFIG="$T/casa/.config/metis/config" METIS_LAUNCHAGENTS="$T/casa/Library/LaunchAgents" METIS_SENZA_CARICARE=1
export CLAUDE_CONFIG_DIR="$T/casa/.claude"
export METIS_AGGIORNA_PROVA=1   # la prova vive in una cartella temporanea, che aggiorna.sh altrimenti rifiuta
unset METIS_ROOT CLAUDE_PLUGIN_ROOT
mkdir -p "$(dirname "$METIS_CONFIG")" "$T/vault"
cat > "$METIS_CONFIG" <<EOF
METIS_VAULT=$T/vault
METIS_FONTI=$T/casa/Documents/Fonti
METIS_LOG_DIR=$T/log
METIS_LABEL=com.metis.prova
METIS_MEMORY_DIR=$T/mem
METIS_JOBS=daily-digest inbox-processor
METIS_MODULI=routine telegram
EOF
bash "$OLD/scripts/installa-struttura.sh" crea >/dev/null
bash "$OLD/scripts/installa-modelli.sh" "$OLD/templates/memoria" "Persona Prova" >/dev/null
bash "$OLD/scripts/installa-permessi.sh" >/dev/null
METIS_ROOT="$OLD" bash "$OLD/scripts/moduli/routine.sh" installa --senza-caricare >/dev/null
METIS_ROOT="$OLD" bash "$OLD/scripts/lib/launchd.sh" genera telegram sempre /usr/bin/python3 "$OLD/scripts/telegram/metis_telegram.py" ascolta >/dev/null
for F in "$T/vault/.claude/settings.json" "$T/casa/.config/metis/permessi-routine.json"; do
  python3 "$OLD/scripts/lib/impostazioni.py" lista "$F" permissions.allow "Bash(python3 $OLD/scripts/telegram/metis_telegram.py invia *)" >/dev/null
done
# Una regola del cliente con un percorso suo, che non va toccata.
python3 "$OLD/scripts/lib/impostazioni.py" lista "$T/vault/.claude/settings.json" permissions.allow "Bash(python3 $T/casa/progetti/scripts/mio.py *)" >/dev/null
# La copia da terminale registrata come la registra Claude Code (catalogo da cartella: si legge sul posto).
mkdir -p "$CLAUDE_CONFIG_DIR/plugins"
printf '{"version":2,"plugins":{"metis@metis":[{"scope":"user","installPath":"%s","version":"0.3.2"}]}}\n' "$OLD" > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"

CL="$T/vault/_Claude"
check "vault 0.3.2: profilo, regole e LaunchAgent puntano alla copia vecchia" '[ -f "$CL/profilo-nucleo.md" ] && grep -q "$OLD/scripts" "$T/vault/.claude/settings.json" && grep -q "$OLD/scripts/doctor.sh" "$METIS_LAUNCHAGENTS/com.metis.prova.doctor.plist"'

# Contenuto del cliente: profilo compilato, uno stato, una correzione, una scheda. Se ne prende l'impronta.
printf '\n## Chi sono\nSono una persona di prova, consulente.\n' >> "$CL/profilo-nucleo.md"
sed -i '' 's/<!-- AVVIO[^>]*-->//' "$CL/profilo-nucleo.md" 2>/dev/null
mkdir -p "$CL/stati" "$CL/dominio"
printf -- '---\nstatus: attivo\n---\n# Lavoro di prova\n## Impegni\n- [ ] consegnare la nota | 2026-11-20 | palla:me\n' > "$CL/stati/lavoro-prova.md"
printf '\n## 2026-10-10 — una correzione\nregola di prova\n' >> "$CL/correzioni.md"
printf -- '---\ntags: [tipo/appunti]\n---\n# Scheda di prova\n' > "$CL/dominio/materia.md"
mkdir -p "$T/vault/1 - Progetti/Lavoro"; printf -- '---\ncreated_at: 2026-10-10\n---\nnota\n' > "$T/vault/1 - Progetti/Lavoro/nota.md"
impronta() { ( cd "$T/vault" && find . -name '*.md' -not -path './_Claude/doctor.md' -not -path './_Claude/mappa-*' -not -path './_Claude/cache/*' -print0 | sort -z | xargs -0 shasum ) | shasum | cut -c1-16; }
PRIMA="$(impronta)"

# --- 3. Segnale all'avvio, dalla copia nuova ----------------------------------------------------------------------------
ORIENT() { printf '{"cwd":"%s"}' "$1" | CLAUDE_PLUGIN_ROOT="$NEW" bash "$NEW/hooks/session-orient.sh" 2>/dev/null; }
check "avvio: segnala l'aggiornamento da fare, con la versione vecchia" 'ORIENT "$T/vault" | grep -q "Aggiornamento dell.installazione da fare.*0.3.2"'
check "avvio: nessuna proposta di onboarding (profilo già compilato)" '! ORIENT "$T/vault" | grep -q "Avvio da fare"'
check "avvio da una cartella che contiene il vault: indica la cartella giusta" 'mkdir -p "$T/casa/Documents" && ORIENT "$T" | grep -q "cartella del vault: $T/vault"'
check "avvio da un progetto qualsiasi: niente" '[ -z "$(ORIENT "$T/casa/progetti")" ]'

# --- 4. aggiorna.sh controlla --------------------------------------------------------------------------------------------
A=(bash "$NEW/scripts/aggiorna.sh")
OUT="$("${A[@]}" controlla)"; RC=$?
check "controlla: uscita 1 (c'è da fare) e niente scritto" '[ "$RC" -eq 1 ] && [ ! -d "$T/casa/.config/metis/backup" ]'
check "controlla: riconosce la copia nell'app e la vecchia" 'printf "%s" "$OUT" | grep -q "caricata nell.app" && printf "%s" "$OUT" | grep -q "Da riallineare: puntano a $OLD (versione 0.3.2)"'
check "controlla: segnala la copia da terminale ancora installata" 'printf "%s" "$OUT" | grep -q "Copia da terminale ancora installata: metis@metis"'
check "controlla: la regola del cliente non è presa per una copia di Metis" '! printf "%s" "$OUT" | grep -q "progetti"'

# --- 5. aggiorna.sh esegui -----------------------------------------------------------------------------------------------
OUT="$("${A[@]}" esegui 2>&1)"; RC=$?
echo "$OUT" | sed 's/^/      /' | head -30
check "esegui: riuscito" '[ "$RC" -eq 0 ]'
B="$(ls -d "$T/casa/.config/metis/backup"/aggiorna-* 2>/dev/null | head -1)"
check "copia di sicurezza: configurazione, regole, LaunchAgent, cartella di Claude, istruzioni" '[ -f "$B/LEGGIMI.txt" ] && [ -f "$B/cartella-di-claude.tgz" ] && ls "$B/file" | grep -q "config$" && ls "$B/file" | grep -q "settings.json$" && ls "$B/file" | grep -q "doctor.plist$"'
check "regole del vault: nessun percorso della copia vecchia" '! grep -q "$OLD/" "$T/vault/.claude/settings.json"'
check "regole del vault: la regola di Telegram con il percorso nuovo" 'grep -qF "Bash(python3 $NEW/scripts/telegram/metis_telegram.py invia *)" "$T/vault/.claude/settings.json"'
check "regole del vault: la regola del cliente intatta" 'grep -qF "Bash(python3 $T/casa/progetti/scripts/mio.py *)" "$T/vault/.claude/settings.json"'
check "regole del vault: le voci nuove della versione (trascrizione.py)" 'grep -qF "$NEW/scripts/trascrizione.py" "$T/vault/.claude/settings.json"'
check "regole con il percorso fra virgolette (la cartella dell'app ha uno spazio)" 'grep -qF "Bash(bash \\\"$NEW/scripts/doctor.sh\\\")" "$T/vault/.claude/settings.json" && grep -qF "Bash(python3 \\\"$NEW/scripts/telegram/metis_telegram.py\\\" invia *)" "$T/vault/.claude/settings.json"'
R="$T/casa/.config/metis/permessi-routine.json"
check "regole dei giri: percorso nuovo, Telegram rimesso, niente di vecchio" 'grep -qF "$NEW/scripts/doctor.sh" "$R" && grep -qF "$NEW/scripts/telegram/metis_telegram.py invia" "$R" && ! grep -q "$OLD/" "$R"'
check "LaunchAgent: tutti con il percorso nuovo, stessi orari" '! grep -l "$OLD/" "$METIS_LAUNCHAGENTS"/com.metis.prova.*.plist && grep -q "$NEW/scripts/metis-agent.sh" "$METIS_LAUNCHAGENTS/com.metis.prova.daily-digest.plist" && /usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:0:Hour" "$METIS_LAUNCHAGENTS/com.metis.prova.daily-digest.plist" | grep -q "^7$"'
check "LaunchAgent di Telegram riallineato" 'grep -q "$NEW/scripts/telegram/metis_telegram.py" "$METIS_LAUNCHAGENTS/com.metis.prova.telegram.plist"'
check "contenuto del cliente identico (profilo, stati, correzioni, schede, note, CLAUDE.md)" '[ "$(impronta)" = "$PRIMA" ]'
check "configurazione invariata" 'cmp -s "$METIS_CONFIG" "$B/file/$(ls "$B/file" | grep "config$")"'
check "doctor eseguito dalla copia nuova" '[ -f "$CL/doctor.md" ] && printf "%s" "$OUT" | grep -q "^Doctor:"'
check "esegui ricorda la copia da terminale da togliere" 'printf "%s" "$OUT" | grep -q "Resta da togliere la copia da terminale metis@metis"'
check "avvio dopo l'aggiornamento: nessun segnale d'aggiornamento" '! ORIENT "$T/vault" | grep -q "Aggiornamento dell.installazione"'

# --- 6. Si ripete senza danni --------------------------------------------------------------------------------------------
H1="$(shasum "$T/vault/.claude/settings.json" "$R" "$METIS_LAUNCHAGENTS"/com.metis.prova.*.plist | cut -c1-40)"
"${A[@]}" esegui >/dev/null 2>&1; RC=$?
H2="$(shasum "$T/vault/.claude/settings.json" "$R" "$METIS_LAUNCHAGENTS"/com.metis.prova.*.plist | cut -c1-40)"
check "secondo esegui: riuscito e niente cambiato" '[ "$RC" -eq 0 ] && [ "$H1" = "$H2" ]'
check "controlla dopo: resta solo la copia da terminale" '"${A[@]}" controlla | grep -q "Regole e automazioni puntano già a questa copia"'

# --- 7. togli-terminale, con un claude finto ------------------------------------------------------------------------------
printf '#!/bin/bash\necho "$*" >> "%s/claude.log"\n' "$T" > "$T/claude-finto"; chmod +x "$T/claude-finto"
METIS_ROOT="$OLD" METIS_CLAUDE="$T/claude-finto" bash "$NEW/scripts/aggiorna.sh" togli-terminale >/dev/null 2>&1; RC=$?
check "togli-terminale lanciato dalla copia da terminale stessa: rifiutato" '[ "$RC" -eq 1 ] && [ ! -f "$T/claude.log" ]'
OUT="$(METIS_CLAUDE="$T/claude-finto" "${A[@]}" togli-terminale 2>&1)"; RC=$?
check "togli-terminale: plugin e catalogo «metis» tolti" '[ "$RC" -eq 0 ] && grep -qx "plugin uninstall metis@metis" "$T/claude.log" && grep -qx "plugin marketplace remove metis" "$T/claude.log"'
check "togli-terminale: dice che ~/Metis si può cancellare, senza cancellarla" 'printf "%s" "$OUT" | grep -q "non serve più" && [ -d "$OLD" ]'

METIS_AGGIORNA_PROVA= "${A[@]}" esegui >/dev/null 2>&1; RC=$?
check "esegui da una copia in una cartella temporanea: rifiutato" '[ "$RC" -eq 1 ]'

# --- 8. Senza installazione ----------------------------------------------------------------------------------------------
METIS_CONFIG="$T/nessuna/config" "${A[@]}" controlla >/dev/null 2>&1; RC=$?
check "senza configurazione: uscita 2" '[ "$RC" -eq 2 ]'

echo ""
echo "aggiorna: $PASS ok, $FAIL falliti"
[ "$FAIL" -eq 0 ]
