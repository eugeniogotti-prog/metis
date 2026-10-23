#!/bin/bash
# doctor.sh — controllo giornaliero di Metis: scrive <cartella di Claude>/doctor.md con un semaforo.
# L'hook di avvio ne mostra il sunto. Fa anche da test di conformità dopo un'installazione o un aggiornamento.
#
# Controlli: tetti del contesto (letti dalla tabella di _Claude.md), onboarding, operazioni di inizio mese,
# frontmatter e tag, stati e impegni, mappa delle cartelle, cartelle dei documenti, log di sessione, Inbox, automazioni, log grandi, affidabilità del report.
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
    case "$f" in */.obsidian/*|*/.trash/*|*/.claude/*) salta=1 ;; esac   # .claude: skill e comandi del progetto, non note
    case "$f" in */_IN/*|*/_fonti/*|*/_OUT/*) salta=1 ;; esac   # file di lavoro (ricevuti, fonti, consegnati): non note da giudicare
    case "$f" in "$METIS_VAULT"/CLAUDE.md|"$METIS_VAULT"/CLAUDE.local.md) salta=1 ;; esac   # istruzioni, non note
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
if [ "${NCOMP:-0}" -gt 0 ]; then add warn "Onboarding non finito: $NCOMP punti da compilare o regole [da confermare] nel profilo o in CLAUDE.md (skill onboarding)"
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
  add info "Nessuno stato in $METIS_RUOLO_CLAUDE/stati/: il primo nasce con l'onboarding"
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
  # Soglie (6/10/2026, dal vault di riferimento): 2-3 sezioni avviso, oltre 3 critico. Ogni sezione in più è un posto
  # dove un impegno si duplica o resta aperto a fatto avvenuto.
  MCRIT=$(printf '%s' "$MULTI" | tr ' ' '\n' | sed -n 's/^\(.*\)(\([0-9]*\))$/\2 \1/p' | awk '$1>3{printf "%s %s(%s)", s, $2, $1; s=","}')
  MWARN=$(printf '%s' "$MULTI" | tr ' ' '\n' | sed -n 's/^\(.*\)(\([0-9]*\))$/\2 \1/p' | awk '$1<=3{printf "%s %s(%s)", s, $2, $1; s=","}')
  [ -n "$MCRIT" ] && add crit "Stati con più di 3 sezioni ## Impegni, da riunire (skill impegni § 7):$MCRIT"
  [ -n "$MWARN" ] && add warn "Stati con 2-3 sezioni ## Impegni (skill impegni § 7):$MWARN"
  [ -z "$MULTI" ] && add ok "Una sola sezione ## Impegni per stato"
  [ "$MALFORMATE" -gt 0 ] && add warn "$MALFORMATE righe d'impegno senza palla valida o attese senza decade:" || add ok "Righe d'impegno a norma"
  [ "$SCADUTI" -gt 0 ] && add warn "$SCADUTI impegni palla:me con la scadenza passata" || add ok "Nessun impegno scaduto"
  [ "$DECADUTE" -gt 0 ] && add warn "$DECADUTE attese oltre la data di decadenza, da chiudere come ⊘ decaduta (auto $OGGI)" || add ok "Nessuna attesa oltre la decadenza"
  [ -n "$DORMIENTI" ] && add warn "Lavori fermi da più di 30 giorni:$DORMIENTI" || add ok "Nessun lavoro fermo da più di 30 giorni"
fi

# --- Mappa delle cartelle: inventario, fotografia del giorno e confronto con la precedente (scripts/mappa.py) ---
# Avviso solo per i lavori che perdono la loro cartella (fonte-primaria); il resto è informazione.
sec "Mappa delle cartelle"
RIEP=$(python3 "$METIS_ROOT/scripts/mappa.py" 2>/dev/null | tail -1)
case "$RIEP" in
  "mappa: ERRORE"*|"") add warn "Mappa non generata: ${RIEP:-nessuna uscita} (python3 $METIS_ROOT/scripts/mappa.py)" ;;
  *) add info "${RIEP#mappa: } — $METIS_RUOLO_CLAUDE/mappa-inventario.md"
     NSP=0; SPOST="$CL/cache/mappa-spostamenti.txt"; [ -f "$SPOST" ] || SPOST=/dev/null
     while IFS='|' read -r LIV TESTO; do
       [ -n "$LIV" ] || continue
       if [ "$LIV" = warn ]; then add warn "$TESTO"
       else NSP=$((NSP+1)); [ "$NSP" -le 8 ] && add info "$TESTO"; fi
     done < "$SPOST"
     [ "$NSP" -gt 8 ] && add info "… e altri $((NSP-8)) spostamenti: elenco completo nell'inventario"
     case "$RIEP" in *" 0 fermi "*) ;; *) add info "Lavori fermi da tempo: proposte per l'archivio nell'inventario (skill archiviazione, alla prima sessione del mese)" ;; esac ;;
esac

# --- Ascolto del telefono (6/10/2026): solo se è installato l'ascoltatore Telegram ---
# L'ascoltatore riscrive il suo file di stato a ogni ciclo (circa un minuto): la data del file è il battito. Se il Mac si
# è svegliato da poco, un battito vecchio è normale (durante il sonno launchd sospende tutto) e non è un allarme.
# Variabili per le prove: METIS_TELEGRAM_STATO, METIS_ASCOLTO_PROCESSO (1/0), METIS_WAKETIME (epoch).
if [ -f "${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}/$METIS_LABEL.telegram.plist" ]; then
  sec "Ascolto del telefono"
  ST="${METIS_TELEGRAM_STATO:-$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")/telegram-stato.json}"
  VIVO="${METIS_ASCOLTO_PROCESSO:-$(pgrep -f "metis_telegram.py ascolta" >/dev/null 2>&1 && echo 1 || echo 0)}"
  SVEGLIA="${METIS_WAKETIME:-$(sysctl -n kern.waketime 2>/dev/null | sed -n 's/.*sec = \([0-9]*\).*/\1/p')}"
  if [ "$VIVO" != 1 ]; then add crit "L'ascoltatore del bot non gira: i messaggi dal telefono non arrivano nel vault (bash scripts/moduli/telegram.sh controlla)"
  elif [ ! -f "$ST" ]; then add warn "L'ascoltatore gira ma non ha ancora scritto il suo stato ($ST)"
  else
    BATT=$(stat -f %m "$ST" 2>/dev/null || echo 0); ETA=$(( (NOW - BATT) / 60 ))
    if [ "$ETA" -le 15 ]; then add ok "Ascoltatore del bot attivo (battito $ETA min fa)"
    elif [ -n "$SVEGLIA" ] && [ "$BATT" -lt "$SVEGLIA" ] && [ $(( (NOW - SVEGLIA) / 60 )) -le 10 ]; then add info "Ascoltatore del bot: Mac svegliato da $(( (NOW - SVEGLIA) / 60 )) min, battito non ancora ripreso"
    elif [ "$ETA" -le 60 ]; then add warn "Ascoltatore del bot: ultimo battito $ETA min fa"
    else add crit "Ascoltatore del bot fermo: ultimo battito $ETA min fa, il processo c'è ma non ascolta (ricaricarlo: bash scripts/lib/launchd.sh carica telegram)"; fi
  fi
