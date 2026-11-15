#!/bin/bash
# guardia.sh — hook PreToolUse di Metis. Tre protezioni (più l'instradamento della posta e i limiti dei giri automatici),
# nelle sessioni del vault configurato; nelle altre cartelle del Mac solo la prima:
#   1. percorsi protetti (riservata.py): la cartella riservata e i file delle credenziali di Metis → bloccati (deny);
#   2. azioni irreversibili: cancellazioni ricorsive, cestino di Obsidian, push, reset, scaricamento dei LaunchAgent → conferma (ask);
#   3. invii verso l'esterno: strumenti di posta e messaggistica che mandano, inoltrano o rispondono; eventi di calendario
#      con invitati e risposte agli inviti; condivisioni di file e cartelle (Drive); cancellazioni e cestino degli
#      strumenti MCP (delete, trash, remove_file, empty_trash, batch_delete) → conferma (ask), tranne le bozze.
# L'azione si riconosce dalla fine del nome dello strumento: nell'app di Claude i connettori si chiamano
# mcp__<identificativo>__<azione>, non mcp__claude_ai_<servizio>__<azione> come in Claude Code (verificato il 23/10/2026).
# Le bozze restano libere: crearle, modificarle e cancellarle (decisione del 23/10/2026). In una sessione non interattiva (claude -p) una richiesta di conferma equivale a un blocco:
# è il comportamento voluto per i giri automatici (verificato con Claude Code 2.1.284).
# Uscita: JSON hookSpecificOutput sullo stdout quando decide; niente output quando lascia passare.

export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
METIS_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
INPUT=$(cat 2>/dev/null)
metis_carica_config || exit 0

# Senza python3 (su un macOS senza Command Line Tools c'è solo un rimando all'installazione) la guardia non sa leggere
# l'evento. Invece di lasciar passare tutto in silenzio fallisce chiusa: chiede conferma per la shell e per ogni
# strumento MCP, blocca ciò che nomina la cartella riservata e lascia passare il resto.
if ! python3 -c '' >/dev/null 2>&1; then
  campo() { printf '%s' "$INPUT" | tr '\n' ' ' | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }
  TOOL=$(campo tool_name); CWD=$(campo cwd)
  metis_dentro_vault "${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}" || exit 0
  chiuso() { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$2"; exit 0; }
  if [ -n "${METIS_RUOLO_RISERVATA:-}" ]; then
    piano=$(printf '%s' "$INPUT" | tr -d "\"'\\\\" | tr '[:upper:]' '[:lower:]'); rpiano=$(printf '%s' "${METIS_RUOLO_RISERVATA%/}" | tr '[:upper:]' '[:lower:]')
    case "$piano" in *"$rpiano"*) chiuso deny "Cartella riservata (${METIS_RUOLO_RISERVATA%/}): Claude non la legge, non la cerca e non la elenca." ;; esac
  fi
  case "$TOOL" in
    Bash|mcp__*|"") chiuso ask "Manca python3, quindi la guardia non riesce a controllare ${TOOL:-questo strumento}: serve la conferma del cliente. Rimedio: xcode-select --install, poi riaprire Claude Code." ;;
  esac
  exit 0
fi

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
# Invitati: ogni campo il cui nome parla di invitati, a qualunque profondità (attendees, addAttendees, addedAttendees,
# addedAttendeeEmails, attendeeEmails, invitees, guests…): i connettori cambiano i nomi (revisione del 15/11/2026).
def invitati(x):
    if isinstance(x, dict):
        return any((re.search(r"attendee|invitee|guest", str(k), re.I) and v) or invitati(v) for k, v in x.items())
    if isinstance(x, list):
        return any(invitati(v) for v in x)
    return False
import re
print("INVITATI=" + ("1" if invitati(ti) else ""))
print("URL=" + shlex.quote(str(ti.get("url", "")) if isinstance(ti, dict) else ""))
' 2>/dev/null)"

