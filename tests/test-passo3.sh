#!/bin/bash
# test-passo3.sh — prova di hook di avvio e doctor su vault di prova creati in una cartella temporanea.
# Non tocca nessun vault reale: tutto vive sotto una mktemp -d, cancellata alla fine.
#
# Uso: bash tests/test-passo3.sh <cartella dei modelli>
#   <cartella dei modelli> contiene CLAUDE.md.txt, _Claude/*.md.txt, memory/MEMORY.md.txt
#   (fino alla migrazione del 16/10 i modelli stanno nel kit, fuori da questo repository).

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="${1:?uso: bash tests/test-passo3.sh <cartella dei modelli>}"
[ -f "$MOD/CLAUDE.md.txt" ] || { echo "modelli non trovati in $MOD"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
ko()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

# installa <vault> <memoria> <ruolo claude> <ruolo inbox> → copia i modelli e sostituisce i segnaposto d'installazione
installa() {
  local V="$1" M="$2" RC="$3" RI="$4" f b
  mkdir -p "$V/$RC"/{stati/archivio,dominio,sessioni/archivio,archivio} "$V/$RI/Clippings" "$M/archivio"
  for f in "$MOD"/_Claude/*.md.txt; do b=$(basename "$f" .txt); cp "$f" "$V/$RC/$b"; done
  cp "$MOD/CLAUDE.md.txt" "$V/CLAUDE.md"; cp "$MOD/memory/MEMORY.md.txt" "$M/MEMORY.md"
  find "$V" "$M" -type f -name "*.md" -exec perl -pi -e \
    "s/\{\{PRODOTTO\}\}/Metis/g; s/\{\{Nome\}\}/Anna Rossi/g; s#\{\{VAULT\}\}#$V#g; s#\{\{FONTI\}\}#$T/fonti#g; s/\{\{YYYY-MM-DD\}\}/$(date +%F)/g;
     s#\{\{RUOLO_CLAUDE\}\}#$RC#g; s#\{\{RUOLO_INBOX\}\}#$RI#g; s#\{\{RUOLO_PROGETTI\}\}#1 - Progetti#g; s#\{\{RUOLO_AREE\}\}#2 - Aree#g;
     s#\{\{RUOLO_RISORSE\}\}#3 - Risorse#g; s#\{\{RUOLO_PERSONE\}\}#3 - Risorse/Persone#g; s#\{\{RUOLO_ARCHIVIO\}\}#4 - Archivio#g;
     s#\{\{RUOLO_JOURNAL\}\}#Journal#g; s#\{\{RUOLO_TEMPLATE\}\}#_Extras/_Templates#g; s#\{\{RUOLO_RISERVATA\}\}#_Privato#g; s#\{\{COMANDO_DOCTOR\}\}#bash $ROOT/scripts/doctor.sh#g" {} +
  # nessun segnaposto d'installazione deve restare: solo quelli COMPILARE, che chiude l'onboarding
  ! grep -rhoE "\{\{[^}]*\}\}" "$V" "$M" | grep -qv "COMPILARE"
}

config() {  # config <file> <vault> <memoria> [righe in più]
  { echo "METIS_VAULT=$2"; echo "METIS_MEMORY_DIR=$3"; echo "METIS_JOBS="; echo "METIS_LOG_DIR=$T/log"; shift 3; printf '%s\n' "$@"; } > "$1"
}

echo "1. Vault nuovo con struttura PARA"
V1="$T/vault uno"; M1="$T/mem1"
check "installazione: nessun segnaposto rimasto oltre a COMPILARE" 'installa "$V1" "$M1" "_Claude" "0 - Inbox"'
cp "$MOD/../../03-cartella-claude/_Claude/stati/_template-stato.md" "$V1/_Claude/stati/" 2>/dev/null || touch "$V1/_Claude/stati/_template-stato.md"
config "$T/c1" "$V1" "$M1"
export METIS_CONFIG="$T/c1"
bash "$ROOT/scripts/doctor.sh" >"$T/d1.out" 2>"$T/d1.err"; RC=$?
check "doctor esce senza rosso (codice $RC)" '[ "$RC" -eq 0 ]'
check "doctor.md scritto" '[ -f "$V1/_Claude/doctor.md" ]'
check "stderr del doctor vuoto" '[ ! -s "$T/d1.err" ]'
check "nessun «report parziale»" '! grep -q "report è parziale" "$V1/_Claude/doctor.md"'
check "sei tetti misurati e rispettati" '[ "$(grep -cE "^- ✅ .*: [0-9]+ / [0-9]+$" "$V1/_Claude/doctor.md")" -eq 6 ]'
check "avvio segnalato come non fatto" 'grep -q "Avvio non fatto: 2 sezioni AVVIO" "$V1/_Claude/doctor.md"'
check "regole di partenza contate come informazione" 'grep -q "regole \[di partenza\] nel profilo: attive" "$V1/_Claude/doctor.md"'
check "stati con il solo modello: nessun errore (difetto della riga 76 del kit)" 'grep -q "Nessuno stato in" "$V1/_Claude/doctor.md"'
H=$(echo "{\"cwd\":\"$V1\",\"source\":\"startup\"}" | bash "$ROOT/hooks/session-orient.sh" 2>"$T/h1.err")
check "hook: profilo iniettato" 'printf "%s" "$H" | grep -q "^# Profilo di Anna Rossi"'
check "hook: stato attuale iniettato" 'printf "%s" "$H" | grep -q "^## Stato attuale"'
check "hook: frontmatter del profilo tolto" '! printf "%s" "$H" | grep -q "^created_at:"'
check "hook: avvio proposto" 'printf "%s" "$H" | grep -q "Avvio da fare: 2 sezioni AVVIO"'
check "hook: sunto del doctor" 'printf "%s" "$H" | grep -q "SALUTE DEL SISTEMA"'
check "hook: stderr vuoto" '[ ! -s "$T/h1.err" ]'
check "hook: CLAUDE.md non segnalato come nota senza frontmatter" '! printf "%s" "$H" | grep -q "CLAUDE (senza frontmatter)"'
check "doctor: CLAUDE.md non segnalato" '! grep -q "CLAUDE (senza frontmatter)" "$V1/_Claude/doctor.md"'
H2=$(echo "{\"cwd\":\"$T\",\"source\":\"startup\"}" | bash "$ROOT/hooks/session-orient.sh")
check "hook fuori dal vault: nessun output" '[ -z "$H2" ]'
H3=$(cd "$V1/_Claude/stati" && echo '{}' | CLAUDE_PROJECT_DIR="$V1" bash "$ROOT/hooks/session-orient.sh")
check "hook senza cwd nel JSON: usa CLAUDE_PROJECT_DIR" 'printf "%s" "$H3" | grep -q "Stato attuale"'

echo "1b. Avvio fatto: tolti i soli commenti AVVIO; COMPILARE e [di partenza] restano e non accendono avvisi"
cp -R "$V1" "$T/vault-avvio"; VF="$T/vault-avvio"
perl -0pi -e 's/<!-- AVVIO.*?-->//gs' "$VF/_Claude/profilo-nucleo.md" "$VF/_Claude/profilo-completo.md"
config "$T/cf" "$VF" "$M1"
METIS_CONFIG="$T/cf" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
check "doctor: avvio fatto" 'grep -q "Avvio fatto: il resto del profilo si completa nell" "$VF/_Claude/doctor.md"'
check "doctor: nessun avviso sull'onboarding" '! grep -q "Avvio non fatto\|Onboarding non finito" "$VF/_Claude/doctor.md"'
check "restano sezioni COMPILARE da completare nell'uso" 'grep -q "<!-- COMPILARE" "$VF/_Claude/profilo-nucleo.md"'
HF=$(echo "{\"cwd\":\"$VF\"}" | METIS_CONFIG="$T/cf" bash "$ROOT/hooks/session-orient.sh")
check "hook: nessun invito all'avvio" '! printf "%s" "$HF" | grep -q "Avvio da fare"'
export METIS_CONFIG="$T/c1"

echo "1c. Profilo di partenza: regole attive marcate [di partenza]"
VP="$V1"
check "nucleo installato: nessun [da confermare] rimasto" '! grep -q "da confermare\]" "$VP/_Claude/profilo-nucleo.md"'
check "nucleo installato: sezione Onestà epistemica attiva" 'grep -q "^## Onestà epistemica" "$VP/_Claude/profilo-nucleo.md" && ! sed -n "/^## Onestà epistemica/,/^## /p" "$VP/_Claude/profilo-nucleo.md" | grep -q "di partenza\]"'
check "nucleo installato: AVVIO solo su Chi sono e Come lavoro con te" '[ "$(grep -c "<!-- AVVIO" "$VP/_Claude/profilo-nucleo.md")" -eq 2 ] && grep -A1 "^## Chi sono" "$VP/_Claude/profilo-nucleo.md" | grep -q "<!-- AVVIO" && grep -A1 "^## Come lavoro con te" "$VP/_Claude/profilo-nucleo.md" | grep -q "<!-- AVVIO"'

echo "2. Inizio mese: un caso del mese scorso ancora in correzioni.md"
MP=$(date -v-1m +%Y-%m)
printf '\n## %s-15 — caso di prova\n\nTesto.\n' "$MP" >> "$V1/_Claude/correzioni.md"
bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
if [ "$(date +%d | sed 's/^0//')" -ge 4 ]; then
  check "doctor segnala l'inizio mese non fatto" 'grep -q "Inizio mese non fatto: 1 casi" "$V1/_Claude/doctor.md"'
else
  check "prima del giorno 4 il doctor non segnala" 'grep -q "parte dal giorno 4" "$V1/_Claude/doctor.md"'
fi
H=$(echo "{\"cwd\":\"$V1\"}" | bash "$ROOT/hooks/session-orient.sh")
check "hook ricorda la distillazione del mese" 'printf "%s" "$H" | grep -q "Inizio mese: 1 casi di $MP"'

echo "3. Tetto superato"
head -c 12000 /dev/zero | tr '\0' 'x' >> "$V1/_Claude/profilo-nucleo.md"
bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
check "doctor segnala profilo-nucleo oltre il tetto" 'grep -q "profilo-nucleo.md.*oltre il tetto di 10000" "$V1/_Claude/doctor.md"'

echo "4. Vault esistente con un'altra struttura (mappatura dei ruoli)"
V2="$T/vault-due"; M2="$T/mem2"
check "installazione con ruoli mappati: nessun segnaposto rimasto" 'installa "$V2" "$M2" "Sistema/Claude" "00 Ingresso"'
check "CLAUDE.md punta alla cartella di Claude mappata" 'grep -q "Sistema/Claude/regole-di-metodo.md" "$V2/CLAUDE.md"'
mkdir -p "$V2/Clienti/Rossi"; printf -- '---\ncreated_at: 2026-09-29\ntags:\n- appunti\nup:\n- x\n---\nTesto\n' > "$V2/Clienti/Rossi/nota.md"
printf 'Senza frontmatter\n' > "$V2/Clienti/Rossi/nuda.md"
mkdir -p "$V2/.claude/skills/prova"; printf -- '---\nname: prova\ndescription: x\n---\n' > "$V2/.claude/skills/prova/SKILL.md"
config "$T/c2" "$V2" "$M2" "METIS_RUOLO_CLAUDE=Sistema/Claude" "METIS_RUOLO_INBOX=00 Ingresso" "METIS_RUOLO_JOURNAL=Diario"
export METIS_CONFIG="$T/c2"
bash "$ROOT/scripts/doctor.sh" >/dev/null 2>"$T/d2.err"
check "doctor scrive nella cartella di Claude mappata" '[ -f "$V2/Sistema/Claude/doctor.md" ]'
check "tetti letti anche con la cartella mappata" '[ "$(grep -cE "^- ✅ .*: [0-9]+ / [0-9]+$" "$V2/Sistema/Claude/doctor.md")" -eq 6 ]'
check "Inbox mappata trovata" 'grep -q "Note in Inbox: 0" "$V2/Sistema/Claude/doctor.md"'
check "nota senza frontmatter trovata" 'grep -q "nuda (senza frontmatter)" "$V2/Sistema/Claude/doctor.md"'
check "skill del progetto in .claude: non segnalata dal doctor" '! grep -q "SKILL (manca" "$V2/Sistema/Claude/doctor.md"'
check "tag senza prefisso trovato" 'grep -q "Tag senza prefisso in: nota" "$V2/Sistema/Claude/doctor.md"'
check "stderr del doctor vuoto" '[ ! -s "$T/d2.err" ]'
config "$T/c2b" "$V2" "$M2" "METIS_RUOLO_CLAUDE=Sistema/Claude" "METIS_RUOLO_INBOX=00 Ingresso" "METIS_TAG_PREFISSI="
METIS_CONFIG="$T/c2b" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
check "controllo dei tag spento se METIS_TAG_PREFISSI è vuoto" 'grep -q "Controllo dei tag spento" "$V2/Sistema/Claude/doctor.md"'

echo "4b. Memoria di Claude Code: vault dentro un repository git"
mkdir -p "$T/repo/sotto/vault"; git -C "$T/repo" init -q
printf 'METIS_VAULT=%s\n' "$T/repo/sotto/vault" > "$T/cg"
MG=$(METIS_CONFIG="$T/cg" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; echo "$METIS_MEMORY_DIR"' "$ROOT")
ATTESA="$HOME/.claude/projects/$(cd "$T/repo" && pwd -P | sed 's/[^A-Za-z0-9]/-/g')/memory"
check "memoria ricavata dalla radice del repository" '[ "$MG" = "$ATTESA" ]'
printf 'METIS_VAULT=%s\n' "$V2" > "$T/cg2"
MG2=$(METIS_CONFIG="$T/cg2" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; echo "$METIS_MEMORY_DIR"' "$ROOT")
check "memoria ricavata dal vault quando non c'è repository" '[ "$MG2" = "$HOME/.claude/projects/$(printf "%s" "$V2" | sed "s/[^A-Za-z0-9]/-/g")/memory" ]'

echo "5. Configurazione: si legge, non si esegue"
config "$T/c3" "$V1" "$M1" 'METIS_PRODOTTO=$(touch '"$T"'/eseguito)' 'rm -rf /tmp/non-esiste' 'PATH=/nulla'
METIS_CONFIG="$T/c3" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1
check "nessun comando eseguito dalla configurazione" '[ ! -e "$T/eseguito" ]'
METIS_CONFIG="$T/manca" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1; RC=$?
check "configurazione assente: doctor esce con 2" '[ "$RC" -eq 2 ]'
H=$(echo '{}' | METIS_CONFIG="$T/manca" bash "$ROOT/hooks/session-orient.sh"; echo "rc=$?")
check "configurazione assente: hook muto e codice 0" '[ "$H" = "rc=0" ]'

echo "6. Cartella fonti: una cartella per lavoro"
V5="$T/vault cinque"; M5="$T/mem5"; F5="$T/fonti cinque"
installa "$V5" "$M5" "_Claude" "0 - Inbox" >/dev/null
check "modello: regola della cartella per lavoro in CLAUDE.md" 'grep -q "una cartella per lavoro" "$V5/CLAUDE.md" && grep -q "_IN/" "$V5/CLAUDE.md" && grep -q "_OUT/" "$V5/CLAUDE.md" && grep -q "Risorse/" "$V5/CLAUDE.md"'
config "$T/c5" "$V5" "$M5" "METIS_FONTI=$F5"
stato() {  # stato <nome> <fonte-primaria>
  printf -- "---\nstatus: attivo\nfonte-primaria: '%s'      # cartella su disco\nupdated_at: %s\n---\n\n# %s\n" "$2" "$(date +%F)" "$1" > "$V5/_Claude/stati/$1.md"
}
mkdir -p "$F5/Ente - tema/"{_IN,_fonti,_OUT} "$F5/_Risorse/norme" "$T/altrove/Fuori"
stato lavoro-a "Ente - tema"
stato lavoro-fuori "$T/altrove/Fuori"
touch "$F5/.DS_Store" "$F5/_Risorse/norme/legge.pdf"
d5() { METIS_CONFIG="$T/c5" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>"$T/d5.err"; cat "$V5/_Claude/doctor.md"; }
D=$(d5)
check "fonti in ordine: nessun file sciolto (file nascosti e _Risorse esclusi)" 'printf "%s" "$D" | grep -q "Nessun file sciolto nella radice della cartella fonti"'
check "fonti in ordine: cartella del lavoro con la struttura" 'printf "%s" "$D" | grep -q "con _IN, _fonti e _OUT (1)"'
check "cartella fuori dalla cartella fonti: non giudicata" '! printf "%s" "$D" | grep -q "Fuori (manca"'
check "fonti in ordine: stderr del doctor vuoto" '[ ! -s "$T/d5.err" ]'
touch "$F5/scaricato.pdf" "$F5/bozza.docx"
mkdir -p "$F5/Altro ente - altro tema/_IN"
stato lavoro-b "$F5/Altro ente - altro tema/"
D=$(d5)
check "file sciolti nella radice: avviso con il numero" 'printf "%s" "$D" | grep -q "⚠️ 2 file sciolti nella radice della cartella fonti"'
check "cartella senza _fonti e _OUT: avviso che dice che cosa manca" 'printf "%s" "$D" | grep -q "Altro ente - altro tema (manca _fonti _OUT)"'
check "la cartella completa non compare fra quelle segnalate" '! printf "%s" "$D" | grep -q "Ente - tema (manca"'
check "fonti in disordine: solo avvisi, doctor senza rosso" 'METIS_CONFIG="$T/c5" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>&1'
rm -rf "$F5"
check "cartella fonti assente: informazione, non avviso" 'd5 | grep -q "ℹ️ Cartella fonti non ancora creata"'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
