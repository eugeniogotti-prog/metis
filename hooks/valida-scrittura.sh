#!/bin/bash
# valida-scrittura.sh — hook PostToolUse di Metis su Write/Edit: controlla il frontmatter delle note scritte da Claude.
# Solo dentro il vault configurato, solo per i .md fuori dalla cartella di Claude, dai modelli di nota e dai file
# d'istruzioni alla radice (CLAUDE.md). Se mancano chiavi, lo dice a Claude (codice 2, messaggio su stderr) perché le
# sistemi nello stesso turno. Non blocca niente: la scrittura è già avvenuta.

export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
METIS_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
INPUT=$(cat 2>/dev/null)
metis_carica_config || exit 0

F=$(printf '%s' "$INPUT" | python3 -c 'import sys,json
try: print((json.load(sys.stdin).get("tool_input") or {}).get("file_path",""))
except Exception: pass' 2>/dev/null)
[ -n "$F" ] && [ -f "$F" ] || exit 0
case "$F" in *.md) ;; *) exit 0 ;; esac
case "$F" in "$METIS_VAULT"/*) ;; *) exit 0 ;; esac
for e in "$METIS_CL" "$(metis_ruolo TEMPLATE)"; do [ -n "$e" ] && case "$F" in "$e"/*) exit 0 ;; esac; done
case "$F" in "$METIS_VAULT"/CLAUDE.md|"$METIS_VAULT"/CLAUDE.local.md) exit 0 ;; esac

NOME="${F#$METIS_VAULT/}"
if [ "$(head -1 "$F")" != "---" ]; then
  echo "Frontmatter mancante in «${NOME}»: aggiungilo ora (chiavi: $METIS_FRONTMATTER_CHIAVI; convenzioni in CLAUDE.md)." >&2
  exit 2
fi
FM=$(awk 'NR==1{next} $0=="---"{exit} {print}' "$F")
MANCA=""
for k in $METIS_FRONTMATTER_CHIAVI; do printf '%s\n' "$FM" | grep -q "^$k:" || MANCA="$MANCA $k"; done
if [ -n "$METIS_TAG_PREFISSI" ]; then
  PREF=$(printf '%s|' $METIS_TAG_PREFISSI); PREF="${PREF%|}"
  NUDI=$(printf '%s\n' "$FM" | awk '/^tags:/{t=1; next} /^[^ -]/{t=0} t' | grep -E '^- ' | grep -vE "^- ['\"]?($PREF)/" | sed 's/^- //' | paste -sd, -)
fi
if [ -n "$MANCA" ] || [ -n "${NUDI:-}" ]; then
  MSG="Frontmatter di «${NOME}» da sistemare ora:"
  [ -n "$MANCA" ] && MSG="$MSG mancano$MANCA."
  [ -n "${NUDI:-}" ] && MSG="$MSG Tag senza prefisso: $NUDI (prefissi: $METIS_TAG_PREFISSI)."
  echo "$MSG" >&2
  exit 2
fi
exit 0
