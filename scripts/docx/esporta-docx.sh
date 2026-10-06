#!/usr/bin/env bash
# esporta-docx.sh — converte una nota .md del vault in un documento Word (.docx), pronto da consegnare.
# Modulo `docx` di Metis (scripts/moduli/docx.sh). Portato il 6/10/2026 dal vault di riferimento e generalizzato.
#
# Uso: esporta-docx.sh <nota.md> [-o file.docx] [--toc] [--borders] [--forza]
#   -o        file d'uscita. Senza -o: <cartella dei documenti>/<nome della nota>.docx (METIS_FONTI), perché i file
#             binari stanno fuori dal vault; se la cartella non è configurata, accanto alla nota.
#   --toc     indice dei contenuti (due livelli)
#   --borders bordi sottili su tutte le tabelle
#   --forza   scavalca la guardia (file aperto in Word o modificato a mano dopo l'ultima esportazione)
#
# Che cosa fa: toglie il frontmatter, i wikilink ([[nota|testo]] → testo) e i commenti %%…%%; separa i paragrafi; porta il
# primo titolo nel titolo del documento; pandoc con il modello Word del cliente (METIS_DOCX_MODELLO, facoltativo; senza,
# quello di pandoc); poi, con python-docx: data nel piè di pagina (segnaposto §DATA§ nel modello), liste giustificate,
# modalità Word 2013+ (altrimenti Word apre il file «in compatibilità» e i commenti moderni non funzionano).
# Prima di scrivere chiama guardia-docx.py; dopo, controlla che il documento non sia vuoto e ne registra l'impronta.
# Codici: 0 fatto, 1 uso sbagliato o dipendenze mancanti, 2 documento vuoto, 3 fermato dalla guardia.
set -euo pipefail
QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METIS_ROOT="${METIS_ROOT:-$(cd "$QUI/../.." && pwd)}"
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config 2>/dev/null || true
PY="${METIS_DOCX_PYTHON:-$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")/docx-venv/bin/python3}"
[ -x "$PY" ] || PY=python3
PANDOC=$(command -v pandoc || ls /opt/homebrew/bin/pandoc /usr/local/bin/pandoc 2>/dev/null | head -1 || true)

IN=""; OUT=""; TOC=0; BORDERS=0; FORZA=0
while [ $# -gt 0 ]; do
  case "$1" in
    --toc) TOC=1; shift ;;
    --borders) BORDERS=1; shift ;;
    --forza) FORZA=1; shift ;;
    -o) OUT="$2"; shift 2 ;;
    -*) echo "esporta-docx: opzione sconosciuta $1" >&2; exit 1 ;;
    *) IN="$1"; shift ;;
  esac
done
[ -n "$IN" ] && [ -f "$IN" ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ -n "$PANDOC" ] || { echo "esporta-docx: manca pandoc (modulo docx: brew install pandoc)" >&2; exit 1; }
if [ -z "$OUT" ]; then
  NOME="$(basename "${IN%.md}").docx"
  if [ -n "${METIS_FONTI:-}" ]; then mkdir -p "$METIS_FONTI"; OUT="$METIS_FONTI/$NOME"; else OUT="${IN%.md}.docx"; fi
fi
GUARDIA="$QUI/guardia-docx.py"
if [ "$FORZA" -eq 0 ]; then python3 "$GUARDIA" verifica "$OUT" || exit 3; fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT; B="$TMP/corpo.md"

