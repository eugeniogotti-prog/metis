#!/bin/bash
# test-mappa.sh — prova della mappa delle cartelle (scripts/mappa.py), della sua sezione nel doctor e
# dell'archiviazione (scripts/archivia.py) su un vault di prova con una struttura diversa da PARA.
# Tutto vive sotto una mktemp -d, cancellata alla fine. Le date dei giri si fissano con METIS_OGGI.
#
# Uso: bash tests/test-mappa.sh

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -n "${TDIR:-}" ]; then T="$TDIR"; else T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; fi   # TDIR: conserva i file della prova
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
ko()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

V="$T/Studio Bianchi"; F="$T/Documenti lavoro"; M="$T/mem"
mkdir -p "$V" "$F" "$M"
export METIS_CONFIG="$T/config"
cat > "$METIS_CONFIG" <<EOF
METIS_VAULT=$V
METIS_FONTI=$F
METIS_MEMORY_DIR=$M
METIS_JOBS=
METIS_LOG_DIR=$T/log
METIS_RUOLO_INBOX=Arrivi
METIS_RUOLO_PROGETTI=Clienti
METIS_RUOLO_AREE=Ambiti
METIS_RUOLO_RISORSE=Materiali
METIS_RUOLO_ARCHIVIO=Chiusi
METIS_RUOLO_PERSONE=Contatti
METIS_RUOLO_JOURNAL=Diario
METIS_RUOLO_TEMPLATE=Modelli
METIS_RUOLO_CLAUDE=_Claude
METIS_RUOLO_RISERVATA=Personale
METIS_MAPPA_CONTENITORI=Gare
EOF
bash "$ROOT/scripts/installa-struttura.sh" crea >/dev/null 2>&1
bash "$ROOT/scripts/installa-modelli.sh" templates/memoria "Luca Bianchi" >/dev/null 2>&1
CL="$V/_Claude"
mappa() { METIS_OGGI="$1" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; python3 "$0/scripts/mappa.py"' "$ROOT"; }
doctor() { METIS_OGGI="$1" bash "$ROOT/scripts/doctor.sh" >/dev/null 2>"$T/doctor.err"; }
archivia() { bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; shift; python3 "$0/scripts/archivia.py" "$@"' "$ROOT" x "$@"; }
sezione() { sed -n '/^### Mappa delle cartelle/,/^### /p' "$CL/doctor.md"; }

echo "1. Vault con i soli modelli: la mappa non accende avvisi"
doctor 2026-09-30
check "doctor senza errori su stderr" '[ ! -s "$T/doctor.err" ]'
check "sezione della mappa presente, nessun ⚠️" 'sezione | grep -q "prima fotografia" && ! sezione | grep -q "⚠️"'
rm -rf "$CL/cache/mappa-snapshot"

echo "2. Lavori, stati e cartelle su disco"
nota() { mkdir -p "$(dirname "$1")"; printf -- '---\ncreated_at: %s\ntags:\n- tipo/appunti\nup:\n- x\n---\n# %s\n' "$2" "$(basename "$1" .md)" > "$1"; }
nota "$V/Clienti/Rossi srl/Contratto Rossi.md" 2026-09-20
nota "$V/Clienti/Rossi srl/Verbale avvio.md" 2026-09-25
nota "$V/Clienti/Vigevano/Gara mensa.md" 2026-09-28
nota "$V/Clienti/Vigevano/Capitolato.md" 2026-09-28
nota "$V/Clienti/Vecchio cliente/Parere finale.md" 2025-03-01
nota "$V/Clienti/Vecchio cliente/Fattura.md" 2025-03-02
nota "$V/Personale/segreto.md" 2026-09-01
mkdir -p "$F/Rossi srl/Bozze" "$F/Gare/Gara A" "$F/Gare/Gara B"
for f in offerta.docx listino.xlsx relazione.pdf; do echo x > "$F/Rossi srl/$f"; done
echo x > "$F/Rossi srl/Bozze/b1.docx"; echo x > "$F/Gare/Gara A/bando.pdf"
stato() {  # stato <nome> <fonte-primaria> [riga di impegno]
  sed -e "s/{{slug-del-filo}}/$1/; s/{{Nome leggibile del filo}}/$1/g; s/{{YYYY-MM-DD}}/2026-09-25/g" \
      "$CL/stati/_template-stato.md" > "$CL/stati/$1.md"
  FP="$2" perl -pi -e "s/^fonte-primaria: .*/fonte-primaria: '\$ENV{FP}'/" "$CL/stati/$1.md"
  [ -n "${3:-}" ] && IMP="$3" perl -0pi -e 's/(## Impegni\n(?:<!--.*?-->\n)?)/$1$ENV{IMP}\n/s' "$CL/stati/$1.md"
  true
}
stato rossi-srl "Rossi srl"
stato vecchio-cliente "" "- [ ] Mandare la fattura | 2025-04-01 | palla:me"
mappa 2026-10-01 > "$T/m1.out"
INV="$CL/mappa-inventario.md"
check "giro 1: prima fotografia, inventario scritto" 'grep -q "prima fotografia" "$T/m1.out" && [ -f "$INV" ]'
check "lavoro collegato allo stato per nome" 'grep -q "| Rossi srl | 2 | 2026-09-25 (fm) | \[\[rossi-srl\]\] (nome) |" "$INV"'
check "cartella su disco trovata relativa alle fonti" 'grep -q "rossi-srl.*Documenti lavoro/Rossi srl.*✓" "$INV"'
check "lavoro fermo da oltre 90 giorni proposto" 'grep -q "Vecchio cliente — ultima attività 2025-03-02" "$INV"'
check "contenitore dichiarato: figli elencati" 'grep -q "Gare/Gara A" "$INV"'
check "cartella riservata mai fotografata né elencata" '! grep -rq "Personale\|segreto" "$INV" "$CL/cache/mappa-snapshot"'

echo "3. Fra un giro e l'altro: una rinomina sul disco, una nel vault, una cartella nuova"
mv "$F/Rossi srl" "$F/Rossi S.r.l."
mv "$V/Clienti/Vigevano" "$V/Clienti/Comune di Vigevano"
mkdir -p "$F/Nuovo cliente"; echo x > "$F/Nuovo cliente/primo.pdf"
doctor 2026-10-02
check "doctor senza errori su stderr" '[ ! -s "$T/doctor.err" ]'
check "rinomina sul disco riconosciuta" 'sezione | grep -q "Documenti lavoro/Rossi srl\` → \`.*Documenti lavoro/Rossi S.r.l.\`"'
check "rinomina nel vault riconosciuta" 'sezione | grep -q "Clienti/Vigevano\` → \`Clienti/Comune di Vigevano\`"'
check "cartella nuova senza lavoro segnalata" 'sezione | grep -q "Nuovo cliente\` — nessun lavoro la segue"'
check "avviso solo per il lavoro scollegato, con il percorso nuovo" '[ "$(sezione | grep -c "⚠️")" -eq 1 ] && sezione | grep -q "⚠️ Lavoro \[\[rossi-srl\]\].*forse ora è .*Rossi S.r.l."'

echo "4. Archiviazione di un lavoro finto"
archivia ricognizione --filo vecchio-cliente --lavoro "Vecchio cliente" > "$T/r.out"
check "ricognizione: impegno aperto e destinazione per anno" 'grep -q "impegni aperti: 1" "$T/r.out" && grep -q "destinazione: Chiusi/2026/Vecchio cliente" "$T/r.out"'
archivia esegui --filo vecchio-cliente --lavoro "Vecchio cliente" --motivo "incarico concluso" --distillato "nessuno: pratica standard" --istanza cli:prova > "$T/e.out"; RC=$?
check "esecuzione rifiutata con un impegno aperto" '[ "$RC" -eq 1 ] && [ -f "$CL/stati/vecchio-cliente.md" ]'
perl -pi -e 's/^- \[ \] Mandare la fattura.*/- [x] Mandare la fattura ✅ 2025-04-02/' "$CL/stati/vecchio-cliente.md"
METIS_OGGI=2026-10-02 archivia esegui --filo vecchio-cliente --lavoro "Vecchio cliente" --motivo "incarico concluso" --distillato "nessuno: pratica standard" --istanza cli:prova > "$T/e.out"; RC=$?
A="$CL/stati/archivio/vecchio-cliente.md"
check "eseguita (codice $RC)" '[ "$RC" -eq 0 ]'
check "stato archiviato: chiuso, date, riga di chiusura, marcatore" 'grep -q "^status: chiuso" "$A" && grep -q "^ultima-mossa: .2026-10-02" "$A" && grep -q "incarico concluso. Distillato: nessuno" "$A" && grep -q "aggiornato da cli:prova 2026-10-02 (archiviazione)" "$A"'
check "cartella spostata nell'archivio dell'anno" '[ -f "$V/Chiusi/2026/Vecchio cliente/Parere finale.md" ] && [ ! -d "$V/Clienti/Vecchio cliente" ]'
archivia esegui --lavoro "Rossi srl" --motivo x --distillato x --istanza cli:prova > "$T/e2.out"; RC=$?
check "lavoro con uno stato ancora vivo: non si sposta" '[ "$RC" -eq 1 ] && [ -d "$V/Clienti/Rossi srl" ]'
mappa 2026-10-03 > /dev/null
check "giro dopo l'archiviazione: spostamento in archivio riconosciuto" 'grep -q "Clienti/Vecchio cliente\` → \`Chiusi/2026/Vecchio cliente\`" "$INV"'
check "il lavoro archiviato non è più fra i fermi" '! grep -q "Vecchio cliente — ultima attività" "$INV"'
AR="$CL/mappa-archivio.md"
check "mappa dell'archivio: stato con oggetto e data di chiusura" 'grep -q "| \[\[vecchio-cliente\]\] | vecchio-cliente | 2026-10-02 |" "$AR"'
check "mappa dell'archivio: lavoro nell'anno, collegato allo stato" 'grep -q "| 2026 | Vecchio cliente | 2 | 2025-03-02 | \[\[vecchio-cliente\]\] |" "$AR"'
check "inventario delle cose in corso: rimanda all'archivio" 'grep -q "\[\[mappa-archivio\]\] (1 stati archiviati, 1 lavori archiviati)" "$INV"'

echo "5. Archivio senza cartella per anno"
echo "METIS_ARCHIVIO_PER_ANNO=no" >> "$METIS_CONFIG"
nota "$V/Clienti/Piccolo/Nota.md" 2026-01-01
archivia ricognizione --lavoro Piccolo > "$T/r2.out"
check "destinazione senza anno" 'grep -q "destinazione: Chiusi/Piccolo" "$T/r2.out"'

echo "6. Segnaposto {anno} nelle radici"
D="$T/Drive"; mkdir -p "$D/2026 attività in corso/Cliente A" "$D/Archivio fisso/X"
echo x > "$D/2026 attività in corso/Cliente A/a.pdf"; echo x > "$D/Archivio fisso/X/b.pdf"
radici_di() {  # radici_di <oggi> → etichette delle radici
  METIS_OGGI="$1" METIS_MAPPA_RADICI="$D/{anno} attività in corso|$D/Archivio fisso" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; METIS_OGGI="$1" python3 -c "
import sys, importlib.util
s = importlib.util.spec_from_file_location(\"m\", sys.argv[1] + \"/scripts/mappa.py\"); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
print(\"\n\".join(e for e, _, _ in m.radici()))" "$0"' "$ROOT" "$1"
}
check "solo la cartella 2026: nel 2027 prende la 2026 (gennaio)" 'radici_di 2027-01-05 | grep -q "Drive/2026 attività in corso$"'
mkdir -p "$D/2027 attività in corso/Cliente B"; echo x > "$D/2027 attività in corso/Cliente B/c.pdf"
check "2026 e 2027 presenti: nel 2027 prende la 2027" 'radici_di 2027-03-01 | grep -q "Drive/2027 attività in corso$" && ! radici_di 2027-03-01 | grep -q "2026 attività"'
check "nel 2026, con anche la 2027 già creata: prende la 2026" 'radici_di 2026-12-20 | grep -q "Drive/2026 attività in corso$"'
check "radice senza {anno}: invariata" 'radici_di 2027-03-01 | grep -q "Drive/Archivio fisso$"'
NFD=$(python3 -c "import unicodedata;print(unicodedata.normalize('NFD','2028 attività in corso'))")
mkdir -p "$D/$NFD/Cliente C"
check "nome in NFD sul disco: trovato, etichetta in NFC" 'radici_di 2028-02-01 | python3 -c "import sys,unicodedata; t=sys.stdin.read(); sys.exit(0 if \"2028 attività in corso\" in t and t==unicodedata.normalize(\"NFC\",t) else 1)"'

echo "7. Passaggio d'anno nella fotografia"
G="$T/Giri"; mkdir -p "$G/2026 attività in corso/Cliente A" "$G/2026 attività in corso/Cliente Z"
echo x > "$G/2026 attività in corso/Cliente A/a.pdf"; echo x > "$G/2026 attività in corso/Cliente Z/z.pdf"
giro_anno() { METIS_OGGI="$1" METIS_MAPPA_RADICI="Clienti|$G/{anno} attività in corso" bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; python3 "$0/scripts/mappa.py" >/dev/null' "$ROOT"; }
giro_anno 2026-12-30
mkdir -p "$G/2027 attività in corso/Cliente B"; echo x > "$G/2027 attività in corso/Cliente B/b.pdf"
giro_anno 2027-01-02
SP="$CL/cache/mappa-spostamenti.txt"
check "anno nuovo: una riga «radice nuova» al posto della vecchia" 'grep -q "Radice nuova: .*2027 attività in corso.* (al posto di .*2026 attività in corso" "$SP"'
check "nessuna cartella dell'anno vecchio data per sparita" '! grep -q "sparita.*2026 attività" "$SP"'
check "nessuna cartella dell'anno nuovo elencata come nuova una per una" '! grep -q "Cartella nuova: .*Cliente B" "$SP"'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
