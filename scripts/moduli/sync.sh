#!/bin/bash
# sync.sh — modulo sincronizzazione: tiene allineate sul server le cartelle di lavoro del cliente che stanno in un cloud
# (Google Drive, OneDrive, SharePoint, ogni remoto di rclone), nei due versi, con rclone bisync.
# Per i file che stanno solo sul computer del cliente la strada è Syncthing (fra il suo computer e il server): non è qui.
#
# Uso:
#   sync.sh aggiungi <remoto:percorso> <cartella locale>   una coppia da tenere allineata (il remoto si crea prima con
#                                                           «rclone config», con il cliente: serve il suo consenso)
#   sync.sh togli <cartella locale>                         smette di allinearla (i file restano dove sono)
#   sync.sh elenco                                          le coppie
#   sync.sh giro                                            un giro su tutte le coppie (lo fa l'automatismo)
#   sync.sh installa                                        l'automatismo, ogni METIS_SYNC_MINUTI minuti (default 5)
#   sync.sh controlla                                       coppie, ultimo giro riuscito, conflitti
#
# Prudenze:
# - Versioni: ogni file locale sovrascritto o cancellato da un giro si conserva in <cartella delle versioni>/<coppia>/<data>/
#   (METIS_SYNC_VERSIONI, default ~/.local/share/metis/sync-versioni) per METIS_SYNC_GIORNI giorni (default 30).
#   Dal lato del cloud valgono le versioni e il cestino del servizio.
# - Esclusioni: file temporanei e di sistema (.DS_Store, ~$*, .~lock.*, *.tmp, Icon\r), e i documenti nativi di Google
#   (Documenti, Fogli: restano solo nel cloud).
# - Se in un giro sparirebbe più della metà dei file, rclone si ferma (protezione di bisync) e il controllo lo segnala.
# - Conflitti (file cambiato nei due posti): vince il più recente, l'altro resta accanto con «sync-conflict» nel nome.
# - Un giro alla volta (blocco); l'ora dell'ultimo giro riuscito va in <cartella della configurazione>/sync-ultimo, letta
#   dal controllo giornaliero.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "sync: ${METIS_ERRORE}" >&2; exit 2; }
CFG_DIR="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
COPPIE="$CFG_DIR/sync-coppie"            # righe «remoto:percorso<TAB>cartella locale»
STATO="$CFG_DIR/sync-stato"; mkdir -p "$STATO"
VERS="${METIS_SYNC_VERSIONI:-$HOME/.local/share/metis/sync-versioni}"
RCLONE="${METIS_RCLONE:-$(command -v rclone || echo /usr/bin/rclone)}"
LOG="$METIS_LOG_DIR/sync.log"; mkdir -p "$METIS_LOG_DIR"
ESCLUDI=(--exclude .DS_Store --exclude 'Icon?' --exclude '~$*' --exclude '.~lock.*' --exclude '*.tmp' --exclude '.tmp.drive*')
chiave() { printf '%s' "$1" | cksum | cut -d' ' -f1; }   # nome breve e stabile di una coppia