fi

# --- Segreti in chiaro nel vault (6/10/2026) ---
# trascrizione.py oscura token e chiavi quando stampa; questo è il controllo dietro: un segreto incollato in una nota,
# in un log o in un file arrivato da fuori si vede il giorno dopo. Si stampano solo file e tipo, mai il segreto.
# La cartella riservata non si legge mai.
sec "Segreti"
ESCL=(); RIS=$(metis_ruolo RISERVATA); [ -n "$RIS" ] && ESCL=(--escludi "$RIS")
SEGR=$(python3 "$METIS_ROOT/scripts/segreti.py" --cerca "$METIS_VAULT" ${ESCL[@]+"${ESCL[@]}"} 2>/dev/null)
if [ -z "$SEGR" ]; then add ok "Nessun token o chiave in chiaro nelle note"
else add crit "Token o chiavi in chiaro in $(printf '%s\n' "$SEGR" | grep -c .) note: $(printf '%s\n' "$SEGR" | head -3 | sed "s|$METIS_VAULT/||" | tr '\t\n' ' ;') — oscurarli (le regole sono in scripts/segreti.py) e valutare la revoca"; fi

# --- Portabilità macOS (6/10/2026) ---
# Comandi GNU che su macOS non esistono o si comportano diversamente: un giro automatico che li usa riceve
# «command not found» e può leggere l'uscita vuota come un risultato. Si cercano negli script e nelle skill del plugin
# e nelle istruzioni del vault; al posto di timeout c'è scripts/con-timeout.sh. Poi il PATH dei LaunchAgent di Metis.
sec "Portabilità macOS"
PORT=$( { ls "$METIS_ROOT"/scripts/*.sh "$METIS_ROOT"/scripts/*/*.sh "$METIS_ROOT"/hooks/*.sh "$METIS_ROOT"/skills/*/SKILL.md "$METIS_VAULT/CLAUDE.md" "$METIS_VAULT/CLAUDE.local.md" "$CL/regole-di-metodo.md" "$CL/regole-di-metodo-strumenti.md" 2>/dev/null; } \
  | while IFS= read -r f; do grep -nHE '(^|[`;&|( ])(g?timeout [0-9]+|date -d |grep -[a-zA-Z]*P |readlink -f )' "$f" 2>/dev/null; done \
  | grep -vE ':[0-9]+:[[:space:]]*#' | grep -vE 'con-timeout|grep -nHE|date -v|date -j' | sed "s|$METIS_ROOT/||; s|$METIS_VAULT/||" | cut -c1-110)
