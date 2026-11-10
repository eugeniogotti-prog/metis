#!/bin/bash
# prepara-vps.sh — prepara un server Ubuntu 24.04 vuoto per Metis «gestito»: il cliente usa l'assistente da Telegram, mail
# e app di Claude, senza terminale; chi lo assiste entra con la sua chiave SSH come amministratore.
#
# Si lancia da root sul server (copiato con scp, o da una copia del repository). Si può rilanciare: ogni passo controlla
# prima che cosa c'è già e fa solo ciò che manca.
#
# Uso:
#   prepara-vps.sh --admin <utente> --chiave <file .pub> [--cliente metis] [--fuso Europe/Rome] [--swap 2G]
#       pacchetti di sistema e di sicurezza, lingua e fuso, swap, utente amministratore (sudo, solo chiave), utente del
#       cliente (servizi con linger, niente SSH), SSH solo con chiave, ufw con la sola 22, fail2ban, aggiornamenti di
#       sicurezza automatici, Node 22, rclone, e per il cliente Claude Code e uv.
#       Root può ancora entrare con la chiave: si chiude dopo, con il comando qui sotto.
#   sudo prepara-vps.sh --chiudi-root
#       da lanciare collegati come amministratore (ssh <admin>@server, poi sudo): che il comando arrivi fin qui dimostra
#       che l'accesso dell'amministratore e il suo sudo funzionano. Solo allora toglie a root l'accesso SSH.
#   prepara-vps.sh --controlla
#       dice che cosa è a posto e che cosa manca, senza cambiare niente (uscita 1 se manca qualcosa).
#
# Che cosa NON fa: il login di Claude, il bot di Telegram, l'autorizzazione Google e l'installazione di Metis per il
# cliente (passi successivi, con il cliente o con chi lo assiste).

set -uo pipefail
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 LC_ALL=C.UTF-8

ADMIN=""; CHIAVE=""; CLIENTE="metis"; FUSO="Europe/Rome"; SWAP="2G"; AZIONE=prepara
while [ $# -gt 0 ]; do
  case "$1" in
    --admin) ADMIN="${2:-}"; shift 2 ;;
    --chiave) CHIAVE="${2:-}"; shift 2 ;;
    --cliente) CLIENTE="${2:-}"; shift 2 ;;
    --fuso) FUSO="${2:-}"; shift 2 ;;
    --swap) SWAP="${2:-}"; shift 2 ;;
    --chiudi-root) AZIONE=chiudi; shift ;;
    --controlla) AZIONE=controlla; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "prepara-vps: opzione sconosciuta «$1» (--help)" >&2; exit 2 ;;
  esac
done

[ "$(id -u)" = 0 ] || { echo "prepara-vps: va lanciato da root (o con sudo)" >&2; exit 2; }
SSHD_METIS=/etc/ssh/sshd_config.d/10-metis.conf
passo() { printf '\n== %s\n' "$*"; }
fatto() { echo "  ✅ $*"; }
nuovo() { echo "  ➕ $*"; }
male() { echo "  ❌ $*" >&2; }