case "${1:-}" in
  aggiungi)
    R="${2:?manca il remoto (es. drive:Lavoro)}"; L="${3:?manca la cartella locale}"
    [[ "$R" == *:* ]] || { echo "sync: «${R}» non è un remoto di rclone (nome:percorso)" >&2; exit 2; }
    "$RCLONE" listremotes 2>/dev/null | grep -qx "${R%%:*}:" || [ -n "${METIS_SYNC_SENZA_REMOTI:-}" ] \
      || { echo "sync: il remoto «${R%%:*}» non c'è: prima rclone config, con il cliente" >&2; exit 1; }
    L="$(mkdir -p "$L" && cd "$L" && pwd -P)"
    touch "$COPPIE"; chmod 600 "$COPPIE"
    grep -q "	$L\$" "$COPPIE" && { echo "sync: $L è già allineata"; exit 0; }
    printf '%s\t%s\n' "$R" "$L" >> "$COPPIE"
    echo "sync: $R ⇄ $L aggiunta; il primo giro confronta tutto (--resync) e può durare" ;;
  togli)
    L="$(cd "${2:?manca la cartella locale}" 2>/dev/null && pwd -P || echo "$2")"
    grep -v "	$L\$" "$COPPIE" > "$COPPIE.tmp" 2>/dev/null; mv "$COPPIE.tmp" "$COPPIE"
    rm -f "$STATO/pronta-$(chiave "$L")"; echo "sync: $L non è più allineata (i file restano)" ;;
  elenco)
    [ -s "$COPPIE" ] && sed 's/	/ ⇄ /' "$COPPIE" || echo "nessuna coppia" ;;
  giro)
    [ -s "$COPPIE" ] || exit 0
    exec 9>"$STATO/blocco"
    if command -v flock >/dev/null; then flock -n 9 || { echo "[$(date '+%F %T')] giro precedente ancora in corso" >> "$LOG"; exit 0; }; fi
    ERR=0; OGGI=$(date +%F)
    while IFS=$'\t' read -r R L; do
      [ -n "$R" ] || continue
      K=$(chiave "$L"); P="$STATO/pronta-$K"; EXTRA=()
      [ -f "$P" ] || EXTRA=(--resync)
      "$RCLONE" bisync "$R" "$L" ${EXTRA[@]+"${EXTRA[@]}"} --drive-skip-gdocs "${ESCLUDI[@]}" --resilient --recover \
        --conflict-resolve newer --conflict-suffix sync-conflict --backup-dir2 "$VERS/$K/$OGGI" \
        --workdir "$STATO/rclone-$K" --max-lock 30m --stats 0 --log-level NOTICE >> "$LOG" 2>&1
      RC=$?
      if [ "$RC" = 0 ]; then touch "$P"; else ERR=1; echo "[$(date '+%F %T')] ❌ $R ⇄ $L: rclone esce con $RC" >> "$LOG"; fi
    done < "$COPPIE"
    # versioni oltre il limite: si tolgono le cartelle dei giorni vecchi
    [ -d "$VERS" ] && find "$VERS" -mindepth 2 -maxdepth 2 -type d -mtime +"${METIS_SYNC_GIORNI:-30}" -exec rm -rf {} + 2>/dev/null
    [ "$ERR" = 0 ] && date +%s > "$CFG_DIR/sync-ultimo"
    exit "$ERR" ;;
  installa)
    command -v "$RCLONE" >/dev/null || [ -x "$RCLONE" ] || { echo "sync: manca rclone" >&2; exit 1; }
    bash "$METIS_ROOT/scripts/lib/servizi.sh" genera sync ogni "${METIS_SYNC_MINUTI:-5}" /bin/bash "$METIS_ROOT/scripts/moduli/sync.sh" giro || exit 1
    bash "$METIS_ROOT/scripts/lib/servizi.sh" carica sync || exit 1
    bash "$METIS_ROOT/scripts/configura.sh" aggiungi METIS_MODULI sync >/dev/null
    echo "sync: giro ogni ${METIS_SYNC_MINUTI:-5} minuti" ;;
  controlla)
    ERR=0
    [ -s "$COPPIE" ] && echo "✅ coppie: $(grep -c . "$COPPIE")" || { echo "❌ nessuna coppia (sync.sh aggiungi)"; ERR=1; }
    if [ -f "$CFG_DIR/sync-ultimo" ]; then
      M=$(( ($(date +%s) - $(cat "$CFG_DIR/sync-ultimo")) / 60 ))
      [ "$M" -le 60 ] && echo "✅ ultimo giro riuscito $M minuti fa" || { echo "❌ ultimo giro riuscito $M minuti fa (registro: $LOG)"; ERR=1; }
    else echo "❌ nessun giro riuscito finora (registro: $LOG)"; ERR=1; fi
    N=0; while IFS=$'\t' read -r _ L; do [ -d "$L" ] && N=$((N + $(find "$L" -name '*sync-conflict*' 2>/dev/null | grep -c .))); done < "$COPPIE" 2>/dev/null
    [ "$N" = 0 ] && echo "✅ nessun conflitto" || echo "⚠️ $N file in conflitto (cercare «sync-conflict» nel nome)"
    bash "$METIS_ROOT/scripts/lib/servizi.sh" esiste sync 2>/dev/null && { bash "$METIS_ROOT/scripts/lib/servizi.sh" stato sync >/dev/null && echo "✅ automatismo caricato" || { echo "❌ automatismo non caricato"; ERR=1; }; }
    exit "$ERR" ;;
  *) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