# La sessione è del vault se lavora nel vault (cartella di lavoro dell'evento o cartella del progetto di Claude Code) o
# nella cartella fonti fuori dal vault (METIS_DOCUMENTI=separati). Prima del 15/11/2026 la guardia guardava solo la
# cartella di lavoro: dopo un «cd» nella cartella fonti si spegneva del tutto. Nelle altre cartelle del Mac restano solo
# i percorsi protetti (modo «fuori»): la cartella riservata del vault raggiunta per percorso e i file delle credenziali.
MODO=fuori
if metis_dentro_vault "${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}" || { [ -n "${CLAUDE_PROJECT_DIR:-}" ] && metis_dentro_vault "$CLAUDE_PROJECT_DIR"; }; then
  MODO=dentro
elif [ "${METIS_DOCUMENTI:-}" = separati ] && [ -n "${METIS_FONTI:-}" ] && [ -d "$METIS_FONTI" ]; then
  F_=$(cd "$METIS_FONTI" && pwd -P); C_=$(cd "${CWD:-$PWD}" 2>/dev/null && pwd -P)
  case "$C_/" in "$F_"/*) MODO=dentro ;; esac
fi
# File delle credenziali che Metis e i suoi moduli creano (rilievo della revisione del 15/11/2026).
CFGD="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")"
SEGRETI="$CFGD/telegram:$CFGD/claude-oauth-token:$CFGD/groq:$CFGD/groq-api-key:$CFGD/riunioni-segreto:$HOME/.config/metis-attesa:${XDG_CONFIG_HOME:-$HOME/.config}/google-workspace-mcp:$HOME/.config/rclone:$HOME/.claude/.credentials.json${METIS_GROQ_FILE:+:$METIS_GROQ_FILE}${METIS_CLAUDE_TOKEN_FILE:+:$METIS_CLAUDE_TOKEN_FILE}"

decidi() {  # decidi deny|ask "motivo"
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":sys.argv[1],"permissionDecisionReason":sys.argv[2]}}, ensure_ascii=False))' "$1" "$2"
  exit 0
}

# 1. Percorsi protetti (riservata.py): la cartella riservata, in qualunque forma il comando ci arrivi (virgolette, caratteri
# jolly, maiuscole, collegamenti, cd), e le ricerche ricorsive nella shell che la attraversano senza escluderla; i file
# delle credenziali di Metis. Gli strumenti Grep e Glob di Claude la escludono già con le regole deny (verificato il 29/9/2026).
ESITO=$(GUARDIA_EVENTO="$INPUT" GUARDIA_SEGRETI="$SEGRETI" python3 "$METIS_ROOT/hooks/riservata.py" "$TOOL" "${CWD:-$PWD}" "$METIS_VAULT" "${METIS_RUOLO_RISERVATA:-}" "$MODO" 2>/dev/null)
RIS="${METIS_RUOLO_RISERVATA%/}"
case "$ESITO" in
  nega) decidi deny "Cartella riservata ($RIS): Claude non la legge, non la cerca e non la elenca. Se il cliente lo chiede esplicitamente, va chiesta conferma e l'accesso lo fa lui." ;;
  ricerca) decidi deny "Ricerca che attraversa la cartella riservata ($RIS). Escluderla (grep --exclude-dir=$RIS, find … -not -path '*$RIS*', rg -g '!$RIS'), cercare in una sottocartella, oppure usare lo strumento Grep, che la esclude già." ;;
  segreto) decidi deny "File delle credenziali (token di Claude e del bot, chiavi, posta, sincronizzazione): Claude non li legge e non li copia. Gli script del plugin li usano per conto loro." ;;
esac
[ "$MODO" = dentro ] || exit 0

# 2. Azioni irreversibili nei comandi di shell.
if [ "$TOOL" = "Bash" ] && [ -n "$CMD" ]; then
  C=" $(printf '%s' "$CMD" | tr '\n' ' ') "
  # Cancellazioni ricorsive o di massa in ogni forma (revisione del 15/11/2026): «rm -f -r», «/bin/rm -rf», «\rm -r»,
  # «xargs rm», «find … -delete», «find … -exec rm». Il rm di un singolo file resta libero.
  if printf '%s' "$C" | grep -Eq '[[:space:];&|(`/\\]rm([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)[[:space:];&|)]' \
     || printf '%s' "$C" | grep -Eq '(^|[[:space:];&|(`/])find[[:space:]].*(-delete|-exec(dir)?[[:space:]]+[^[:space:]]*rm([[:space:]]|$)|-ok[[:space:]]+[^[:space:]]*rm[[:space:]])' \
     || printf '%s' "$C" | grep -Eq '(^|[[:space:];&|(`/])xargs([[:space:]]+[^[:space:]]+)*[[:space:]]+[^[:space:]]*rm([[:space:]]|$)'; then
    decidi ask "Cancellazione ricorsiva o di molti file: serve la conferma del cliente. Alternativa: spostare in una cartella di quarantena."
  fi
  # Giri automatici (METIS_GIRO, da metis-agent.sh): nessun comando di rete. Le regole delle routine già non li ammettono;
  # questo vale anche se una regola li ammettesse per sbaglio.
  if [ -n "${METIS_GIRO:-}" ] && printf '%s' "$C" | grep -Eq '(^|[[:space:];&|(`/])(curl|wget|nc|ncat|netcat|socat|telnet|ssh|scp|sftp|ftp|rsync|aria2c|http|https)[[:space:]]'; then
    decidi deny "Giro automatico: niente comandi di rete. Le pagine dei link si leggono con WebFetch, solo per i link già nell'Inbox."
  fi
  printf '%s' "$C" | grep -Eq 'obsidian[[:space:]]+delete' && decidi ask "obsidian delete manda una nota nel cestino: serve la conferma del cliente."
  printf '%s' "$C" | grep -Eq 'git[[:space:]]+(push|reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f)' && decidi ask "Operazione git che pubblica o cancella: serve la conferma del cliente."
  printf '%s' "$C" | grep -Eq 'launchctl[[:space:]]+(bootout|unload|remove)|systemctl[[:space:]]+(--user[[:space:]]+)?(stop|disable|mask|kill)' && decidi ask "Scaricare un'automazione la ferma: serve la conferma del cliente."
  printf '%s' "$C" | grep -Eq '(^|[[:space:];&|])sudo[[:space:]]' && decidi deny "Comandi con sudo: fuori da ciò che Claude fa sul Mac del cliente."
fi

# 2b. Posta dal server locale (METIS_POSTA=locale, modulo google «posta locale»): il connettore Gmail di claude.ai si
# rifiuta e si rimanda al server, le cui regole stanno per nome nelle impostazioni del vault. Il connettore si riconosce
# dal nome: mcp__claude_ai_Gmail__… in Claude Code, mcp__<identificativo UUID>__<azione del connettore> nell'app.
# Calendar e Drive di claude.ai restano liberi (gli invii li ferma il punto 3).
if [ "${METIS_POSTA:-connettori}" = locale ]; then
  case "$TOOL" in
    mcp__claude_ai_Gmail__*) CONN_GMAIL=1 ;;
    mcp__*__*)
      SRV=$(printf '%s' "$TOOL" | sed -n 's/^mcp__\(.*\)__[^_][^_]*.*$/\1/p' | sed 's/__.*//')
      if printf '%s' "$SRV" | grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
        case "${TOOL##*__}" in
          send_message|reply|forward|create_draft|update_draft|delete_draft|get_draft|list_drafts|search_threads|get_thread|get_message|\
          list_labels|create_label|update_label|delete_label|label_message|label_thread|unlabel_message|unlabel_thread|update_message_labels|\
          trash_message|trash_thread|untrash_message|untrash_thread|mark_message_spam|mark_thread_spam|unmark_message_spam|unmark_thread_spam|\
          apply_sensitive_message_label|apply_sensitive_thread_label) CONN_GMAIL=1 ;;
        esac
      fi ;;
  esac
  [ -n "${CONN_GMAIL:-}" ] && decidi deny "La posta di questo vault passa dal server locale (strumenti mcp__gmail-locale__…: search_emails, read_email, download_attachment, draft_email; bozze con allegati: scripts/gmail-bozza.mjs del plugin), non dal connettore Gmail di claude.ai."
