#!/bin/bash
# metis-server.sh — dal Mac di chi installa: porta un server Ubuntu 24.04 appena creato fino a Metis «gestito» pronto per il
# cliente. Fa da solo tutto ciò che può e si ferma, chiedendo, solo dove serve una persona:
#   👤 login di Claude (link e codice) · 👤 connettori da tenere · 👤 chiave di Groq · 👤 password di FileBrowser ·
#   👤 il codice di abbinamento che il cliente manda al suo bot. (Creare il server e aprire la Scorciatoia sull'iPhone restano fuori dallo script.)
# Si può rilanciare quante volte si vuole: ogni passo controlla prima che cosa c'è già. Guida: docs/server-da-zero.md.
#
# Uso:
#   metis-server.sh --ip <indirizzo> --admin <utente> --nome-cliente "<Nome Cognome>" [opzioni]
# Opzioni:
#   --chiave <file .pub>       chiave SSH dell'amministratore (default ~/.ssh/id_ed25519.pub)
#   --cliente <utente>         utente del cliente sul server (default metis)
#   --token-bot <file>         file locale con il token del bot (@BotFather); si copia sul server e si cancella là dopo l'uso
#   --giri "<lavori>"          giri automatici (default «manutenzione daily-digest inbox-processor daily-sera weekly-digest»)
#   --utente-web <nome>        utente di FileBrowser (default ospite)
#   --dominio <nome dns>       nome per l'HTTPS (default <ip-con-trattini>.sslip.io; su un server già configurato, quello che ha)
#   --uscita <cartella>        dove lasciare la Scorciatoia firmata (default ~/Desktop/metis-<nome-del-cliente>)
#   --senza-domande            non chiede niente: fa i passi automatici e dice quali passi umani mancano
#   --sviluppo                 dopo l'installazione da GitHub, copia sul server questa copia locale di Metis (prove)
# Uscita: 0 tutto fatto · 1 qualcosa da fare (lo dice in fondo) · 2 errore negli argomenti.

set -uo pipefail
QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; RADICE="$(cd "$QUI/../.." && pwd)"
IP=""; ADMIN=""; NOME=""; CHIAVE="$HOME/.ssh/id_ed25519.pub"; CLIENTE="metis"; TOKEN_BOT=""
GIRI="manutenzione daily-digest inbox-processor daily-sera weekly-digest"; UWEB="ospite"; DOMINIO=""; USCITA=""; DOMANDE=1; SVILUPPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ip) IP="${2:-}"; shift 2 ;; --admin) ADMIN="${2:-}"; shift 2 ;; --nome-cliente) NOME="${2:-}"; shift 2 ;;
    --chiave) CHIAVE="${2:-}"; shift 2 ;; --cliente) CLIENTE="${2:-}"; shift 2 ;; --token-bot) TOKEN_BOT="${2:-}"; shift 2 ;;
    --giri) GIRI="${2:-}"; shift 2 ;; --utente-web) UWEB="${2:-}"; shift 2 ;; --dominio) DOMINIO="${2:-}"; shift 2 ;;
    --uscita) USCITA="${2:-}"; shift 2 ;; --senza-domande) DOMANDE=""; shift ;; --sviluppo) SVILUPPO=1; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "metis-server: opzione sconosciuta «$1» (--help)" >&2; exit 2 ;;
  esac
done
[ -n "$IP" ] && [ -n "$ADMIN" ] && [ -n "$NOME" ] || { echo "metis-server: servono --ip, --admin e --nome-cliente (--help)" >&2; exit 2; }
[ -f "$CHIAVE" ] || { echo "metis-server: chiave pubblica non trovata: $CHIAVE" >&2; exit 2; }
[ -z "$TOKEN_BOT" ] || [ -f "$TOKEN_BOT" ] || { echo "metis-server: file del token del bot non trovato: $TOKEN_BOT" >&2; exit 2; }
USCITA="${USCITA:-$HOME/Desktop/metis-$(printf '%s' "$NOME" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')}"
MANCA=()

passo() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
umano() { printf '\n\033[1;33m👤 %s\033[0m\n' "$*"; }
ok() { echo "  ✅ $*"; }; no() { echo "  ❌ $*"; }
chiedi() {  # chiedi "domanda" → 0 se sì; senza domande: no
  [ -n "$DOMANDE" ] || return 1
  local r; read -r -p "  $1 [s/N] " r < /dev/tty; [[ "$r" =~ ^[sS] ]]
}
r_root() { command ssh -o BatchMode=yes -o ConnectTimeout=10 "root@$IP" "$@"; }
r() { command ssh -o BatchMode=yes -o ConnectTimeout=10 "$ADMIN@$IP" "$@"; }
r_tty() { command ssh -t -o ConnectTimeout=10 "$ADMIN@$IP" "$@"; }
cliente() { r "sudo -iu $CLIENTE bash -lc $(printf '%q' "$1")"; }   # un comando come utente del cliente
cliente_tty() { r_tty "sudo -iu $CLIENTE bash -lc $(printf '%q' "$1")"; }
porta() { scp -q "$1" "$ADMIN@$IP:/tmp/$(basename "$1")"; }   # copia uno script locale in /tmp del server

