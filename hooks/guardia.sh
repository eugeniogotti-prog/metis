#!/bin/bash
# guardia.sh — hook PreToolUse di Metis. Tre protezioni (più l'instradamento della posta), solo dentro il vault configurato:
#   1. cartella riservata: ogni strumento che la tocca viene bloccato (deny);
#   2. azioni irreversibili: cancellazioni ricorsive, cestino di Obsidian, push, reset, scaricamento dei LaunchAgent → conferma (ask);
#   3. invii verso l'esterno: strumenti di posta e messaggistica che mandano, inoltrano o rispondono; eventi di calendario
#      con invitati e risposte agli inviti; condivisioni di file e cartelle (Drive); cancellazioni e cestino degli
#      strumenti MCP (delete, trash, remove_file, empty_trash, batch_delete) → conferma (ask).
# L'azione si riconosce dalla fine del nome dello strumento: nell'app di Claude i connettori si chiamano
# mcp__<identificativo>__<azione>, non mcp__claude_ai_<servizio>__<azione> come in Claude Code (verificato il 23/10/2026).
# Le bozze restano libere. In una sessione non interattiva (claude -p) una richiesta di conferma equivale a un blocco:
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
    case "$INPUT" in *"${METIS_RUOLO_RISERVATA%/}"*) chiuso deny "Cartella riservata (${METIS_RUOLO_RISERVATA%/}): Claude non la legge, non la cerca e non la elenca." ;; esac
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
inv = [ti.get(k) for k in ("attendees", "attendee", "invitees", "guests", "addAttendees")] if isinstance(ti, dict) else []
print("INVITATI=" + ("1" if any(v for v in inv) else ""))
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

# 1b. Ricerche ricorsive nella shell (grep -r, rg, ag, find) che partono da una cartella che contiene quella riservata
# senza escluderla. Gli strumenti Grep e Glob di Claude la escludono già con le regole deny (verificato il 29/9/2026).
if [ -n "${METIS_RUOLO_RISERVATA:-}" ] && [ "$TOOL" = "Bash" ] && [ -n "$CMD" ]; then
  ESITO=$(python3 - "$CMD" "${CWD:-$PWD}" "$METIS_VAULT" "${METIS_RUOLO_RISERVATA%/}" <<'PY2'
import os, shlex, sys
cmd, cwd, vault, ris = sys.argv[1:]
ris_abs = os.path.realpath(os.path.join(vault, ris))
try:
    parole = shlex.split(cmd, posix=True)
except ValueError:
    parole = cmd.split()
# si spezza la riga in comandi semplici
comandi, cur = [], []
for p in parole:
    if p in ("|", "||", "&&", ";", "&"):
        comandi.append(cur); cur = []
    else:
        cur.append(p)
comandi.append(cur)
def contiene(percorso):
    a = os.path.realpath(os.path.join(cwd, os.path.expanduser(percorso)))
    return ris_abs == a or ris_abs.startswith(a.rstrip("/") + "/")
def svolgi(c):
    """Toglie gli involucri davanti al comando vero (6/10/2026): con-timeout.sh SECONDI, bash/sh <script>, env VAR=…,
    nice, command, time, sudo è già bloccato altrove. Senza, `bash con-timeout.sh 90 find …` non veniva controllato."""
    while c:
        b = os.path.basename(c[0])
        if b in ("bash", "sh", "zsh") and len(c) > 1 and os.path.basename(c[1]) == "con-timeout.sh":
            c = c[3:]
        elif b == "con-timeout.sh":
            c = c[2:]
        elif b in ("env", "nice", "command", "time", "nohup"):
            c = c[1:]
            while c and ("=" in c[0] and not c[0].startswith("-") or c[0].startswith("-")):
                c = c[1:]
        elif "=" in c[0] and not c[0].startswith("-") and os.path.basename(c[0].split("=")[0]) == c[0].split("=")[0]:
            c = c[1:]                     # VAR=valore davanti al comando
        else:
            return c
    return c
for c in comandi:
    c = svolgi(c)
    if not c: continue
    nome = os.path.basename(c[0])
    if nome not in ("grep", "egrep", "rg", "ag", "find"): continue
    if ris in " ".join(c[1:]):          # la cartella è nominata: è un'esclusione (o la regola 1 ha già deciso)
        continue
    if nome == "find":
        percorsi, args = [], c[1:]
        # opzioni che stanno PRIMA dei percorsi (BSD e GNU): -H -L -P -E -X -d -s -x, -f <percorso>, -O<livello>
        while args and (args[0] in ("-H", "-L", "-P", "-E", "-X", "-d", "-s", "-x") or args[0].startswith("-O") or args[0] == "-f"):
            if args[0] == "-f" and len(args) > 1:
                percorsi.append(args[1]); args = args[2:]
            else:
                args = args[1:]
        for a in args:
            if a.startswith("-") or a in ("(", "!", ")"): break
            percorsi.append(a)
        percorsi = percorsi or ["."]
    else:
        ricorsivo = nome in ("rg", "ag") or any(a.startswith("-") and not a.startswith("--") and ("r" in a or "R" in a) for a in c[1:]) or "--recursive" in c
        if not ricorsivo: continue
        non_opz = [a for a in c[1:] if not a.startswith("-")]
        percorsi = non_opz[1:] or ["."]      # il primo argomento non opzione è il pattern
    if any(contiene(p) for p in percorsi):
        print("nega"); sys.exit(0)
PY2
)
  [ "$ESITO" = nega ] && decidi deny "Ricerca che attraversa la cartella riservata (${METIS_RUOLO_RISERVATA%/}). Escluderla (grep --exclude-dir=${METIS_RUOLO_RISERVATA%/}, find … -not -path '*${METIS_RUOLO_RISERVATA%/}*', rg -g '!${METIS_RUOLO_RISERVATA%/}'), cercare in una sottocartella, oppure usare lo strumento Grep, che la esclude già."
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

# 3. Invii: strumenti MCP di posta e messaggistica che mandano, inoltrano o rispondono. Le bozze passano.
case "$TOOL" in
  mcp__*)
    AZIONE=$(printf '%s' "${TOOL##*__}" | tr 'A-Z' 'a-z')
    case "$AZIONE" in
      # Cancellazioni e cestino (23/10/2026): prima dell'uscita delle bozze, perché delete_draft contiene «draft».
      # Leggere (elenchi, ricerche, permessi) e ripristinare dal cestino restano liberi.
      list_*|get_*|search_*|read_*|*untrash*|*restore*) ;;
      *delete*|*trash*|*remove_file*)
        decidi ask "Cancellazione ($TOOL): toglie un elemento (mail, bozza, evento, file) in un servizio esterno. Serve il via esplicito del cliente per questo elemento." ;;
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
