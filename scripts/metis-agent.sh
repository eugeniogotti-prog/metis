#!/bin/bash
# metis-agent.sh — un giro automatico di Claude nel vault del cliente, lanciato da un LaunchAgent.
# Uso: metis-agent.sh <lavoro>      lavori: daily-digest, daily-sera, weekly-digest, inbox-processor
#
# Il giro: claude -p nel vault con le regole delle routine (--settings), i server MCP delle routine (--mcp-config),
# gli strumenti MCP ammessi per nome (--allowedTools), modalità acceptEdits. La guardia del plugin resta attiva:
# in un giro automatico una richiesta di conferma vale come un no, quindi niente invii e niente cancellazioni.
# Esito: una riga nella nota del giorno sotto «# Memo» (🤖 riuscito, ⚠️ metis-agent fallito, che il doctor cerca)
# e il resoconto in coda al log di sessione del giorno. Log tecnico in $METIS_LOG_DIR/<lavoro>.log.
# Un lavoro la cui skill non è nel plugin non parte, e lo dice.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "metis-agent: ${METIS_ERRORE}" >&2; exit 2; }
LAVORO="${1:-}"
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
CLAUDE="${METIS_CLAUDE:-$(command -v claude || echo "$HOME/.local/bin/claude")}"
OGGI=$(date '+%Y-%m-%d'); ORA=$(date '+%H:%M')
JOURNAL=$(metis_ruolo JOURNAL); DAILY="$JOURNAL/$OGGI.md"
mkdir -p "$METIS_LOG_DIR" "$JOURNAL" "$METIS_CL/sessioni"

# Regola in testa a ogni prompt: un giro non ha un dopo.
REGOLA="[Giro automatico di $METIS_PRODOTTO, senza nessuno davanti allo schermo. Cartella del plugin: $METIS_ROOT. Un giro non ha un dopo: niente attese, niente lavori in background, niente domande. Non mandare mail né messaggi a nessuno: prepara bozze. Chiudi con un resoconto di tre righe al massimo: che cosa hai fatto, dove l'hai scritto, che cosa resta.]"

case "$LAVORO" in
  daily-digest)    SKILL=daily-digest;    COMPITO="Esegui la skill daily-digest in modalità mattino." ;;
  daily-sera)      SKILL=daily-digest;    COMPITO="Esegui la skill daily-digest in modalità sera." ;;
  weekly-digest)   SKILL=weekly-digest;   COMPITO="Esegui la skill weekly-digest." ;;
  inbox-processor) SKILL=inbox-processor; COMPITO="Esegui la skill inbox-processor sulle note dell'Inbox." ;;
  *) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

memo() {  # memo <riga>: una riga sotto «# Memo» nella nota del giorno (creata se manca)
  [ -f "$DAILY" ] || printf -- '---\ncreated_at: %s\ntags:\n- tipo/daily\nup:\n- %s\n---\n\n# Memo\n' "$OGGI" "'[[$(basename "$JOURNAL")]]'" > "$DAILY"
  grep -q '^# Memo' "$DAILY" || printf '\n# Memo\n' >> "$DAILY"
  python3 - "$DAILY" "$1" <<'PY'
import sys
p, riga = sys.argv[1], sys.argv[2]
t = open(p, encoding="utf-8").read().split("\n")
i = next(n for n, l in enumerate(t) if l.strip() == "# Memo")
j = i + 1
while j < len(t) and not t[j].startswith("#"):
    j += 1
while j > i + 1 and t[j - 1].strip() == "":
    j -= 1
t.insert(j, riga)
open(p, "w", encoding="utf-8").write("\n".join(t))
PY
}

if [ ! -f "$METIS_ROOT/skills/$SKILL/SKILL.md" ]; then
  memo "- ⚠️ metis-agent $ORA $LAVORO: non partito, la skill $SKILL non è ancora nel plugin"
  echo "metis-agent: skill $SKILL assente nel plugin" >&2; exit 1
fi

# Inbox: se non c'è niente da lavorare, il giro non parte (niente quota spesa a vuoto).
if [ "$LAVORO" = inbox-processor ]; then
  N=$(find "$(metis_ruolo INBOX)" -name '*.md' -not -path '*/files/*' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$N" = 0 ]; then echo "metis-agent: Inbox vuota, giro saltato"; exit 0; fi
fi

ARGS=(-p --output-format json --permission-mode acceptEdits)
[ -f "$CFG_DIR/permessi-routine.json" ] && ARGS+=(--settings "$CFG_DIR/permessi-routine.json")
[ -f "$CFG_DIR/mcp-routine.json" ] && ARGS+=(--mcp-config "$CFG_DIR/mcp-routine.json")
STRUMENTI="$(bash "$METIS_ROOT/scripts/configura.sh" get METIS_ROUTINE_STRUMENTI 2>/dev/null)"
[ -n "$STRUMENTI" ] && ARGS+=(--allowedTools $STRUMENTI)

INIZIO=$(date +%s)
OUT=$(cd "$METIS_VAULT" && printf '%s\n\n%s\n' "$REGOLA" "$COMPITO" | "$CLAUDE" "${ARGS[@]}" 2>>"$METIS_LOG_DIR/$LAVORO.log"); RC=$?
DURATA=$(( $(date +%s) - INIZIO ))
RESOCONTO=$(printf '%s' "$OUT" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin); print(("ERRORE " if d.get("is_error") else "") + (d.get("result") or "").strip())
except Exception: print("ERRORE uscita non leggibile")' 2>/dev/null)
echo "$(date '+%F %T') rc=$RC ${DURATA}s $(printf '%s' "$RESOCONTO" | head -1 | cut -c1-200)" >> "$METIS_LOG_DIR/$LAVORO.log"

if [ "$RC" -ne 0 ] || [ -z "$RESOCONTO" ] || [ "${RESOCONTO#ERRORE}" != "$RESOCONTO" ]; then
  memo "- ⚠️ metis-agent $ORA $LAVORO: fallito (codice $RC, vedi $METIS_LOG_DIR/$LAVORO.log)"
  exit 1
fi
memo "- 🤖 $ORA $LAVORO: $(printf '%s' "$RESOCONTO" | head -1 | cut -c1-200)"
printf '\n## %s — giro automatico %s (%s s)\n\n%s\n' "$ORA" "$LAVORO" "$DURATA" "$RESOCONTO" >> "$METIS_CL/sessioni/$OGGI.md"
exit 0