if [ -n "$PORT" ]; then add warn "Comandi GNU assenti su macOS in $(printf '%s\n' "$PORT" | grep -c .) punti: $(printf '%s\n' "$PORT" | head -3 | tr '\n' ';')"
else add ok "Nessun comando GNU assente su macOS (timeout, date con -d, grep -P, readlink -f) negli script e nelle istruzioni"; fi
NOHB=""; NPL=0
for f in "${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}/$METIS_LABEL".*.plist; do
  [ -f "$f" ] || continue; NPL=$((NPL+1))
  P=$(plutil -extract EnvironmentVariables.PATH raw "$f" 2>/dev/null) || { NOHB="$NOHB $(basename "$f" .plist)"; continue; }
  case ":$P:" in *:/opt/homebrew/bin:*) ;; *) NOHB="$NOHB $(basename "$f" .plist)" ;; esac
done
if [ -n "$NOHB" ]; then add warn "LaunchAgent di $METIS_PRODOTTO con PATH senza /opt/homebrew/bin (python3, ffmpeg, jq di Homebrew non trovati):$NOHB"
elif [ "$NPL" -gt 0 ]; then add ok "I $NPL LaunchAgent di $METIS_PRODOTTO hanno /opt/homebrew/bin nel PATH"
else add info "Nessun LaunchAgent di $METIS_PRODOTTO installato"; fi

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

# --- Cartelle dei documenti (23/10/2026): una cartella per lavoro, con _IN, _fonti e _OUT (CLAUDE.md, «una cartella per lavoro») ---
# Solo avvisi. Si guardano i file sciolti nelle radici e le cartelle dei lavori aperti (fonte-primaria degli stati non
# archiviati): le cartelle che il cliente aveva prima di Metis non si giudicano.
# Con i documenti accanto alle note (default) le radici sono le cartelle dei progetti, delle aree e delle risorse del vault;
# lì le note (.md) nella radice non contano come sciolte (indici, note di cartella): contano i documenti. Con
# METIS_DOCUMENTI=separati la radice è la cartella fonti fuori dal vault, e conta ogni file.
FONTI="${METIS_FONTI%/}"
if [ "${METIS_DOCUMENTI:-accanto}" = separati ]; then
  sec "Cartella fonti"
  RADICI_DOC=("$FONTI"); NOME_RADICE="della cartella fonti"; SOLO_DOC=0