# frontmatter: si toglie solo se c'è (una nota senza frontmatter produceva un documento vuoto)
if [ "$(head -1 "$IN")" = "---" ]; then awk 'f{print} /^---$/{c++; if(c==2) f=1}' "$IN"; else cat "$IN"; fi \
 | sed -E 's/\[\[([^]|]*\|)?([^]]*)\]\]/\2/g' \
 | awk '
   BEGIN{incode=0}
   { cur=$0
     if (cur ~ /^[[:space:]]*```/){ if(NR>1 && !pb && !incode) print ""; print cur; incode=!incode; pb=0; pblock=0; next }
     if (incode){ print cur; pb=0; next }
     cb=(cur ~ /^[[:space:]]*$/); cblock=(cur ~ /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+/)||(cur ~ /^[[:space:]]*>/)||(cur ~ /^[[:space:]]*\|/)
     if (NR>1 && !pb && !cb){ if(!(pblock&&cblock)) print "" }
     print cur; pb=cb; pblock=cblock }' > "$B"
perl -0777 -CSD -i -pe 's/%%.*?%%//gs' "$B"          # commenti di lavoro di Obsidian: non vanno nel documento

TITOLO="$(grep -m1 '^# ' "$B" | sed 's/^# //' || true)"
if [ -n "$TITOLO" ]; then awk -v t="# $TITOLO" '{if(!d && $0==t){d=1;next} print}' "$B" > "$B.2" && mv "$B.2" "$B"; fi

args=(-f markdown+mark -t docx -V lang=it-IT -o "$OUT")
[ -n "${METIS_DOCX_MODELLO:-}" ] && [ -f "$METIS_DOCX_MODELLO" ] && args+=(--reference-doc="$METIS_DOCX_MODELLO")
[ -n "$TITOLO" ] && args+=(--metadata "title=$TITOLO")
[ "$TOC" -eq 1 ] && args+=(--toc --toc-depth=2)
"$PANDOC" "$B" "${args[@]}"

if "$PY" -c "import docx" 2>/dev/null; then
EXPORT_BORDERS="$BORDERS" "$PY" - "$OUT" <<'PY'
import sys, os, datetime
from docx import Document
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.enum.text import WD_ALIGN_PARAGRAPH
mesi = ["", "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"]
o = datetime.date.today(); dt = "%d %s %d" % (o.day, mesi[o.month], o.year)
d = Document(sys.argv[1]); s = d.sections[0]
for ftr in (s.footer, s.first_page_footer, s.even_page_footer):
    for p in ftr.paragraphs:
        for r in p.runs:
            if "§DATA§" in r.text: r.text = r.text.replace("§DATA§", dt)
def has_num(p):
    pPr = p._p.find(qn('w:pPr')); return pPr is not None and pPr.find(qn('w:numPr')) is not None
for p in d.paragraphs:
    if p.style.name == 'Compact' or has_num(p): p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
if os.environ.get("EXPORT_BORDERS") == "1":
    def tabelle(parent):
        for t in parent.tables:
            yield t
            for row in t.rows:
                for cell in row.cells:
                    yield from tabelle(cell)
    for t in tabelle(d):
        tblPr = t._tbl.tblPr
        old = tblPr.find(qn('w:tblBorders'))
        if old is not None: tblPr.remove(old)
        b = OxmlElement('w:tblBorders')
        for edge in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
            e = OxmlElement(f'w:{edge}'); e.set(qn('w:val'), 'single'); e.set(qn('w:sz'), '4'); e.set(qn('w:color'), 'auto'); b.append(e)
        tblPr.append(b)
st = d.settings.element
compat = st.find(qn('w:compat'))
if compat is None:
    compat = OxmlElement('w:compat'); st.append(compat)
cm = [c for c in compat.findall(qn('w:compatSetting')) if c.get(qn('w:name')) == 'compatibilityMode']
if cm: cm[0].set(qn('w:val'), '15')
else:
    c = OxmlElement('w:compatSetting'); c.set(qn('w:name'), 'compatibilityMode')
    c.set(qn('w:uri'), 'http://schemas.microsoft.com/office/word'); c.set(qn('w:val'), '15'); compat.append(c)
d.save(sys.argv[1])
PY
else
  echo "esporta-docx: python-docx non trovato, documento senza ritocchi (data, liste, modalità Word): bash scripts/moduli/docx.sh installa" >&2
fi

CARATTERI=$(python3 - "$OUT" <<'PYEOF' 2>/dev/null || echo 0
import re, sys, zipfile
try:
    xml = zipfile.ZipFile(sys.argv[1]).read("word/document.xml").decode("utf-8")
    print(len(re.sub(r"<[^>]+>", "", xml).strip()))
except Exception:
    print(0)
PYEOF
)
if [ "${CARATTERI:-0}" -lt 20 ]; then
  echo "✗ $OUT: il documento è vuoto ($CARATTERI caratteri). Controllare la nota d'origine." >&2
  exit 2
fi
python3 "$GUARDIA" registra "$OUT"
echo "✓ $OUT ($CARATTERI caratteri)"