# Nome per l'HTTPS: quello indicato, altrimenti quello che il server ha già, altrimenti <ip-con-trattini>.sslip.io.
if [ -z "$DOMINIO" ]; then
  DOMINIO=$(command ssh -o BatchMode=yes -o ConnectTimeout=10 "$ADMIN@$IP" "sudo awk '/^[^#[:space:]].*\\{\$/ {print \$1; exit}' /etc/caddy/Caddyfile 2>/dev/null" 2>/dev/null)
  DOMINIO="${DOMINIO:-$(printf '%s' "$IP" | tr . -).sslip.io}"
fi

# --- 1. server -------------------------------------------------------------------------------------------------------
# Prima si prova l'amministratore. Root si prova solo se l'amministratore non entra ancora (server appena creato): con root
# chiuso ogni prova è un accesso fallito, e fail2ban blocca l'indirizzo dopo 5 in 10 minuti (successo il 10/11/2026).
passo "1. Preparazione del server ($IP)"
if r "sudo -n true" 2>/dev/null; then
  ok "$ADMIN entra con la chiave e ha sudo: server già preparato"
  porta "$QUI/prepara-vps.sh" && porta "$CHIAVE" && r "sudo bash /tmp/prepara-vps.sh --admin $ADMIN --chiave /tmp/$(basename "$CHIAVE"); rm -f /tmp/prepara-vps.sh /tmp/$(basename "$CHIAVE")" | grep -E '➕|❌|⚠️' | sed 's/^/ /'
elif r_root true 2>/dev/null; then
  scp -q "$QUI/prepara-vps.sh" "root@$IP:/root/prepara-vps.sh" && scp -q "$CHIAVE" "root@$IP:/root/chiave-admin.pub" || { no "copia sul server non riuscita"; exit 1; }
  r_root "bash /root/prepara-vps.sh --admin $ADMIN --chiave /root/chiave-admin.pub" | grep -E '➕|❌|⚠️' | sed 's/^/ /'
  ok "preparazione eseguita come root"
else
  no "né $ADMIN né root entrano con la chiave. Controllare indirizzo e chiave; se le prove fallite sono state molte, fail2ban blocca l'indirizzo per un'ora (console del fornitore: fail2ban-client set sshd unbanip <ip>)"; exit 1
fi

