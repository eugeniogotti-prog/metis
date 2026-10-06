#!/bin/bash
# docx.sh — modulo docx: Claude consegna le note come documenti Word (scripts/docx/esporta-docx.sh), con la guardia che
# non riscrive un documento aperto in Word o modificato a mano dopo l'ultima esportazione.
# Uso: docx.sh installa | controlla
#   installa   controlla pandoc (se manca: brew install pandoc, lo lancia il cliente), crea un ambiente Python del modulo
#              con python-docx (in <cartella della configurazione>/docx-venv, così non dipende dal Python del Mac) e
#              aggiunge il modulo alla configurazione. Serve la rete. Rilanciabile.
#   controlla  converte una nota di prova creata al momento e verifica il documento prodotto.
# Facoltativo: il modello Word del cliente (stili, intestazione, piè di pagina con §DATA§) in METIS_DOCX_MODELLO.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "docx: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
VENV="$CFG_DIR/docx-venv"
PANDOC=$(command -v pandoc || ls /opt/homebrew/bin/pandoc /usr/local/bin/pandoc 2>/dev/null | head -1)

case "${1:-}" in
  installa)
    [ -n "$PANDOC" ] || { echo "docx: manca pandoc. Comando da lanciare: brew install pandoc"; exit 1; }
    if ! "$VENV/bin/python3" -c "import docx" 2>/dev/null; then
      python3 -m venv "$VENV" && "$VENV/bin/python3" -m pip install --quiet --disable-pip-version-check python-docx \
        || { echo "docx: non riesco a installare python-docx nell'ambiente del modulo (serve la rete)"; exit 1; }
    fi
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI docx
    echo "docx: installato (pandoc: $PANDOC; python-docx in $VENV)" ;;
  controlla)
    [ -n "$PANDOC" ] || { echo "❌ docx: manca pandoc"; exit 1; }
    "$VENV/bin/python3" -c "import docx" 2>/dev/null || { echo "❌ docx: python-docx non installato (docx.sh installa)"; exit 1; }
    T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
    printf -- '---\ncreated_at: 2026-10-06\n---\n# Prova di Metis\n\nUn paragrafo con gli accenti: perché così.\n\n- primo punto\n- secondo punto\n' > "$T/prova.md"
    if METIS_DOCX_PYTHON="$VENV/bin/python3" bash "$METIS_ROOT/scripts/docx/esporta-docx.sh" "$T/prova.md" -o "$T/prova.docx" >/dev/null 2>&1 \
       && unzip -p "$T/prova.docx" word/document.xml | grep -q "perché così"; then
      echo "✅ docx: esportazione in Word funzionante"
    else echo "❌ docx: esportazione di prova non riuscita (bash scripts/docx/esporta-docx.sh <nota> -o <file>)"; exit 1; fi ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
