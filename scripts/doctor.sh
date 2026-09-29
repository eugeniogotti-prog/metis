#!/bin/bash
# doctor.sh — controllo giornaliero di Metis: scrive <cartella di Claude>/doctor.md con un semaforo.
# L'hook di avvio ne mostra il sunto. Fa anche da test di conformità dopo un'installazione o un aggiornamento.
#
# Controlli: tetti del contesto (letti dalla tabella di _Claude.md), onboarding, operazioni di inizio mese,
# frontmatter e tag, stati e impegni, log di sessione, Inbox, automazioni, log grandi, affidabilità del report.
# Percorsi e ruoli dalla configurazione (scripts/lib/config.sh): nessun percorso scritto qui.
#
# Uso: bash doctor.sh            (configurazione in ~/.config/metis/config o in $METIS_CONFIG)
# Uscita: 0 verde o giallo, 1 rosso, 2 configurazione non valida.

set -uo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
# shellcheck source=lib/config.sh
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "doctor: ${METIS_ERRORE:-configurazione non valida}" >&2; exit 2; }

CL="$METIS_CL"
[ -d "$CL" ] || { echo "doctor: cartella di Claude non trovata: $CL" >&2; exit 2; }
OUT="$CL/doctor.md"
NOW=$(date +%s)
TS=$(date '+%Y-%m-%d %H:%M')
OGGI=$(date '+%Y-%m-%d')
IERI=$(metis_data_rel -1d)
GIORNO=$(date +%d); GIORNO=${GIORNO#0}
MESEPREC=$(metis_mese_prec)

# Se il doctor si rompe a metà il report è parziale, ma letto la mattina dopo sembra completo.
# stderr è il segnale: in una corsa sana è vuoto. Ciò che può fallire per motivi attesi ha il suo 2>/dev/null.
ERRLOG="$(mktemp)"
exec 3>&2 2>"$ERRLOG"
trap 'rm -f "$ERRLOG"' EXIT

OK=0; WARN=0; CRIT=0; BODY=""
add() {
  case "$1" in
    ok)   BODY="${BODY}- ✅ $2"$'\n'; OK=$((OK+1)) ;;
    warn) BODY="${BODY}- ⚠️ $2"$'\n'; WARN=$((WARN+1)) ;;
    crit) BODY="${BODY}- ❌ $2"$'\n'; CRIT=$((CRIT+1)) ;;
    info) BODY="${BODY}- ℹ️ $2"$'\n' ;;
  esac
}
sec() { BODY="${BODY}"$'\n'"### $1"$'\n'; }
conta() { grep -c . 2>/dev/null; true; }   # conta le righe non vuote dello stdin; stampa sempre un solo numero