else
  sec "Cartelle dei documenti"
  RADICI_DOC=("$FONTI"); NOME_RADICE="di $METIS_RUOLO_PROGETTI"; SOLO_DOC=1
  for r in AREE RISORSE; do d=$(metis_ruolo "$r"); [ -n "$d" ] && [ -d "$d" ] && [ "$d" != "$FONTI" ] && RADICI_DOC+=("$d"); done
  [ "${#RADICI_DOC[@]}" -gt 1 ] && NOME_RADICE="delle cartelle dei progetti, delle aree e delle risorse"
fi
sciolti() {  # file sciolti nelle radici: nome della radice relativo al vault, poi il file
  for r in "${RADICI_DOC[@]}"; do
    [ -d "$r" ] || continue
    if [ "$SOLO_DOC" = 1 ]; then find "$r" -maxdepth 1 -type f ! -name ".*" ! -name "*.md" 2>/dev/null
    else find "$r" -maxdepth 1 -type f ! -name ".*" 2>/dev/null; fi
  done
}
if [ ! -d "$FONTI" ]; then
  if [ "$SOLO_DOC" = 1 ]; then add info "Cartella dei progetti non ancora creata ($FONTI)"
  else add info "Cartella fonti non ancora creata ($FONTI)"; fi
else
  NSCIOLTI=$(sciolti | conta)
  if [ "$NSCIOLTI" -gt 0 ]; then
    if [ "$SOLO_DOC" = 1 ]; then DEST="nella cartella del loro lavoro o della loro area, o nelle risorse per tema"
    else DEST="nella cartella del loro lavoro o in _Risorse/<tema>/"; fi
    add warn "$NSCIOLTI file sciolti nella radice $NOME_RADICE, da portare $DEST: $(sciolti | sed 's#.*/##' | sort | head -3 | tr '\n' ';')"
  else add ok "Nessun file sciolto nella radice $NOME_RADICE"; fi
  SENZA=""; NLAV=0
  for s in "$CL"/stati/*.md; do
    case "$(basename "$s")" in _*) continue ;; esac
    [ -f "$s" ] || continue
    fp=$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f && /^fonte-primaria:/ {sub(/^fonte-primaria:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, ""); print}' "$s" | tr -d "'\"")
    [ -n "$fp" ] || continue
    case "$fp" in /*) d="$fp" ;; "~"*) d="$HOME${fp#\~}" ;; *) d="$FONTI/$fp"; [ "$SOLO_DOC" = 1 ] && [ ! -d "$d" ] && d="$METIS_VAULT/$fp" ;; esac
    d="${d%/}"
    dentro=""; base=""
    for r in "${RADICI_DOC[@]}"; do case "$d/" in "$r"/?*) dentro=1; base="$r"; break ;; esac; done
    [ -n "$dentro" ] || continue                        # fuori dalle radici dei documenti: non si giudica
    [ -n "$base" ] && [ "$base" = "$(metis_ruolo RISORSE)" ] && continue   # un tema delle risorse non è un lavoro
    [ -d "$d" ] || continue                             # cartella sparita: la segnala la mappa
    NLAV=$((NLAV+1)); manca=""
    for sub in _IN _fonti _OUT; do [ -d "$d/$sub" ] || manca="$manca $sub"; done
    [ -n "$manca" ] && SENZA="$SENZA ${d#"$base"/} (manca$manca);"
  done
  if [ -n "$SENZA" ]; then add warn "Cartelle di lavoro senza la struttura _IN, _fonti, _OUT:$SENZA"
  elif [ "$NLAV" -gt 0 ]; then add ok "Cartelle dei lavori aperti con _IN, _fonti e _OUT ($NLAV)"; fi
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

# Le regole dei permessi contengono il percorso del plugin, che cambia a ogni versione: dopo un aggiornamento vanno
# riscritte, altrimenti i giri automatici si vedono negare gli script del plugin (6/10/2026).
RPERM="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")/permessi-routine.json"
if [ -f "$RPERM" ] && grep -q "/scripts/doctor.sh" "$RPERM" && ! grep -qF "$METIS_ROOT/scripts/doctor.sh" "$RPERM"; then
  add warn "Le regole dei permessi puntano a un'altra versione del plugin: rilanciare bash \"$METIS_ROOT/scripts/installa-permessi.sh\""
fi

# --- Copertura del digest (6/10/2026) ---
# Il digest del mattino appende a cache/digest-copertura.log una riga «AAAA-MM-GG|fonte|motivo» per ogni fonte che non ha
# potuto leggere. Dichiararlo ogni mattina non basta: se la stessa fonte salta 3 giorni su 7, c'è una causa da trovare.
sec "Copertura del digest"
COPLOG="$CL/cache/digest-copertura.log"
if [ ! -f "$COPLOG" ]; then
  add info "Registro di copertura non ancora creato (nasce al primo digest con una fonte saltata)"
else
  COPOUT=$(python3 - "$COPLOG" "$OGGI" <<'PY' 2>/dev/null
import collections, datetime, sys
oggi = datetime.date.fromisoformat(sys.argv[2]); giorni = collections.defaultdict(set)
for l in open(sys.argv[1], encoding="utf-8", errors="ignore"):
    p = l.strip().split("|")
    if len(p) < 2: continue
    try: d = datetime.date.fromisoformat(p[0].strip())
    except ValueError: continue
    if 0 <= (oggi - d).days <= 7: giorni[p[1].strip().lower()].add(d)
for f, ds in sorted(giorni.items()):
    if len(ds) >= 3: print(f"{f}|{len(ds)}")
PY
)
  if [ -n "$COPOUT" ]; then
    while IFS='|' read -r f n; do add warn "Digest: la fonte «${f}» è saltata in ${n} giorni degli ultimi 7: trovare la causa invece di dichiararla ogni mattina"; done <<< "$COPOUT"
  else add ok "Digest: nessuna fonte saltata tre o più volte negli ultimi 7 giorni"; fi
fi

# --- Moduli installati: il controllo di ciascuno (il doctor fa anche da test di conformità) ---
MODULI_INST="$(bash "$METIS_ROOT/scripts/configura.sh" get METIS_MODULI 2>/dev/null)"
if [ -n "$MODULI_INST" ]; then
  sec "Moduli"
  for m in $MODULI_INST; do
    case "$m" in
      voce)   # niente trascrizione ogni mattina: bastano ffmpeg e la chiave protetta
        CG="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")/groq"
        GF="$(bash "$METIS_ROOT/scripts/configura.sh" get METIS_GROQ_FILE 2>/dev/null)"; [ -n "$GF" ] && CG="${GF/#\~/$HOME}"
        if { command -v ffmpeg >/dev/null 2>&1 || [ -x /opt/homebrew/bin/ffmpeg ]; } && [ "$(stat -f %Lp "$CG" 2>/dev/null)" = 600 ]; then add ok "voce: ffmpeg e chiave di Groq presenti"
        else add warn "voce: manca ffmpeg o la chiave di Groq (voce.sh controlla)"; fi ;;
      markitdown|google|microsoft|telegram|routine)
        R=$(bash "$METIS_ROOT/scripts/moduli/$m.sh" controlla 2>/dev/null); RC=$?
        if [ "$RC" = 0 ]; then add ok "$m: controllo superato"
        else add warn "$m: $(printf '%s\n' "$R" | grep '❌' | head -2 | sed 's/^❌ //' | paste -sd ';' - | cut -c1-240)"; fi ;;
    esac
  done
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