# ---------------------------------------------------------------- controlla
if [ "$AZIONE" = controlla ]; then
  ERR=0
  c() { if eval "$2" >/dev/null 2>&1; then fatto "$1"; else male "$1"; ERR=1; fi; }
  . /etc/os-release 2>/dev/null
  c "Ubuntu 24.04" '[ "${VERSION_ID:-}" = 24.04 ]'
  c "ufw attivo con la 22" 'ufw status | grep -q "Status: active" && ufw status | grep -qE "^(22|OpenSSH)"'
  c "fail2ban attivo" 'systemctl is-active fail2ban'
  c "aggiornamenti automatici attivi" 'grep -q "Unattended-Upgrade \"1\"" /etc/apt/apt.conf.d/20auto-upgrades'
  c "SSH senza password" '[ "$(sshd -T | awk "/^passwordauthentication/{print \$2}")" = no ]'
  c "swap presente" '[ -n "$(swapon --show --noheadings)" ]'
  c "fuso orario impostato" '[ "$(timedatectl show -p Timezone --value)" != Etc/UTC ]'
  c "Node 22 o successivo" '[ "$(node -p "process.versions.node.split(\".\")[0]")" -ge 22 ]'
  c "rclone" 'command -v rclone'
  for u in $(awk -F: '$3>=1000 && $3<60000 {print $1}' /etc/passwd); do
    if [ -f "/etc/sudoers.d/90-metis-$u" ]; then
      c "amministratore $u: sudo e chiave" '[ -s /home/'"$u"'/.ssh/authorized_keys ]'
    elif [ -f "/var/lib/systemd/linger/$u" ]; then
      c "cliente $u: linger" 'true'
      c "cliente $u: Claude Code" '[ -x /home/'"$u"'/.local/bin/claude ]'
      c "cliente $u: uv" '[ -x /home/'"$u"'/.local/bin/uv ]'
    fi
  done
  if [ "$(sshd -T | awk '/^permitrootlogin/{print $2}')" = no ]; then fatto "root senza accesso SSH"
  else echo "  ⚠️ root entra ancora con la chiave (si chiude con: sudo prepara-vps.sh --chiudi-root, da amministratore)"; fi
  exit "$ERR"
fi

# ---------------------------------------------------------------- chiudi root
if [ "$AZIONE" = chiudi ]; then
  A="${SUDO_USER:-}"
  if [ -z "$A" ] || [ "$A" = root ]; then
    male "va lanciato come amministratore con sudo (ssh <admin>@server, poi sudo $0 --chiudi-root): così si sa che il suo accesso funziona"; exit 1
  fi
  [ -f "/etc/sudoers.d/90-metis-$A" ] || { male "$A non è l'amministratore preparato da questo script"; exit 1; }
  [ -s "/home/$A/.ssh/authorized_keys" ] || { male "$A non ha chiavi SSH: root resta aperto"; exit 1; }
  [ -f "$SSHD_METIS" ] || { male "manca $SSHD_METIS: prima la preparazione"; exit 1; }
  sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' "$SSHD_METIS"
  sed -i "s/^AllowUsers .*/AllowUsers $A/" "$SSHD_METIS"
  if sshd -t; then systemctl reload ssh && fatto "root senza accesso SSH; entra solo $A (la sessione aperta resta)"
  else male "configurazione SSH non valida: non ricaricata"; exit 1; fi
  exit 0
fi

# ---------------------------------------------------------------- prepara
[ -n "$ADMIN" ] && [ -n "$CHIAVE" ] || { echo "prepara-vps: servono --admin <utente> e --chiave <file .pub> (--help)" >&2; exit 2; }
for u in "$ADMIN" "$CLIENTE"; do [[ "$u" =~ ^[a-z][a-z0-9-]{1,30}$ ]] || { echo "prepara-vps: nome utente non valido «${u}»" >&2; exit 2; }; done
[ "$ADMIN" != "$CLIENTE" ] || { echo "prepara-vps: amministratore e cliente devono essere utenti diversi" >&2; exit 2; }
[ -f "$CHIAVE" ] && grep -qE '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-[a-z0-9-]+|sk-ssh-ed25519@openssh.com) ' "$CHIAVE" \
  || { echo "prepara-vps: «${CHIAVE}» non è una chiave pubblica SSH" >&2; exit 2; }
. /etc/os-release 2>/dev/null
[ "${VERSION_ID:-}" = 24.04 ] || echo "  ⚠️ provato su Ubuntu 24.04; qui c'è ${PRETTY_NAME:-un sistema sconosciuto}"

passo "Pacchetti di sistema"
apt-get update -qq
PACCHETTI="ufw fail2ban unattended-upgrades tmux jq git curl ca-certificates gnupg python3 python3-venv pandoc ffmpeg locales unzip"
MANCANO=$(for p in $PACCHETTI; do dpkg -s "$p" >/dev/null 2>&1 || echo "$p"; done | tr '\n' ' ')
if [ -n "${MANCANO// }" ]; then apt-get install -y -qq $MANCANO >/dev/null && nuovo "installati: $MANCANO" || { male "installazione non riuscita"; exit 1; }
else fatto "già presenti"; fi

