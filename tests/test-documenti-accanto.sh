#!/bin/bash
# test-documenti-accanto.sh — documenti accanto alle note (METIS_DOCUMENTI=accanto, decisione del 23/10/2026):
# variante del CLAUDE.md all'installazione, doctor e valida-scrittura che non giudicano i file in _IN/_fonti/_OUT,
# archiviazione che sposta la cartella del lavoro con i documenti e aggiorna la fonte-primaria; mappa con una sola
# cartella per lavoro (sottocartelle _IN/_fonti/_OUT non contate), aree e risorse, doctor sulle radici PARA, permessi, Word.
set -u
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  ✅ $1"; }; ko() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
export METIS_ROOT="$SRC" METIS_CONFIG="$T/cfg/config" METIS_OGGI=2026-10-23
V="$T/vault"; mkdir -p "$V" "$T/cfg"
cfg() { printf 'METIS_VAULT=%s\nMETIS_RUOLO_PROGETTI=Lavori\nMETIS_RUOLO_ARCHIVIO=Archivio\nMETIS_RUOLO_RISORSE=Risorse\nMETIS_RUOLO_PERSONE=Risorse/Persone\nMETIS_MEMORY_DIR=%s/mem\n%s' "$V" "$T" "$1" > "$METIS_CONFIG"; }

echo "1. Modello CLAUDE.md e configurazione"
cfg ''
bash "$SRC/scripts/installa-modelli.sh" "$SRC/templates/memoria" "Cliente Prova" >/dev/null 2>&1
check "default: documenti accanto alle note" 'grep -q "Note e documenti nella stessa cartella" "$V/CLAUDE.md" && ! grep -q "Binari su disco, note nel vault" "$V/CLAUDE.md"'
check "default: risorse per tema e sottotema, Inbox come ultima risorsa" 'grep -q "Risorse/Norme/Appalti/" "$V/CLAUDE.md" && grep -q "prima si chiede a Cliente Prova" "$V/CLAUDE.md"'
check "segnaposto sostituiti" '! grep -q "{{FONTI}}\|{{RUOLO_\|{{Nome}}" "$V/CLAUDE.md"'
check "marcatori presenti una volta" '[ "$(grep -c "documenti:inizio" "$V/CLAUDE.md")" = 1 ] && [ "$(grep -c "documenti:fine" "$V/CLAUDE.md")" = 1 ]'
f=$(bash -c 'source "$0/scripts/lib/config.sh"; METIS_FONTI= metis_carica_config; echo "$METIS_DOCUMENTI|$METIS_FONTI"' "$SRC")
V0="$T/vault0"; mkdir -p "$V0"; printf 'METIS_VAULT=%s\n' "$V0" > "$T/cfg/config0"
f=$(METIS_CONFIG="$T/cfg/config0" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; echo "$METIS_DOCUMENTI|$METIS_FONTI"' "$SRC")
check "default senza configurazione: accanto, fonti = progetti del vault" '[ "$f" = "accanto|$V0/1 - Progetti" ]'
printf 'METIS_VAULT=%s\nMETIS_FONTI=%s/fuori\n' "$V0" "$T" > "$T/cfg/config0"
f=$(METIS_CONFIG="$T/cfg/config0" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; echo "$METIS_DOCUMENTI"' "$SRC")
check "installazione precedente con fonti fuori dal vault: resta separati" '[ "$f" = separati ]'
V2="$T/vault2"; mkdir -p "$V2"; printf 'METIS_VAULT=%s\nMETIS_DOCUMENTI=separati\nMETIS_FONTI=%s/fonti\nMETIS_MEMORY_DIR=%s/mem2\n' "$V2" "$T" "$T" > "$T/cfg/config2"
METIS_CONFIG="$T/cfg/config2" bash "$SRC/scripts/installa-modelli.sh" "$SRC/templates/memoria" "Cliente Prova" >/dev/null 2>&1
check "separati su scelta: blocco «binari su disco»" 'grep -q "Binari su disco, note nel vault" "$V2/CLAUDE.md" && ! grep -q "Note e documenti nella stessa cartella" "$V2/CLAUDE.md"'

echo "2. File di lavoro non giudicati come note"
L="$V/Lavori/Ente - tema 2026"; mkdir -p "$L/_IN" "$L/_fonti" "$L/_OUT" "$V/Archivio"
printf -- '---\ncreated_at: 2026-10-23\ntags:\n- tipo/appunti\nup:\n- x\n---\nnota\n' > "$L/2026-10-23 Analisi prova — Ente.md"
printf '# Fonti\n' > "$L/_fonti/README.md"; printf 'testo\n' > "$L/_IN/convertito.md"; printf 'pdf' > "$L/_IN/atto.pdf"
bash "$SRC/scripts/doctor.sh" >/dev/null 2>&1
check "doctor: nessun avviso di frontmatter per _IN/_fonti" '! grep -q "Frontmatter incompleto" "$V/_Claude/doctor.md"'
E=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"testo"},"cwd":"%s"}' "$L/_fonti/README.md" "$V" | bash "$SRC/hooks/valida-scrittura.sh" 2>&1 >/dev/null; echo "c=$?")
check "valida-scrittura: silenzio sui file in _fonti" '[ "$E" = "c=0" ]'

