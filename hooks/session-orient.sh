#!/bin/bash
# session-orient.sh — hook SessionStart di Metis: orienta Claude all'avvio di ogni sessione nel vault.
# Lo stdout viene aggiunto al contesto della sessione.
#
# Inietta il livello «nucleo» della memoria: il profilo (profilo-nucleo.md) e lo stato attuale
# (_Claude.md, da «## Stato attuale» in fondo). CLAUDE.md e l'indice MEMORY.md li carica Claude Code da sé.
# Poi pochi segnali calcolati: sunto del doctor, onboarding da completare, operazioni di inizio mese,
# impegni scaduti, note con frontmatter incompleto, Inbox.
# Il tetto del testo iniettato sta nella tabella «Tetti del contesto» di _Claude.md; il doctor lo misura.
#
# Fuori dal vault configurato l'hook non scrive niente: il plugin può essere attivo anche in altri progetti.

export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
METIS_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
# shellcheck source=../scripts/lib/config.sh
source "$METIS_ROOT/scripts/lib/config.sh"

INPUT=$(cat 2>/dev/null)
metis_carica_config || exit 0

# La sessione è nel vault? cwd dal JSON dell'evento, poi CLAUDE_PROJECT_DIR, poi la cartella corrente.
CWD=$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
DOVE="${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}"
metis_dentro_vault "$DOVE" || exit 0

CL="$METIS_CL"
OGGI=$(date '+%Y-%m-%d')

echo "=== ${METIS_PRODOTTO}: orientamento della sessione ($OGGI) ==="
echo ""

# 1. Salute del sistema: la riga del semaforo e i punti da guardare, dal report del doctor.
if [ -f "$CL/doctor.md" ]; then
  echo "--- SALUTE DEL SISTEMA (doctor) ---"
  grep -m1 -E '^\*\*(🟢|🟡|🔴)' "$CL/doctor.md" | sed 's/\*\*//g'
  sed -n '/^## Da guardare/,/^## Dettaglio/p' "$CL/doctor.md" | grep -E '^- (⚠️|❌)' | head -10
  echo "→ Report completo: $METIS_RUOLO_CLAUDE/doctor.md"
  echo ""
fi

# 2. Profilo: il nucleo, per intero.
if [ -f "$CL/profilo-nucleo.md" ]; then
  echo "--- PROFILO (nucleo) ---"
  metis_senza_frontmatter "$CL/profilo-nucleo.md"
  echo ""
fi

# 3. Stato attuale.
if [ -f "$CL/_Claude.md" ]; then
  echo "--- STATO ATTUALE ---"
  metis_stato_attuale
  echo ""
fi

echo "--- DA FARE ALL'AVVIO ---"
SEGNALI=0

# 4. Onboarding non finito.
NCOMP=$(metis_compilare_residui)
if [ "${NCOMP:-0}" -gt 0 ]; then
  echo "- Onboarding da completare: $NCOMP punti COMPILARE nel profilo o in CLAUDE.md. Proporre di riprenderlo con la skill onboarding."
  SEGNALI=1
fi

# 5. Prima sessione del mese: casi del mese chiuso ancora in correzioni.md, log di sessione da compattare.
MESEPREC=$(metis_mese_prec)
if [ -f "$CL/correzioni.md" ] && grep -q "^## $MESEPREC-" "$CL/correzioni.md" 2>/dev/null; then
  N=$(grep -c "^## $MESEPREC-" "$CL/correzioni.md")
  echo "- Inizio mese: $N casi di $MESEPREC in correzioni.md da distillare in regole-di-metodo.md e archiviare in archivio/correzioni-$MESEPREC.md (CLAUDE.md, «Prima sessione del mese»)."
  SEGNALI=1
fi
if ls "$CL/sessioni/$MESEPREC"-*.md >/dev/null 2>&1; then
  echo "- Inizio mese: log di sessione di $MESEPREC da compattare in sessioni/archivio/$MESEPREC.md."
  SEGNALI=1
fi

# 6. Impegni palla:me scaduti.
if [ -d "$CL/stati" ]; then
  SCAD=$(grep -h -E '^- \[ \].*\| *[0-9]{4}-[0-9]{2}-[0-9]{2} *\| *palla:me' "$CL/stati/"*.md 2>/dev/null \
    | awk -F'|' -v oggi="$OGGI" '{ d=$2; gsub(/ /,"",d); if (d < oggi) n++ } END { print n+0 }')
  if [ "${SCAD:-0}" -gt 0 ]; then
    echo "- $SCAD impegni palla:me con la scadenza passata negli stati (skill impegni)."
    SEGNALI=1
  fi
fi

# 7. Note toccate negli ultimi 7 giorni con il frontmatter incompleto (fuori da _Claude, template, journal).
ESCLUSI=("$CL" "$(metis_ruolo TEMPLATE)" "$(metis_ruolo JOURNAL)" "$(metis_ruolo RISERVATA)")
INCOMPLETE=""
while IFS= read -r f; do
  salta=0
  for e in "${ESCLUSI[@]}"; do [ -n "$e" ] && case "$f" in "$e"/*) salta=1 ;; esac; done
  [ "$salta" -eq 1 ] && continue
  case "$f" in */.obsidian/*|*/.trash/*) continue ;; esac
  if [ "$(head -1 "$f" 2>/dev/null)" != "---" ]; then INCOMPLETE="$INCOMPLETE; $(basename "$f" .md) (senza frontmatter)"; continue; fi
  FM=$(awk 'NR==1{next} $0=="---"{exit} {print}' "$f" 2>/dev/null)
  MANCA=""
  for k in $METIS_FRONTMATTER_CHIAVI; do printf '%s\n' "$FM" | grep -q "^$k:" || MANCA="$MANCA $k"; done
  [ -n "$MANCA" ] && INCOMPLETE="$INCOMPLETE; $(basename "$f" .md) (manca$MANCA)"
done < <(find "$METIS_VAULT" -maxdepth 5 -name "*.md" -mtime -7 2>/dev/null | head -300)
if [ -n "$INCOMPLETE" ]; then
  echo "- Frontmatter incompleto, da sistemare per primo:${INCOMPLETE#;}" | cut -c1-600
  SEGNALI=1
fi

# 8. Inbox: note in attesa per fonte attiva.
INBOX=$(metis_ruolo INBOX)
if [ -n "$INBOX" ] && [ -d "$INBOX" ]; then
  TOT=$(find "$INBOX" -maxdepth 2 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$TOT" -gt 0 ] && { echo "- Inbox: $TOT note in attesa."; SEGNALI=1; }
fi

[ "$SEGNALI" -eq 0 ] && echo "Niente da segnalare."
echo ""
echo "→ Prima di processare contenuti o di un lavoro sostanziale: $METIS_RUOLO_CLAUDE/regole-di-metodo.md"
echo "→ Prima di proporre alternative a una scelta fatta: $METIS_RUOLO_CLAUDE/decisioni.md"
echo "=== fine orientamento ==="
exit 0