passo "Lingua e fuso orario"
grep -q '^it_IT.UTF-8 UTF-8' /etc/locale.gen || { sed -i 's/^# *it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen; grep -q '^it_IT.UTF-8 UTF-8' /etc/locale.gen || echo 'it_IT.UTF-8 UTF-8' >> /etc/locale.gen; }
locale -a 2>/dev/null | grep -qi '^it_IT.utf8$' && fatto "it_IT.UTF-8 presente" || { locale-gen it_IT.UTF-8 >/dev/null && nuovo "it_IT.UTF-8 generata"; }
if [ "$(timedatectl show -p Timezone --value)" = "$FUSO" ]; then fatto "fuso $FUSO"; else timedatectl set-timezone "$FUSO" && nuovo "fuso $FUSO"; fi

passo "Swap"
if [ -n "$(swapon --show --noheadings)" ]; then fatto "già attivo ($(swapon --show --noheadings | awk '{print $3}' | head -1))"
else
  fallocate -l "$SWAP" /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile \
    && { grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab; } && nuovo "swap di $SWAP in /swapfile"
fi

passo "Utente amministratore: $ADMIN"
id "$ADMIN" >/dev/null 2>&1 && fatto "esiste" || { useradd -m -s /bin/bash "$ADMIN" && passwd -l "$ADMIN" >/dev/null && nuovo "creato (senza password)"; }
install -d -m 700 -o "$ADMIN" -g "$ADMIN" "/home/$ADMIN/.ssh"
AK="/home/$ADMIN/.ssh/authorized_keys"; touch "$AK"
K=$(awk '{print $1" "$2}' "$CHIAVE" | head -1)
grep -qF "$K" "$AK" && fatto "chiave già autorizzata" || { head -1 "$CHIAVE" >> "$AK"; nuovo "chiave autorizzata"; }
chown "$ADMIN:$ADMIN" "$AK"; chmod 600 "$AK"
SUD="/etc/sudoers.d/90-metis-$ADMIN"
if [ -f "$SUD" ]; then fatto "sudo già concesso"
else
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$ADMIN" > "$SUD.tmp" && chmod 440 "$SUD.tmp"
  if visudo -cf "$SUD.tmp" >/dev/null; then mv "$SUD.tmp" "$SUD"; nuovo "sudo senza password (l'utente non ha password: entra solo con la chiave)"
  else rm -f "$SUD.tmp"; male "regola sudo non valida"; exit 1; fi
fi

passo "Utente del cliente: $CLIENTE"
id "$CLIENTE" >/dev/null 2>&1 && fatto "esiste" || { useradd -m -s /bin/bash "$CLIENTE" && passwd -l "$CLIENTE" >/dev/null && nuovo "creato (senza password, senza SSH, senza sudo)"; }
if [ -f "/var/lib/systemd/linger/$CLIENTE" ]; then fatto "linger già attivo"; else loginctl enable-linger "$CLIENTE" && nuovo "linger: i suoi servizi girano anche senza nessuno collegato"; fi
# Chi assiste entra nel cliente con: sudo -iu <cliente>

passo "SSH solo con chiave"
if [ ! -f "$SSHD_METIS" ]; then
  # Il primo file in ordine alfabetico vince: 10-metis viene prima di 50-cloud-init (che su Hetzner rimette le password).
  cat > "$SSHD_METIS" <<EOF
# Scritto da prepara-vps.sh (Metis). Root si chiude con: sudo prepara-vps.sh --chiudi-root, da amministratore.
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
AllowUsers $ADMIN root
EOF
  if sshd -t; then systemctl reload ssh && nuovo "password disattivate; entrano $ADMIN e root, solo con chiave"
  else rm -f "$SSHD_METIS"; male "configurazione SSH non valida: tolta, SSH invariato"; exit 1; fi
else
  grep -q "^AllowUsers.*\b$ADMIN\b" "$SSHD_METIS" && fatto "già impostato ($(grep -E '^(PermitRootLogin|AllowUsers)' "$SSHD_METIS" | tr '\n' ' '))" \
    || { male "$SSHD_METIS esiste ma non ammette $ADMIN: controllarlo a mano"; exit 1; }
fi

passo "Firewall (ufw): solo la 22 in ingresso"
ufw status | grep -qE '^(22|OpenSSH)[ /]' || { ufw allow OpenSSH >/dev/null && nuovo "22 aperta"; }
if ufw status | grep -q 'Status: active'; then fatto "attivo"
else ufw default deny incoming >/dev/null; ufw default allow outgoing >/dev/null; ufw --force enable >/dev/null && nuovo "attivato"; fi

passo "fail2ban"
if [ ! -f /etc/fail2ban/jail.d/metis.local ]; then
  printf '[sshd]\nenabled = true\nmaxretry = 5\nbantime = 1h\n' > /etc/fail2ban/jail.d/metis.local; nuovo "regola per SSH"
fi
systemctl enable --now fail2ban >/dev/null 2>&1; systemctl restart fail2ban
systemctl is-active fail2ban >/dev/null && fatto "attivo" || male "non parte (journalctl -u fail2ban)"

passo "Aggiornamenti di sicurezza automatici"
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
systemctl enable --now unattended-upgrades >/dev/null 2>&1 && fatto "attivi (solo sicurezza, configurazione di Ubuntu)"

passo "Node 22 (serve al server della posta locale)"
NV=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
if [ "$NV" -ge 22 ]; then fatto "node $(node -v)"
else
  install -d -m 755 /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update -qq && apt-get install -y -qq nodejs >/dev/null && nuovo "node $(node -v) (NodeSource)" || { male "Node non installato"; exit 1; }
fi

passo "rclone (sincronizzazione dei file)"
if command -v rclone >/dev/null && rclone version 2>/dev/null | head -1 | grep -qE 'v1\.(6[6-9]|[7-9][0-9])'; then fatto "$(rclone version | head -1)"
else curl -fsSL https://rclone.org/install.sh | bash >/dev/null 2>&1; command -v rclone >/dev/null && nuovo "$(rclone version | head -1)" || male "rclone non installato"; fi

passo "Programmi del cliente ($CLIENTE): Claude Code e uv"
come() { sudo -iu "$CLIENTE" bash -lc "$1"; }
grep -q '.local/bin' "/home/$CLIENTE/.profile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "/home/$CLIENTE/.profile"
if [ -x "/home/$CLIENTE/.local/bin/claude" ]; then fatto "Claude Code $(come 'claude --version' 2>/dev/null | head -1)"
else come 'curl -fsSL https://claude.ai/install.sh | bash' >/dev/null 2>&1; [ -x "/home/$CLIENTE/.local/bin/claude" ] && nuovo "Claude Code $(come 'claude --version' | head -1)" || male "Claude Code non installato"; fi
if [ -x "/home/$CLIENTE/.local/bin/uv" ]; then fatto "uv presente"
else come 'curl -LsSf https://astral.sh/uv/install.sh | sh' >/dev/null 2>&1; [ -x "/home/$CLIENTE/.local/bin/uv" ] && nuovo "uv installato" || male "uv non installato"; fi

passo "Fatto"
echo "  Prova adesso, da un'altra finestra: ssh $ADMIN@<server> e poi sudo -iu $CLIENTE."
echo "  Se entra: sudo $0 --chiudi-root (da $ADMIN). Controllo: $0 --controlla"
echo "  Poi Metis per il cliente, con il login di Claude (serve un terminale, quindi ssh -t):"
echo "    sudo -iu $CLIENTE bash <percorso assoluto>/installa-cliente.sh --nome \"<Nome del cliente>\" --token-bot <file> --login completo"