# Note del cliente toccate negli ultimi 7 giorni, fuori dalla cartella di Claude, dai template, dal journal e dalla cartella riservata.
note_recenti() {
  local e f salta
  local esclusi=("$CL" "$(metis_ruolo TEMPLATE)" "$(metis_ruolo JOURNAL)" "$(metis_ruolo RISERVATA)")
  find "$METIS_VAULT" -maxdepth 5 -name "*.md" -mtime -7 2>/dev/null | while IFS= read -r f; do
    salta=0
    for e in "${esclusi[@]}"; do [ -n "$e" ] && case "$f" in "$e"/*) salta=1 ;; esac; done
    case "$f" in */.obsidian/*|*/.trash/*) salta=1 ;; esac
    [ "$salta" -eq 0 ] && printf '%s\n' "$f"
  done
}

# --- Tetti del contesto ---
sec "Tetti del contesto"
TETTI=$(metis_tetti)
if [ -z "$TETTI" ]; then
  add warn "Tabella «Tetti del contesto» non trovata in $METIS_RUOLO_CLAUDE/_Claude.md: i tetti non sono misurati"
else
  while IFS=$'\t' read -r etichetta tetto; do
    misura=$(metis_misura "$etichetta")
    if [ -z "$misura" ]; then add warn "$etichetta: misura non riuscita (file assente o voce non riconosciuta)"
    elif [ "$misura" -gt "$tetto" ]; then add warn "$etichetta: $misura caratteri, oltre il tetto di $tetto. Distillare, fondere o spostare nel livello su richiesta"
    else add ok "$etichetta: $misura / $tetto"; fi
  done <<< "$TETTI"
fi

# --- Onboarding ---
sec "Onboarding"
NCOMP=$(metis_compilare_residui)
if [ "${NCOMP:-0}" -gt 0 ]; then add warn "Onboarding non finito: $NCOMP punti COMPILARE nel profilo o in CLAUDE.md (skill onboarding)"
else add ok "Profilo e CLAUDE.md compilati"; fi

# --- Operazioni di inizio mese (dal giorno 4) ---
sec "Inizio mese"
if [ "$GIORNO" -ge 4 ]; then
  NCASI=$(grep "^## $MESEPREC-" "$CL/correzioni.md" 2>/dev/null | conta)
  if [ "$NCASI" -gt 0 ]; then add warn "Inizio mese non fatto: $NCASI casi di $MESEPREC ancora in correzioni.md. Distillarli in regole-di-metodo.md e spostarli in archivio/correzioni-$MESEPREC.md"
  else add ok "Casi di correzione di $MESEPREC distillati e archiviati (o nessun caso)"; fi
  NSESS=$(ls -1 "$CL/sessioni/$MESEPREC"-*.md 2>/dev/null | conta)
  if [ "$NSESS" -gt 0 ]; then add warn "$NSESS log di sessione di $MESEPREC da compattare in sessioni/archivio/$MESEPREC.md"
  else add ok "Log di sessione di $MESEPREC compattati (o nessun log)"; fi
else
  add info "Operazioni di inizio mese: il controllo parte dal giorno 4"
fi

# --- Convenzioni: frontmatter e tag ---
sec "Convenzioni"
RECENTI=$(note_recenti)
INCOMPLETE=""; NUDI=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ "$(head -1 "$f" 2>/dev/null)" != "---" ]; then INCOMPLETE="$INCOMPLETE; $(basename "$f" .md) (senza frontmatter)"; continue; fi
  FM=$(awk 'NR==1{next} $0=="---"{exit} {print}' "$f" 2>/dev/null)
  MANCA=""
  for k in $METIS_FRONTMATTER_CHIAVI; do printf '%s\n' "$FM" | grep -q "^$k:" || MANCA="$MANCA $k"; done
  [ -n "$MANCA" ] && INCOMPLETE="$INCOMPLETE; $(basename "$f" .md) (manca$MANCA)"
  if [ -n "$METIS_TAG_PREFISSI" ]; then
    PREF=$(printf '%s|' $METIS_TAG_PREFISSI); PREF="${PREF%|}"
    printf '%s\n' "$FM" | awk '/^tags:/{t=1; next} /^[^ -]/{t=0} t' | grep -E '^- ' | grep -vE "^- ['\"]?($PREF)/" | grep -q . \
      && NUDI="$NUDI, $(basename "$f" .md)"
  fi
done <<< "$RECENTI"
if [ -n "$INCOMPLETE" ]; then add warn "Frontmatter incompleto:$(printf '%s' "${INCOMPLETE#;}" | cut -c1-400)"
else add ok "Frontmatter completo nelle note recenti"; fi
if [ -z "$METIS_TAG_PREFISSI" ]; then add info "Controllo dei tag spento (METIS_TAG_PREFISSI vuoto)"
elif [ -n "$NUDI" ]; then add warn "Tag senza prefisso in:$(printf '%s' "${NUDI#,}" | cut -c1-300)"
else add ok "Tag con prefisso nelle note recenti"; fi

# --- Stati e impegni ---
sec "Lavori (stati)"
STATI=$(find "$CL/stati" -maxdepth 1 -name "*.md" ! -name "_*" 2>/dev/null | sort)
NSTATI=$(printf '%s\n' "$STATI" | conta)
if [ "$NSTATI" -eq 0 ]; then
  add info "Nessuno stato in $METIS_RUOLO_CLAUDE/stati/: il primo nasce dall'onboarding, fase 2"
else
  add info "$NSTATI stati attivi"
  MULTI=""; MALFORMATE=0; SCADUTI=0; DECADUTE=0; DORMIENTI=""
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    nome=$(basename "$f" .md)
    NSEZ=$(grep '^## Impegni' "$f" 2>/dev/null | conta)
    [ "$NSEZ" -gt 1 ] && MULTI="$MULTI $nome($NSEZ)"
    while IFS= read -r riga; do
      [ -n "$riga" ] || continue
      PALLA=$(printf '%s' "$riga" | grep -oE 'palla:[A-Za-z]*' | head -1)
      case "$PALLA" in
        palla:me|palla:claude)
          D=$(printf '%s' "$riga" | grep -oE '\| *[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | tr -d '| ')
          [ -n "$D" ] && [[ "$D" < "$OGGI" ]] && SCADUTI=$((SCADUTI+1)) ;;
        palla:loro)
          DEC=$(printf '%s' "$riga" | grep -oE 'decade:[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | cut -d: -f2)
          if [ -z "$DEC" ]; then MALFORMATE=$((MALFORMATE+1))
          elif [[ "$DEC" < "$OGGI" ]]; then DECADUTE=$((DECADUTE+1)); fi ;;
        *) MALFORMATE=$((MALFORMATE+1)) ;;
      esac
    done < <(grep -E '^- \[ \]' "$f" 2>/dev/null)
    ULTIMA=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null | awk -v t="$OGGI" '$1 <= t' | sort | tail -1)
    if [ -n "$ULTIMA" ]; then
      E=$(metis_epoch "$ULTIMA")
      [ "$E" -gt 0 ] && [ $(( (NOW - E) / 86400 )) -gt 30 ] && DORMIENTI="$DORMIENTI $nome($(( (NOW - E) / 86400 ))gg)"
    fi
  done <<< "$STATI"
  [ -n "$MULTI" ] && add warn "Stati con più di una sezione ## Impegni (skill impegni):$MULTI" || add ok "Una sola sezione ## Impegni per stato"
  [ "$MALFORMATE" -gt 0 ] && add warn "$MALFORMATE righe d'impegno senza palla valida o attese senza decade:" || add ok "Righe d'impegno a norma"
  [ "$SCADUTI" -gt 0 ] && add warn "$SCADUTI impegni palla:me con la scadenza passata" || add ok "Nessun impegno scaduto"
  [ "$DECADUTE" -gt 0 ] && add warn "$DECADUTE attese oltre la data di decadenza, da chiudere come ⊘ decaduta (auto $OGGI)" || add ok "Nessuna attesa oltre la decadenza"
  [ -n "$DORMIENTI" ] && add warn "Lavori fermi da più di 30 giorni:$DORMIENTI" || add ok "Nessun lavoro fermo da più di 30 giorni"
fi

# --- Log di sessione: se ieri si è lavorato nel vault, il log di ieri deve esserci ---
sec "Log di sessione"
TOCCATE_IERI=$(find "$METIS_VAULT" -maxdepth 5 -name "*.md" -newermt "$IERI" ! -newermt "$OGGI" -not -path "*/.obsidian/*" 2>/dev/null | conta)
if [ -f "$CL/sessioni/$IERI.md" ]; then add ok "Log di sessione di ieri presente"
elif [ "$TOCCATE_IERI" -gt 0 ]; then add warn "Ieri sono state toccate $TOCCATE_IERI note ma manca sessioni/$IERI.md: la routine di chiusura è saltata"
else add ok "Ieri nessuna attività nel vault, nessun log atteso"; fi

# --- Inbox ---
sec "Inbox"
INBOX=$(metis_ruolo INBOX)
if [ -z "$INBOX" ] || [ ! -d "$INBOX" ]; then
  add warn "Cartella Inbox non trovata ($METIS_RUOLO_INBOX)"
else
  TOT=$(find "$INBOX" -maxdepth 3 -name "*.md" 2>/dev/null | conta)
  add info "Note in Inbox: $TOT"
  for sub in $METIS_INBOX_FONTI; do
    [ -d "$INBOX/$sub" ] || continue
    n=$(find "$INBOX/$sub" -maxdepth 1 -name "*.md" 2>/dev/null | conta)
    [ "$n" -gt 5 ] && add warn "Inbox/$sub: $n note, sopra la soglia di 5 (l'inbox-processor gira?)"
  done
  VECCHIA=$(find "$INBOX" -maxdepth 3 -name "*.md" -mtime +7 2>/dev/null | head -1)
  [ -n "$VECCHIA" ] && add warn "Almeno una nota ferma in Inbox da più di 7 giorni: $(basename "$VECCHIA" .md)"
  [ "$TOT" -le 5 ] && [ -z "$VECCHIA" ] && add ok "Inbox sotto controllo"
fi

# --- Automazioni ---
sec "Automazioni"
if [ -z "$METIS_JOBS" ]; then
  add info "Nessuna automazione configurata"
else
  for job in $METIS_JOBS; do
    if launchctl list "$METIS_LABEL.$job" >/dev/null 2>&1; then add ok "LaunchAgent $METIS_LABEL.$job caricato"
    else add warn "LaunchAgent $METIS_LABEL.$job non caricato"; fi
  done
  JOURNAL=$(metis_ruolo JOURNAL)
  if [ -n "$JOURNAL" ] && [ -f "$JOURNAL/$IERI.md" ]; then
    grep -q '⚠️ metis-agent' "$JOURNAL/$IERI.md" 2>/dev/null && add crit "Un giro automatico è fallito ieri: vedere la daily di ieri e $METIS_LOG_DIR"
  fi
fi

# --- Manutenzione: log grandi ---
sec "Manutenzione"
GRANDI=0
for L in "$METIS_LOG_DIR"/*.log; do
  [ -f "$L" ] || continue
  sz=$(stat -f %z "$L" 2>/dev/null || stat -c %s "$L" 2>/dev/null || echo 0)
  [ "$sz" -gt 1000000 ] && { add warn "Log grande: $(basename "$L") ($((sz/1024)) KB)"; GRANDI=1; }
done
[ "$GRANDI" -eq 0 ] && add ok "Nessun log oltre 1 MB"

# --- Affidabilità del report: stderr non vuoto vuol dire report parziale ---
NERR=$(conta < "$ERRLOG")
if [ "$NERR" -gt 0 ]; then
  sec "Affidabilità di questo report"
  add crit "Il controllo ha prodotto $NERR righe di errore: questo report è parziale. $(tr '\n' ' ' < "$ERRLOG" | cut -c1-300)"
fi

# --- Report ---
SEMAFORO="🟢"; [ "$WARN" -gt 0 ] && SEMAFORO="🟡"; [ "$CRIT" -gt 0 ] && SEMAFORO="🔴"
DAGUARDARE=$(printf '%s' "$BODY" | grep -E '^- (⚠️|❌)' || true)
{
  echo "---"
  echo "created_at: $OGGI"
  echo "updated_at: $OGGI"
  echo "tags:"
  echo "- tipo/appunti"
  echo "up:"
  echo "- '[[_Claude]]'"
  echo "---"
  echo ""
  echo "# Doctor — salute del sistema"
  echo ""
  echo "**$SEMAFORO $TS — $OK ✅ · $WARN ⚠️ · $CRIT ❌**"
  echo ""
  if [ -n "$DAGUARDARE" ]; then echo "## Da guardare"; echo ""; printf '%s\n' "$DAGUARDARE"; echo ""; fi
  echo "## Dettaglio"
  printf '%s' "$BODY"
  echo ""
  echo "<!-- generato da doctor.sh di $METIS_PRODOTTO: non modificare a mano -->"
} > "$OUT"

# Andamento: una riga al giorno, per distinguere un problema cronico da uno passeggero.
TREND="$CL/doctor-andamento.tsv"
[ -f "$TREND" ] || printf 'data\tok\twarn\tcrit\n' > "$TREND"
grep -v "^${OGGI}[[:space:]]" "$TREND" > "$TREND.tmp" 2>/dev/null && mv "$TREND.tmp" "$TREND"
printf '%s\t%s\t%s\t%s\n' "$OGGI" "$OK" "$WARN" "$CRIT" >> "$TREND"

exec 2>&3
echo "doctor: $SEMAFORO report in $OUT ($OK ok, $WARN warn, $CRIT crit)"
[ "$CRIT" -gt 0 ] && exit 1
exit 0
