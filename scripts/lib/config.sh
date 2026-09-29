#!/bin/bash
# config.sh — libreria comune di Metis: legge la configurazione, risolve i ruoli delle cartelle,
# misura i tetti del contesto, fa la guardia su Obsidian.
#
# Uso: source "$METIS_ROOT/scripts/lib/config.sh"; metis_carica_config || exit 0
#
# La configurazione è un file di righe CHIAVE=valore (vedi config/config.example).
# Il file si legge riga per riga e non si esegue: sono accettate solo chiavi METIS_[A-Z0-9_]+.
# Percorso: $METIS_CONFIG se definita, altrimenti ~/.config/metis/config.

# Ruoli delle cartelle e valori di default (struttura PARA alla radice del vault).
# La mappatura ruolo → cartella si cambia nella configurazione, mai qui.
METIS_RUOLI="INBOX PROGETTI AREE RISORSE ARCHIVIO PERSONE JOURNAL TEMPLATE CLAUDE RISERVATA"
_metis_default_ruolo() {
  case "$1" in
    INBOX) echo "0 - Inbox" ;;
    PROGETTI) echo "1 - Progetti" ;;
    AREE) echo "2 - Aree" ;;
    RISORSE) echo "3 - Risorse" ;;
    ARCHIVIO) echo "4 - Archivio" ;;
    PERSONE) echo "3 - Risorse/Persone" ;;
    JOURNAL) echo "Journal" ;;
    TEMPLATE) echo "_Extras/_Templates" ;;
    CLAUDE) echo "_Claude" ;;
    RISERVATA) echo "" ;;
  esac
}