# Durante l'installazione fail2ban non blocca l'indirizzo di questo Mac (tolto in fondo).
MIO_IP=$(curl -s --max-time 10 https://ifconfig.me 2>/dev/null)
if [[ "$MIO_IP" =~ ^[0-9a-fA-F.:]+$ ]]; then
  porta "$QUI/prepara-vps.sh" && r "sudo bash /tmp/prepara-vps.sh --ip-fidato $MIO_IP; rm -f /tmp/prepara-vps.sh" | sed 's/^/ /'
fi

# --- 2. accesso dell'amministratore e chiusura di root --------------------------------------------------------------
passo "2. Accesso dell'amministratore e chiusura di root"
if r "sudo -n true" 2>/dev/null; then ok "$ADMIN entra con la chiave e ha sudo"; else no "$ADMIN non entra o non ha sudo: root resta aperto"; exit 1; fi
# Lo stato di root si legge sul server (sshd -T), senza tentare un accesso.
if [ "$(r "sudo sshd -T 2>/dev/null | awk '/^permitrootlogin/ {print \$2}'")" = no ]; then ok "root già chiuso"
else
  porta "$QUI/prepara-vps.sh" && r "sudo bash /tmp/prepara-vps.sh --chiudi-root; rm -f /tmp/prepara-vps.sh" | sed 's/^/ /'
  [ "$(r "sudo sshd -T 2>/dev/null | awk '/^permitrootlogin/ {print \$2}'")" = no ] && ok "root chiuso (sshd: PermitRootLogin no)" || { no "root non chiuso"; exit 1; }
fi

# --- 3. Metis per il cliente -------------------------------------------------------------------------------------------
passo "3. Metis per il cliente «${NOME}» (utente $CLIENTE)"
porta "$QUI/installa-cliente.sh" && r "sudo install -m 755 -o $CLIENTE -g $CLIENTE /tmp/installa-cliente.sh /home/$CLIENTE/installa-cliente.sh && rm -f /tmp/installa-cliente.sh"
ARG_BOT=""
if [ -n "$TOKEN_BOT" ]; then
  r "sudo -u $CLIENTE bash -c 'umask 077; mkdir -p /home/$CLIENTE/.config/metis-attesa && cat > /home/$CLIENTE/.config/metis-attesa/bot-token'" < "$TOKEN_BOT" \
    && ARG_BOT="--token-bot /home/$CLIENTE/.config/metis-attesa/bot-token" && ok "token del bot copiato (600, solo per $CLIENTE)"
fi
ESEGUI="bash /home/$CLIENTE/installa-cliente.sh --nome $(printf '%q' "$NOME") --giri $(printf '%q' "$GIRI") $ARG_BOT"
cliente "$ESEGUI" 2>&1 | grep -E '➕|❌|⏳|doctor|metis@metis' | sed 's/^/ /'
PLUGIN=$(cliente "python3 -c 'import json,os; print(json.load(open(os.path.expanduser(\"~/.claude/plugins/installed_plugins.json\")))[\"plugins\"][\"metis@metis\"][0][\"installPath\"])'" 2>/dev/null)
[ -n "$PLUGIN" ] || { no "plugin non installato per $CLIENTE"; exit 1; }
if [ -n "$SVILUPPO" ]; then
  rsync -a --delete --exclude .git --exclude prove --exclude banco --exclude '.mandato*' "$RADICE/" "$ADMIN@$IP:/tmp/metis-sviluppo/" \
    && r "sudo rsync -a --chown=$CLIENTE:$CLIENTE /tmp/metis-sviluppo/ $PLUGIN/ && rm -rf /tmp/metis-sviluppo" && ok "copia locale di Metis portata sul server (--sviluppo)"
  cliente "$ESEGUI" >/dev/null 2>&1
fi
ok "plugin in $PLUGIN"
riavvia_sessione() { cliente "tmux kill-session -t metis-principale 2>/dev/null; true"; }

# --- 4. login di Claude 👤 ---------------------------------------------------------------------------------------------
passo "4. Login di Claude"
login_ok() { cliente "env -u CLAUDE_CODE_OAUTH_TOKEN claude auth status 2>/dev/null" | grep -q '"loggedIn": true'; }
if login_ok; then ok "login completo già fatto"
else
  umano "Serve il login completo di Claude, con l'account dell'abbonamento del cliente: si apre un link, si autorizza, si incolla qui il CODICE che la pagina mostra (non è il token)."
  if chiedi "Faccio partire il login adesso?"; then cliente_tty "bash $PLUGIN/scripts/server/login-claude.sh completo"; fi
  if login_ok; then ok "login completo fatto"; riavvia_sessione; else no "login di Claude non fatto"; MANCA+=("login di Claude: rilanciare questo script"); fi
fi
if login_ok && ! cliente "test -s ~/.config/metis/claude-oauth-token"; then
  echo "  Facoltativo: un token di un anno di riserva (solo per giri e bot, se il login completo scade)."
  if chiedi "Creo anche il token di riserva?"; then cliente_tty "bash $PLUGIN/scripts/server/login-claude.sh token"; cliente "$ESEGUI" >/dev/null 2>&1; fi
fi

# --- 5. connettori 👤 ------------------------------------------------------------------------------------------------
passo "5. Connettori dell'account"
if login_ok; then
  cliente "bash $PLUGIN/scripts/server/connettori.sh plugin" | sed 's/^/ /'
  cliente "bash $PLUGIN/scripts/server/connettori.sh elenca" | sed 's/^/    /'
  if [ -n "$DOMANDE" ]; then
    read -r -p "  Quali tengo accesi? Nomi separati da virgole (Invio = nessuno): " TIENI < /dev/tty
    cliente "bash $PLUGIN/scripts/server/connettori.sh tieni $(printf '%q' "$TIENI")" | sed 's/^/ /' && riavvia_sessione
  else echo "  (senza domande: connettori lasciati come sono)"; fi
else echo "  (dopo il login)"; fi

# --- 6. Groq 👤 --------------------------------------------------------------------------------------------------------
passo "6. Chiave di Groq (trascrizione di vocali e riunioni)"
if cliente "test -s ~/.config/metis/groq"; then ok "chiave presente"
else
  umano "Serve una chiave di Groq del cliente (console.groq.com → API Keys): la si incolla qui, non si vede a schermo."
  if chiedi "La inserisco adesso?"; then cliente_tty "bash $PLUGIN/scripts/moduli/voce.sh chiave"; fi
  cliente "test -s ~/.config/metis/groq" && ok "chiave salvata" || { no "chiave di Groq mancante"; MANCA+=("chiave di Groq: voce.sh chiave"); }
fi
cliente "bash $PLUGIN/scripts/moduli/voce.sh controlla" 2>/dev/null | sed 's/^/ /'

# --- 7. HTTPS, FileBrowser, riunioni ------------------------------------------------------------------------------------
passo "7. HTTPS ($DOMINIO), FileBrowser in sola lettura, ingresso delle riunioni"
porta "$QUI/web.sh" && r "sudo bash /tmp/web.sh --nome $DOMINIO --cliente $CLIENTE --utente-web $UWEB; rm -f /tmp/web.sh" 2>&1 | grep -E '➕|❌|https' | sed 's/^/ /'
umano "Password di FileBrowser per l'utente «${UWEB}» (almeno 12 caratteri): la sceglie chi la userà."
if chiedi "La imposto adesso?"; then r_tty "sudo filebrowser-password $UWEB"; else MANCA+=("password di FileBrowser: ssh -t $ADMIN@$IP sudo filebrowser-password $UWEB"); fi

# --- 8. Scorciatoia per l'iPhone -------------------------------------------------------------------------------------
passo "8. Scorciatoia iPhone «Manda riunione»"
if [ "$(uname -s)" = Darwin ] && command -v shortcuts >/dev/null; then
  S=$(mktemp); chmod 600 "$S"
  cliente "python3 $PLUGIN/scripts/server/riunioni.py segreto" > "$S" 2>/dev/null
  python3 "$QUI/scorciatoia.py" --url "https://$DOMINIO/riunione" --segreto "$S" --uscita "$USCITA" | sed 's/^/  /'
  rm -f "$S"
  umano "Mandare «$USCITA/Manda riunione.shortcut» al cliente (AirDrop) e aprirla sul suo iPhone. Per le riunioni: Memo vocali → Condividi → Manda riunione."
else no "serve un Mac con Comandi rapidi per firmare la Scorciatoia"; MANCA+=("Scorciatoia: scorciatoia.py da un Mac"); fi

# --- 9. bot: la chat del cliente 👤 ------------------------------------------------------------------------------------
passo "9. Bot Telegram"
bot_ok() { cliente "bash $PLUGIN/scripts/moduli/telegram.sh controlla" 2>/dev/null | grep -q 'chat.*salvat\|✅ chat'; }
if cliente "test -s ~/.config/metis/telegram"; then
  if ! cliente "grep -q '^CHAT_ID=' ~/.config/metis/telegram"; then
    umano "Il cliente mandi al suo bot, dal telefono, questo messaggio: $(cliente "bash $PLUGIN/scripts/moduli/telegram.sh codice" 2>/dev/null) (è la prova che la chat è sua)."
    if chiedi "Fatto? Salvo la chat e accendo l'ascoltatore"; then cliente "$ESEGUI --moduli telegram" | grep -E '✅|⏳|❌|chat' | sed 's/^/ /'; fi
  fi
  cliente "grep -q '^CHAT_ID=' ~/.config/metis/telegram" && ok "chat del cliente salvata" || MANCA+=("chat del bot: il cliente manda al bot il codice di abbinamento, poi rilanciare")
else no "token del bot mancante (--token-bot <file>)"; MANCA+=("bot: --token-bot <file con il token di @BotFather>"); fi

# --- 10. collaudo ---------------------------------------------------------------------------------------------------------
passo "10. Collaudo"
porta "$QUI/prepara-vps.sh" && r "sudo bash /tmp/prepara-vps.sh --controlla; rm -f /tmp/prepara-vps.sh" | grep -E '❌|⚠️' | sed 's/^/ /'
porta "$QUI/web.sh" && r "sudo bash /tmp/web.sh --controlla --nome $DOMINIO --cliente $CLIENTE; rm -f /tmp/web.sh" | grep -E '❌' | sed 's/^/ /'
cliente "bash $PLUGIN/scripts/server/controllo-giornaliero.sh --muto" | sed 's/^/ /'
cliente "bash $PLUGIN/scripts/doctor.sh >/dev/null 2>&1; grep -m1 '^\*\*' ~/Vault/_Claude/doctor.md 2>/dev/null; true" | sed 's/^/  doctor: /'

porta "$QUI/prepara-vps.sh" && r "sudo bash /tmp/prepara-vps.sh --ip-fidato -; rm -f /tmp/prepara-vps.sh" | sed 's/^/ /'

echo
if [ ${#MANCA[@]} = 0 ]; then echo "✅ Server pronto. Prove dal telefono: docs/server-da-zero.md, «Collaudo finale»."; exit 0; fi
echo "Restano da fare:"; for x in "${MANCA[@]}"; do echo "  - $x"; done; exit 1