echo "3. Mappa e doctor con i documenti accanto"
mappa() { METIS_OGGI="$1" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; python3 "$0/scripts/mappa.py"' "$SRC"; }
S="$V/_Claude/stati/ente-tema-2026.md"
printf -- "---\ncreated_at: 2026-10-01\ntags:\n- tipo/appunti\nup:\n- x\nstatus: caldo\nfonte-primaria: 'Ente - tema 2026/'\nupdated_at: 2026-10-20\n---\n\n## Impegni\n" > "$S"
mkdir -p "$L/Bozze"; printf -- '---\ncreated_at: 2026-10-22\ntags:\n- tipo/appunti\nup:\n- x\n---\nbozza\n' > "$L/Bozze/Bozza relazione.md"
AR_="$V/2 - Aree/Amministrazione"; mkdir -p "$AR_/_IN"
printf -- '---\ncreated_at: 2026-10-10\ntags:\n- tipo/appunti\nup:\n- x\n---\narea\n' > "$AR_/Scadenze dell'anno.md"; printf 'pdf' > "$AR_/_IN/avviso.pdf"
mkdir -p "$V/Risorse/Norme/Appalti" "$V/Risorse/Studi"; printf 'pdf' > "$V/Risorse/Norme/Appalti/legge.pdf"; printf '# Norme\n' > "$V/Risorse/Norme/README.md"
printf 'pdf' > "$V/Risorse/Studi/rapporto.pdf"
mkdir -p "$V/Risorse/Persone"; printf '# Nome Cognome\n' > "$V/Risorse/Persone/Nome Cognome.md"   # ruolo PERSONE dentro le risorse
printf -- "---\nstatus: attivo\nfonte-primaria: '2 - Aree/Amministrazione/'\nupdated_at: 2026-10-20\n---\n\n## Impegni\n" > "$V/_Claude/stati/amministrazione.md"
R1=$(mappa 2026-10-22); INV="$V/_Claude/mappa-inventario.md"
check "un solo lavoro, collegato al suo stato" 'printf "%s" "$R1" | grep -q "mappa: 1 lavori" && grep -q "^| Ente - tema 2026 | 2 | .* | \[\[ente-tema-2026\]\] (nome) |" "$INV"'
check "_IN, _fonti, _OUT e Bozze non sono lavori; le note in _IN e _fonti non contano" '! grep -Eq "^\| (_IN|_fonti|_OUT|Bozze) \|" "$INV"'
check "radici: progetti, aree, risorse e archivio, senza doppioni" 'grep "^\*Generato" "$INV" | grep -q "\`Lavori\`, \`2 - Aree\`, \`Risorse\`, \`Archivio\`" && [ "$(grep "^\*Generato" "$INV" | grep -o "\`Lavori\`" | wc -l)" -eq 1 ]'
check "nessuna sezione «Cartelle su disco»: la cartella del lavoro è una sola" '! grep -q "^## Cartelle su disco" "$INV"'
check "aree elencate a parte, con lo stato, senza proposta d archivio" 'grep -q "^## Aree in «2 - Aree»" "$INV" && grep -q "^| Amministrazione | 1 | .* | \[\[amministrazione\]\]" "$INV"'
check "la cartella delle persone non è un tema delle risorse" '! grep -q "^| Persone |" "$INV"'
check "risorse per tema, con il README che manca segnalato" 'grep -q "^| Norme | Appalti | 1 | sì |" "$INV" && grep -q "^| Studi | — | 1 | \*\*manca\*\* |" "$INV"'
check "cartella del lavoro dello stato trovata" 'grep -q "\[\[ente-tema-2026\]\] .*Lavori/Ente - tema 2026.*✓" "$INV"'
printf 'pdf' > "$V/Lavori/scaricato.pdf"; printf -- '---\ncreated_at: 2026-10-23\ntags:\n- tipo/indice\nup:\n- x\n---\n' > "$V/Lavori/Lavori.md"
bash "$SRC/scripts/doctor.sh" >/dev/null 2>&1; DOC="$V/_Claude/doctor.md"
check "doctor: sezione «Cartelle dei documenti», documento sciolto contato, nota d indice no" 'grep -q "Cartelle dei documenti" "$DOC" && grep -q "1 file sciolti nella radice delle cartelle dei progetti, delle aree e delle risorse" "$DOC"'
check "doctor: area senza _fonti e _OUT segnalata, il lavoro completo no" 'grep -q "Amministrazione (manca _fonti _OUT)" "$DOC" && ! grep -q "Ente - tema 2026 (manca" "$DOC"'
rm "$V/Lavori/scaricato.pdf"

echo "4. Archiviazione"
S="$V/_Claude/stati/ente-tema-2026.md"
printf -- "---\ncreated_at: 2026-10-01\ntags:\n- tipo/appunti\nup:\n- x\nstatus: caldo\nfonte-primaria: 'Ente - tema 2026/'\nupdated_at: 2026-10-20\n---\n\n## Impegni\n" > "$S"
archivia() { bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; shift; python3 "$0/scripts/archivia.py" "$@"' "$SRC" x "$@"; }
R=$(archivia ricognizione --filo ente-tema-2026 --lavoro "Ente - tema 2026")
check "ricognizione: la cartella su disco si sposta con il lavoro" 'printf "%s" "$R" | grep -q "si sposta con lui"'
archivia esegui --filo ente-tema-2026 --lavoro "Ente - tema 2026" --motivo prova --distillato "nessuno: prova" --istanza test >/dev/null
D="$V/Archivio/2026/Ente - tema 2026"
check "cartella spostata con documenti e note" '[ -f "$D/_IN/atto.pdf" ] && [ -f "$D/2026-10-23 Analisi prova — Ente.md" ] && [ ! -d "$L" ]'
A="$V/_Claude/stati/archivio/ente-tema-2026.md"
check "fonte-primaria aggiornata alla posizione nuova" 'grep -q "^fonte-primaria: .*Archivio/2026/Ente - tema 2026/" "$A"'
R2=$(mappa 2026-10-23); SP="$V/_Claude/cache/mappa-spostamenti.txt"; AM="$V/_Claude/mappa-archivio.md"
check "mappa: spostamento in archivio riconosciuto, nessun avviso" 'grep -q "Lavori/Ente - tema 2026\` → \`Archivio/2026/Ente - tema 2026\`" "$SP" && ! grep -q "^warn" "$SP"'
check "mappa: nessuna «cartella nuova senza lavoro» per l anno d archivio" '! grep -q "nessun lavoro la segue" "$SP"'
check "mappa dell archivio: lavoro nell anno, con lo stato, una volta sola" '[ "$(grep -c "Ente - tema 2026" "$AM")" -eq 2 ] && grep -q "^| 2026 | Ente - tema 2026 | 2 | .* | \[\[ente-tema-2026\]\] |" "$AM"'
check "mappa dell archivio: cartella del lavoro dello stato nell archivio, niente sezione su disco" 'grep -q "^| \[\[ente-tema-2026\]\] .*Archivio/2026/Ente - tema 2026" "$AM" && ! grep -q "Cartelle su disco" "$AM"'
check "inventario: il lavoro non è più fra i lavori in corso" 'printf "%s" "$R2" | grep -q "mappa: 0 lavori"'

echo "5. Permessi e Word"
bash "$SRC/scripts/installa-permessi.sh" >/dev/null 2>&1
check "accanto: nessuna cartella aggiuntiva" 'python3 -c "import json,sys; sys.exit(0 if not json.load(open(sys.argv[1]))[\"permissions\"][\"additionalDirectories\"] else 1)" "$V/.claude/settings.json"'
METIS_CONFIG="$T/cfg/config2" bash "$SRC/scripts/installa-permessi.sh" >/dev/null 2>&1
check "separati: la cartella fonti fuori dal vault è cartella aggiuntiva" 'grep -q "$T/fonti" "$V2/.claude/settings.json"'
if command -v pandoc >/dev/null; then
  W="$V/Lavori/Comune - prova 2027"; mkdir -p "$W/Bozze"; printf '# Relazione\n\nTesto di prova.\n' > "$W/Bozze/Relazione.md"
  bash "$SRC/scripts/docx/esporta-docx.sh" "$W/Bozze/Relazione.md" >/dev/null 2>&1
  check "Word senza -o: nella _OUT del lavoro, con la data" '[ -f "$W/_OUT/2026-10-23 Relazione.docx" ] || ls "$W/_OUT/"*" Relazione.docx" >/dev/null 2>&1'
else echo "  (pandoc assente: prova del Word saltata)"; fi
echo; echo "documenti accanto: $PASS ok, $FAIL falliti"; [ "$FAIL" = 0 ]