# Legge la configurazione ed esporta le variabili. Ritorna 1 se manca il file o il vault.
metis_carica_config() {
  local cfg="${METIS_CONFIG:-$HOME/.config/metis/config}"
  [ -f "$cfg" ] || { METIS_ERRORE="configurazione non trovata: $cfg"; return 1; }
  local riga chiave valore
  while IFS= read -r riga || [ -n "$riga" ]; do
    riga="${riga%%$'\r'}"
    case "$riga" in ''|'#'*) continue ;; esac
    chiave="${riga%%=*}"; valore="${riga#*=}"
    [[ "$chiave" =~ ^METIS_[A-Z0-9_]+$ ]] || continue
    [ "$chiave" = "$riga" ] && continue
    valore="${valore%%[[:space:]]#*}"                       # commento in coda, se staccato da spazio
    valore="${valore#"${valore%%[![:space:]]*}"}"; valore="${valore%"${valore##*[![:space:]]}"}"
    case "$valore" in \"*\") valore="${valore:1:${#valore}-2}" ;; \'*\') valore="${valore:1:${#valore}-2}" ;; esac
    valore="${valore/#\~/$HOME}"
    printf -v "$chiave" '%s' "$valore"; export "$chiave"
  done < "$cfg"

  [ -n "${METIS_VAULT:-}" ] || { METIS_ERRORE="METIS_VAULT non definito in $cfg"; return 1; }
  METIS_VAULT="${METIS_VAULT%/}"
  [ -d "$METIS_VAULT" ] || { METIS_ERRORE="vault non trovato: $METIS_VAULT"; return 1; }

  local r v
  for r in $METIS_RUOLI; do
    v="METIS_RUOLO_$r"
    [ -n "${!v+x}" ] || printf -v "$v" '%s' "$(_metis_default_ruolo "$r")"
    export "$v"
  done
  export METIS_PRODOTTO="${METIS_PRODOTTO:-Metis}"
  export METIS_CL="$METIS_VAULT/$METIS_RUOLO_CLAUDE"
  # Memoria di Claude Code del vault: ~/.claude/projects/<percorso con ogni carattere non alfanumerico sostituito da «-»>/memory.
  # Il percorso è la radice del repository git che contiene il vault, se c'è; altrimenti il vault stesso
  # (verificato con Claude Code 2.1.284 il 29/9/2026: con il vault dentro un repository la memoria segue la radice del repository).
  # Regola ricavata dal comportamento osservato, da riverificare a ogni versione; se non torna, si fissa METIS_MEMORY_DIR.
  if [ -z "${METIS_MEMORY_DIR:-}" ]; then
    local base; base=$(git -C "$METIS_VAULT" rev-parse --show-toplevel 2>/dev/null) || base="$METIS_VAULT"
    METIS_MEMORY_DIR="$HOME/.claude/projects/$(printf '%s' "$base" | sed 's/[^A-Za-z0-9]/-/g')/memory"
  fi
  export METIS_MEMORY_DIR
  export METIS_FONTI="${METIS_FONTI:-$HOME/Documents/Fonti}"
  export METIS_INBOX_FONTI="${METIS_INBOX_FONTI-Clippings files voicenotes}"   # vuoto = Inbox senza sottocartelle
  export METIS_FRONTMATTER_CHIAVI="${METIS_FRONTMATTER_CHIAVI:-created_at tags up}"
  export METIS_TAG_PREFISSI="${METIS_TAG_PREFISSI-tipo argomento contenuto status}"
  export METIS_LABEL="${METIS_LABEL:-com.metis.$(id -un)}"
  export METIS_JOBS="${METIS_JOBS-daily-digest inbox-processor}"
  export METIS_LOG_DIR="${METIS_LOG_DIR:-$HOME/Library/Logs/metis}"
  return 0
}

# Percorso assoluto di un ruolo: metis_ruolo INBOX → /…/vault/0 - Inbox. Vuoto se il ruolo non è assegnato.
metis_ruolo() {
  local v="METIS_RUOLO_$1"
  [ -n "${!v:-}" ] && printf '%s/%s\n' "$METIS_VAULT" "${!v}"
}

# Vero se il percorso dato sta dentro il vault configurato.
metis_dentro_vault() {
  local p="${1%/}"
  [ -n "$p" ] || return 1
  p="$(cd "$p" 2>/dev/null && pwd -P)" || return 1
  local v; v="$(cd "$METIS_VAULT" 2>/dev/null && pwd -P)" || return 1
  case "$p/" in "$v"/*) return 0 ;; esac
  return 1
}

# Corpo di un file markdown senza il frontmatter.
metis_senza_frontmatter() {
  awk 'NR==1 && $0=="---"{fm=1; next} fm && $0=="---"{fm=0; next} !fm' "$1"
}

# Sezione di _Claude.md iniettata all'avvio: da «## Stato attuale» alla fine del file.
metis_stato_attuale() {
  awk '/^## Stato attuale/{p=1} p' "$METIS_CL/_Claude.md" 2>/dev/null
}

# Tetti dalla tabella «Tetti del contesto» di _Claude.md: una riga «etichetta<TAB>tetto» per voce.
# Si legge solo quella sezione, perché la tabella precedente del file ha etichette simili.
metis_tetti() {
  awk -F'|' '
    /^## /{ s = ($0 ~ /^## Tetti del contesto/) }
    s && NF >= 4 {
      e=$2; t=$3; gsub(/^[ \t]+|[ \t]+$/, "", e); gsub(/[ \t.]/, "", t)
      if (t ~ /^[0-9]+$/) print e "\t" t
    }' "$METIS_CL/_Claude.md" 2>/dev/null
}

# Caratteri misurati per un'etichetta della tabella dei tetti. Vuoto se l'etichetta non è riconosciuta.
metis_misura() {
  local e="$1" f=""
  case "$e" in
    *"Stato attuale"*) metis_stato_attuale | wc -m | tr -d ' '; return ;;
    *hook*) echo '{}' | CLAUDE_PROJECT_DIR="$METIS_VAULT" bash "$METIS_ROOT/hooks/session-orient.sh" 2>/dev/null | wc -m | tr -d ' '; return ;;
    *profilo-nucleo.md*) f="$METIS_CL/profilo-nucleo.md" ;;
    *regole-di-metodo-strumenti.md*) f="$METIS_CL/regole-di-metodo-strumenti.md" ;;
    *regole-di-metodo.md*) f="$METIS_CL/regole-di-metodo.md" ;;
    *MEMORY.md*) f="$METIS_MEMORY_DIR/MEMORY.md" ;;
    *CLAUDE.md*)   # tutto ciò che Claude Code carica: CLAUDE.md più CLAUDE.local.md, se c'è
      cat "$METIS_VAULT/CLAUDE.md" "$METIS_VAULT/CLAUDE.local.md" 2>/dev/null | wc -m | tr -d ' '; return ;;
  esac
  [ -n "$f" ] && [ -f "$f" ] && wc -m < "$f" | tr -d ' '
}

# Segnaposto COMPILARE rimasti nei file che l'onboarding deve riempire.
# Contano solo i due marcatori («<!-- COMPILARE» e «{{COMPILARE»): la parola nuda compare anche nella prosa dei modelli.
metis_compilare_residui() {
  cat "$METIS_VAULT/CLAUDE.md" "$METIS_CL/profilo-nucleo.md" "$METIS_CL/profilo-completo.md" 2>/dev/null | grep -oE '<!-- COMPILARE|\{\{COMPILARE' | wc -l | tr -d ' '
}

# Guardia su Obsidian: il binario `obsidian` è l'app, e ad app chiusa la invocazione la avvia e non ritorna.
# Si chiama prima di ogni comando `obsidian`; se torna 1 si scrive sui file e si dichiara che i wikilink non sono aggiornati.
metis_obsidian_aperto() {
  pgrep -f "Obsidian.app/Contents/MacOS/[Oo]bsidian" >/dev/null 2>&1
}

# Date: macOS (date -v) con ripiego GNU.
metis_data_rel() {  # metis_data_rel -1d  → YYYY-MM-DD
  date -v"$1" '+%Y-%m-%d' 2>/dev/null || date -d "${1/d/ day}" '+%Y-%m-%d'
}
metis_mese_prec() { date -v-1m '+%Y-%m' 2>/dev/null || date -d '1 month ago' '+%Y-%m'; }
metis_epoch() { date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null || echo 0; }
