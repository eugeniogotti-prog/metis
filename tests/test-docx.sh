#!/bin/bash
# test-docx.sh — prova del modulo docx: esportazione in Word e guardia, nei due versi. Tutto sotto una mktemp -d.
# Richiede pandoc; python-docx si cerca nell'ambiente del modulo o nel python3 del PATH.
# Uso: bash tests/test-docx.sh

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
ko()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }
command -v pandoc >/dev/null || { echo "pandoc assente: prova saltata"; exit 0; }

V="$T/Vault"; F="$T/Documenti"; mkdir -p "$V/1 - Progetti" "$F"
export METIS_CONFIG="$T/config"
printf 'METIS_VAULT=%s\nMETIS_FONTI=%s\nMETIS_MEMORY_DIR=%s\n' "$V" "$F" "$T/mem" > "$METIS_CONFIG"
python3 -c "import docx" 2>/dev/null && export METIS_DOCX_PYTHON=python3
E="$ROOT/scripts/docx/esporta-docx.sh"
N="$V/1 - Progetti/Parere Rossi.md"
printf -- '---\ncreated_at: 2026-10-06\ntags:\n- tipo/appunti\n---\n# Parere sul contratto Rossi\n\nIl contratto vale fino al 2027, come da [[Contratto Rossi|contratto firmato]].\n%%%%nota di lavoro da non consegnare%%%%\n- primo punto\n- secondo punto\n' > "$N"

echo "1. Esportazione"
bash "$E" "$N" > "$T/o1.txt" 2>&1; RC=$?
D="$F/Parere Rossi.docx"
check "senza -o: il documento va nella cartella dei documenti, fuori dal vault (codice $RC)" '[ "$RC" = 0 ] && [ -f "$D" ] && [ ! -f "$V/1 - Progetti/Parere Rossi.docx" ]'
X=$(unzip -p "$D" word/document.xml)
check "testo presente, wikilink risolto, commento di lavoro tolto" 'printf "%s" "$X" | grep -q "contratto firmato" && ! printf "%s" "$X" | grep -q "Contratto Rossi|" && ! printf "%s" "$X" | grep -q "nota di lavoro"'
check "titolo nel documento, frontmatter tolto" 'unzip -p "$D" docProps/core.xml | grep -q "Parere sul contratto Rossi" && ! printf "%s" "$X" | grep -q "created_at"'
check "impronta registrata" '[ -f "$F/.Parere Rossi.docx.impronta" ]'
if [ -n "${METIS_DOCX_PYTHON:-}" ]; then
  check "modalità Word 2013+ impostata (python-docx)" 'unzip -p "$D" word/settings.xml | grep -q "compatibilityMode\" w:val=\"15\"\|w:val=\"15\" w:name=\"compatibilityMode\"\|compatibilityMode.*15"'
fi
N2="$V/1 - Progetti/Senza frontmatter.md"; printf '# Appunto senza intestazione\n\nTesto sufficiente per il documento di prova.\n' > "$N2"
bash "$E" "$N2" -o "$T/sf.docx" >/dev/null 2>&1; RC=$?
check "nota senza frontmatter: documento pieno (difetto dell'originale) (codice $RC)" '[ "$RC" = 0 ] && unzip -p "$T/sf.docx" word/document.xml | grep -q "Testo sufficiente"'

echo "2. Guardia"
bash "$E" "$N" >/dev/null 2>&1; RC=$?
check "riesportazione di un file non toccato: ammessa (codice $RC)" '[ "$RC" = 0 ]'
touch "$F/~\$rere Rossi.docx"
bash "$E" "$N" >/dev/null 2>"$T/g.err"; RC=$?
check "file aperto in Word (lock ~\$): fermato con codice 3" '[ "$RC" = 3 ] && grep -q "aperto in Word" "$T/g.err"'
rm -f "$F/~\$rere Rossi.docx"
printf 'x' >> "$D"
bash "$E" "$N" >/dev/null 2>"$T/g.err"; RC=$?
check "file salvato da altri dopo l'esportazione: fermato con codice 3" '[ "$RC" = 3 ] && grep -q "modificato dopo l.ultimo export" "$T/g.err"'
bash "$E" "$N" -o "$T/altro.docx" >/dev/null 2>&1; RC=$?
check "su un altro file con -o: ammesso (codice $RC)" '[ "$RC" = 0 ]'
bash "$E" "$N" --forza >/dev/null 2>&1; RC=$?
check "con --forza: ammesso e impronta aggiornata (codice $RC)" '[ "$RC" = 0 ] && bash "$E" "$N" >/dev/null 2>&1'

echo ""
echo "Esito: $PASS passati, $FAIL falliti"
[ "$FAIL" -eq 0 ]