fi

# 2c. WebFetch nei giri automatici (revisione del 15/11/2026): un contenuto di terzi lavorato dal giro potrebbe chiedere
# di aprire un indirizzo costruito apposta, con dentro dati del vault. Nel giro si aprono solo i link che erano già scritti
# in una nota dell'Inbox prima che il giro partisse (METIS_GIRO_INIZIO), più gli indirizzi di METIS_RETE_CONSENTITI
# (nomi di host separati da spazi). Nelle sessioni con il cliente WebFetch resta libero.
if [ -n "${METIS_GIRO:-}" ] && [ "$TOOL" = WebFetch ]; then
  OK_=$(python3 - "$URL" "$(metis_ruolo INBOX)" "${METIS_GIRO_INIZIO:-0}" "${METIS_RETE_CONSENTITI:-}" <<'PYW' 2>/dev/null
import os, sys, urllib.parse
url, inbox, inizio, consentiti = sys.argv[1], sys.argv[2], float(sys.argv[3] or 0), sys.argv[4].split()
u = urllib.parse.urlsplit(url)
host = (u.hostname or "").lower()
if host and any(host == h.lower() or host.endswith("." + h.lower()) for h in consentiti):
    print("si"); sys.exit()
senza = url.split("#")[0]
varianti = {senza, senza.rstrip("/"), senza.replace("https://", "http://", 1), senza.replace("http://", "https://", 1)}
varianti |= {v.rstrip("/") for v in list(varianti)}
varianti = {v for v in varianti if len(v) > 10}
for d, _, fs in os.walk(inbox):
    for f in fs:
        if not f.endswith(".md"):
            continue
        p = os.path.join(d, f)
        try:
            if inizio and os.path.getmtime(p) >= inizio:
                continue
            t = open(p, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        if any(v in t for v in varianti):
            print("si"); sys.exit()
PYW
)
  [ "$OK_" = si ] || decidi deny "Giro automatico: si aprono solo i link già scritti in una nota dell'Inbox prima del giro. Lascia la nota con il solo link e dillo nel riscontro."
fi

# 3. Invii: strumenti MCP di posta e messaggistica che mandano, inoltrano o rispondono. Le bozze passano.
case "$TOOL" in
  mcp__*)
    AZIONE=$(printf '%s' "${TOOL##*__}" | tr 'A-Z' 'a-z')
    case "$AZIONE" in
      # Cancellazioni e cestino (23/10/2026): prima dell'uscita delle bozze, perché delete_draft contiene «draft».
      # Leggere (elenchi, ricerche, permessi) e ripristinare dal cestino restano liberi.
      list_*|get_*|search_*|read_*|*untrash*|*restore*) ;;
      # Cancellare una bozza è libero come crearla: non parte nulla verso altri (23/10/2026).
      *delete_draft*|*delete_bozza*) exit 0 ;;
      *delete*|*trash*|*remove_file*)
        decidi ask "Cancellazione ($TOOL): toglie un elemento (mail, evento, file) in un servizio esterno. Serve il via esplicito del cliente per questo elemento." ;;
      *draft*|*bozza*) exit 0 ;;
      send*|*_send|*send_*|forward*|*forward*|reply*|*_reply*|*post_message*|*send_message*)
        decidi ask "Invio verso l'esterno ($TOOL): parte solo con il via esplicito del cliente per questo messaggio e questo destinatario." ;;
      # Un evento con invitati manda l'invito a ciascuno; rispondere a un invito avvisa chi l'ha mandato.
      *create_event*|*update_event*|*insert_event*|*patch_event*)
        [ -n "$INVITATI" ] && decidi ask "Evento con invitati ($TOOL): Google manda l'invito a ciascuno. Serve il via esplicito del cliente per questo evento e questi invitati." ;;
      *respond_to_event*|*rsvp*)
        decidi ask "Risposta a un invito ($TOOL): arriva a chi l'ha mandato. Serve il via esplicito del cliente." ;;
      # Condividere un file dà accesso a un terzo (e di solito gli manda una mail). Leggere i permessi resta libero.
      *get_sharing*|*list_permission*|*get_permission*|*remove_permission*) ;;
      share*|*_share|*_share_*|*add_permission*|*create_permission*)
        decidi ask "Condivisione verso l'esterno ($TOOL): dà accesso al file a un terzo. Serve il via esplicito del cliente per questo file e questo destinatario." ;;
    esac ;;
esac
exit 0
