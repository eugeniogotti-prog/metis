#!/bin/bash
# guardia.sh — hook PreToolUse di Metis. Tre protezioni, solo dentro il vault configurato:
#   1. cartella riservata: ogni strumento che la tocca viene bloccato (deny);
#   2. azioni irreversibili: cancellazioni ricorsive, cestino di Obsidian, push, reset, scaricamento dei LaunchAgent → conferma (ask);
#   3. invii verso l'esterno: strumenti di posta e messaggistica che mandano, inoltrano o rispondono → conferma (ask).
# Le bozze restano libere. In una sessione non interattiva (claude -p) una richiesta di conferma equivale a un blocco:
# è il comportamento voluto per i giri automatici (verificato con Claude Code 2.1.284).
# Uscita: JSON hookSpecificOutput sullo stdout quando decide; niente output quando lascia passare.

export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
METIS_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
INPUT=$(cat 2>/dev/null)
metis_carica_config || exit 0

# Campi dell'evento: nome dello strumento, cartella di lavoro, tutto il tool_input come testo.
eval "$(printf '%s' "$INPUT" | python3 -c '
import sys, json, shlex
try: d = json.load(sys.stdin)
except Exception: d = {}
ti = d.get("tool_input") or {}
print("TOOL=" + shlex.quote(d.get("tool_name", "")))
print("CWD=" + shlex.quote(d.get("cwd", "")))
print("CMD=" + shlex.quote(ti.get("command", "") if isinstance(ti, dict) else ""))
print("TESTO=" + shlex.quote(json.dumps(ti, ensure_ascii=False)))
' 2>/dev/null)"

metis_dentro_vault "${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}" || exit 0

decidi() {  # decidi deny|ask "motivo"
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":sys.argv[1],"permissionDecisionReason":sys.argv[2]}}, ensure_ascii=False))' "$1" "$2"
  exit 0
}

# 1. Cartella riservata: percorso assoluto o relativo al vault, in qualunque campo dell'input.
if [ -n "${METIS_RUOLO_RISERVATA:-}" ]; then
  RIS_ABS="$METIS_VAULT/$METIS_RUOLO_RISERVATA"
  case "$TESTO" in
    *"$RIS_ABS"*|*"$METIS_RUOLO_RISERVATA/"*|*"$METIS_RUOLO_RISERVATA\""*)
      decidi deny "Cartella riservata ($METIS_RUOLO_RISERVATA): Claude non la legge, non la cerca e non la elenca. Se il cliente lo chiede esplicitamente, va chiesta conferma e l'accesso lo fa lui." ;;
  esac
fi

# 2. Azioni irreversibili nei comandi di shell.
if [ "$TOOL" = "Bash" ] && [ -n "$CMD" ]; then
  C=" $(printf '%s' "$CMD" | tr '\n' ' ') "
  if printf '%s' "$C" | grep -Eq '[[:space:];&|(]rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)'; then
    decidi ask "Cancellazione ricorsiva: serve la conferma del cliente. Alternativa: spostare in una cartella di quarantena."
  fi
  printf '%s' "$C" | grep -Eq 'obsidian[[:space:]]+delete' && decidi ask "obsidian delete manda una nota nel cestino: serve la conferma del cliente."
  printf '%s' "$C" | grep -Eq 'git[[:space:]]+(push|reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f)' && decidi ask "Operazione git che pubblica o cancella: serve la conferma del cliente."
  printf '%s' "$C" | grep -Eq 'launchctl[[:space:]]+(bootout|unload|remove)' && decidi ask "Scaricare un'automazione la ferma: serve la conferma del cliente."
  printf '%s' "$C" | grep -Eq '(^|[[:space:];&|])sudo[[:space:]]' && decidi deny "Comandi con sudo: fuori da ciò che Claude fa sul Mac del cliente."
fi

# 3. Invii: strumenti MCP di posta e messaggistica che mandano, inoltrano o rispondono. Le bozze passano.
case "$TOOL" in
  mcp__*)
    AZIONE=$(printf '%s' "${TOOL##*__}" | tr 'A-Z' 'a-z')
    case "$AZIONE" in
      *draft*|*bozza*) exit 0 ;;
      send*|*_send|*send_*|forward*|*forward*|reply*|*_reply*|*post_message*|*send_message*)
        decidi ask "Invio verso l'esterno ($TOOL): parte solo con il via esplicito del cliente per questo messaggio e questo destinatario." ;;
    esac ;;
esac
exit 0
