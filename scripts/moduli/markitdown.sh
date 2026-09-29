#!/bin/bash
# markitdown.sh — modulo MarkItDown: Claude legge PDF, Word, Excel e PowerPoint della cartella fonti convertendoli in testo.
# Uso: markitdown.sh installa | controlla
#   installa   dichiara il server MCP «markitdown» nel .mcp.json del vault, lo abilita e ne consente lo strumento
#              nelle impostazioni del vault; aggiunge il modulo alla configurazione. Rilanciabile.
#   controlla  converte un documento Word di prova creato al momento e cerca il testo atteso.
# Requisito: uv (brew install uv). Al primo uso uvx scarica il pacchetto: serve la rete.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "markitdown: ${METIS_ERRORE}" >&2; exit 2; }
IMP="$METIS_ROOT/scripts/lib/impostazioni.py"
UVX=$(command -v uvx || ls /opt/homebrew/bin/uvx /usr/local/bin/uvx 2>/dev/null | head -1)

case "${1:-}" in
  installa)
    [ -n "$UVX" ] || { echo "markitdown: manca uv (brew install uv)"; exit 1; }
    # Percorso assoluto di uvx: i giri automatici lanciati da launchd non hanno Homebrew nel PATH.
    python3 "$IMP" mcp "$METIS_VAULT/.mcp.json" markitdown "{\"type\":\"stdio\",\"command\":\"$UVX\",\"args\":[\"markitdown-mcp\"],\"env\":{}}"
    python3 "$IMP" lista "$METIS_VAULT/.claude/settings.json" enabledMcpjsonServers markitdown
    python3 "$IMP" lista "$METIS_VAULT/.claude/settings.json" permissions.allow "mcp__markitdown__convert_to_markdown"
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI markitdown
    echo "markitdown: installato; il server parte alla prossima sessione di Claude Code nel vault" ;;
  controlla)
    [ -n "$UVX" ] || { echo "❌ markitdown: manca uv"; exit 1; }
    T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
    printf 'Documento di prova di Metis\n\nConversione con accenti: perché così.\n' > "$T/p.txt"
    textutil -convert docx "$T/p.txt" -output "$T/p.docx" >/dev/null 2>&1
    OUT=$("$UVX" --from 'markitdown[all]' markitdown "$T/p.docx" 2>/dev/null)
    if printf '%s' "$OUT" | grep -q "perché così"; then echo "✅ markitdown: conversione di un documento Word riuscita"
    else echo "❌ markitdown: conversione non riuscita"; exit 1; fi
    grep -q '"markitdown"' "$METIS_VAULT/.mcp.json" 2>/dev/null && echo "✅ markitdown: server dichiarato nel vault" \
      || { echo "❌ markitdown: server non dichiarato in $METIS_VAULT/.mcp.json"; exit 1; } ;;
  *) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
