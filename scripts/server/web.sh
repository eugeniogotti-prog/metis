#!/bin/bash
# web.sh — la parte web di un server Metis gestito: HTTPS con Caddy su un nome (anche <ip-con-trattini>.sslip.io), FileBrowser
# in SOLA LETTURA sul vault del cliente e, sullo stesso nome, l'ingresso delle riunioni (/riunione, scripts/server/riunioni.py).
# Si lancia da root (o con sudo). Si può rilanciare.
#
# Uso:
#   web.sh --nome <nome dns> [--cliente metis] [--utente-web <nome>]
#       Caddy (pacchetto di Ubuntu) con certificato automatico; ufw apre 80 e 443.
#       FileBrowser (versione fissata) eseguito da un utente di sistema a parte, «filebrowser», che legge il vault del
#       cliente grazie ad ACL in sola lettura: niente scrittura, niente accesso al resto della home (configurazione, token,
#       chiavi). File nascosti esclusi. L'utente web non può modificare, creare, cancellare, rinominare, condividere né
#       lanciare comandi; ha una password casuale che nessuno conosce, finché non la imposta chi assiste il cliente:
#   sudo filebrowser-password <utente-web>     chiede la password senza mostrarla (almeno 12 caratteri) e la imposta.
#   web.sh --controlla --nome <nome dns>       servizi attivi, certificato, ACL, risposta da fuori.
#   --cambia-nome                              necessario per cambiare il nome di un server già configurato.

set -uo pipefail
NOME=""; CLIENTE="metis"; UWEB="ospite"; AZ=prepara; CAMBIA=""
FB_VER="v2.63.23"; FB_PORTA=8081; RIU_PORTA=8765
while [ $# -gt 0 ]; do
  case "$1" in
    --nome) NOME="${2:-}"; shift 2 ;;
    --cliente) CLIENTE="${2:-}"; shift 2 ;;
    --utente-web) UWEB="${2:-}"; shift 2 ;;
    --controlla) AZ=controlla; shift ;;
    --cambia-nome) CAMBIA=1; shift ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "web: opzione sconosciuta «$1»" >&2; exit 2 ;;
  esac
done
[ "$(id -u)" = 0 ] || { echo "web: va lanciato da root (sudo)" >&2; exit 2; }
[ -n "$NOME" ] || { echo "web: serve --nome <nome dns>" >&2; exit 2; }
[[ "$UWEB" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] || { echo "web: nome utente web non valido" >&2; exit 2; }
VAULT="/home/$CLIENTE/Vault"; DB=/var/lib/filebrowser/filebrowser.db
FB="/usr/local/bin/filebrowser"
nuovo() { echo "  ➕ $*"; }; fatto() { echo "  ✅ $*"; }; male() { echo "  ❌ $*" >&2; }

if [ "$AZ" = controlla ]; then
  ERR=0; c() { if eval "$2" >/dev/null 2>&1; then fatto "$1"; else male "$1"; ERR=1; fi; }
  c "Caddy attivo" 'systemctl is-active caddy'
  c "FileBrowser attivo" 'systemctl is-active filebrowser'
  c "ufw con 80 e 443" 'ufw status | grep -qE "^80/tcp" && ufw status | grep -qE "^443/tcp"'
  # Le prove girano con lo stesso isolamento del servizio.
  come_fb() { systemd-run --quiet --wait --pipe -p User=filebrowser -p ProtectHome=tmpfs -p ProtectSystem=strict \
      -p BindReadOnlyPaths="$VAULT:/srv/vault" "$@"; }
  c "filebrowser legge il vault" 'come_fb /bin/ls /srv/vault'
  c "filebrowser NON scrive nel vault" '! come_fb /usr/bin/touch /srv/vault/.prova-scrittura'
  c "filebrowser NON vede la home del cliente" '! come_fb /bin/ls /home/'"$CLIENTE"'/.config'
  c "filebrowser fuori dal servizio non entra nella home" '! sudo -u filebrowser ls /home/'"$CLIENTE"'/'
  c "HTTPS risponde" 'curl -fsS -o /dev/null https://'"$NOME"'/'
  exit "$ERR"
fi

# Un server già configurato con un altro nome non si rinomina per sbaglio: l'indirizzo vecchio smetterebbe di funzionare
# (successo il 10/11/2026 in una prova). Per cambiarlo davvero: --cambia-nome.
if [ -f /etc/caddy/Caddyfile ] && grep -q "Scritto da web.sh" /etc/caddy/Caddyfile; then
  ATTUALE=$(awk '/^[^#[:space:]].*\{$/ {print $1; exit}' /etc/caddy/Caddyfile)
  if [ -n "$ATTUALE" ] && [ "$ATTUALE" != "$NOME" ] && [ -z "$CAMBIA" ]; then
    male "il server risponde già come ${ATTUALE}: per passare a $NOME aggiungere --cambia-nome (l'indirizzo vecchio smette di funzionare)"; exit 1
  fi
fi

echo "== Pacchetti"
for p in caddy acl; do dpkg -s "$p" >/dev/null 2>&1 || { DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt-get install -y -qq "$p" >/dev/null && nuovo "$p"; }; done
fatto "caddy $(caddy version 2>/dev/null | cut -d' ' -f1), acl"
if [ -x "$FB" ] && "$FB" version 2>/dev/null | grep -q "${FB_VER#v}"; then fatto "FileBrowser $FB_VER"
else
  T=$(mktemp -d); curl -fsSL "https://github.com/filebrowser/filebrowser/releases/download/$FB_VER/linux-amd64-filebrowser.tar.gz" -o "$T/fb.tgz" \
    && tar -xzf "$T/fb.tgz" -C "$T" filebrowser && install -m 755 "$T/filebrowser" "$FB" && nuovo "FileBrowser $FB_VER" || { male "FileBrowser non scaricato"; rm -rf "$T"; exit 1; }
  rm -rf "$T"
fi

echo "== Utente di sistema e permessi in sola lettura"
id filebrowser >/dev/null 2>&1 || { useradd --system --home /var/lib/filebrowser --shell /usr/sbin/nologin filebrowser && nuovo "utente filebrowser"; }
install -d -m 700 -o filebrowser -g filebrowser /var/lib/filebrowser
[ -d "$VAULT" ] || { male "manca il vault $VAULT"; exit 1; }
# Nessun accesso alla home: systemd monta il solo vault, in sola lettura, in /srv/vault e nasconde /home al servizio.
# Le ACL danno la lettura dei file del vault (e di quelli creati dopo); il montaggio impedisce la scrittura.
setfacl -x u:filebrowser "/home/$CLIENTE" 2>/dev/null   # resto di una versione precedente, che attraversava la home
setfacl -R -m u:filebrowser:rX "$VAULT"
setfacl -R -d -m u:filebrowser:rX "$VAULT"
fatto "ACL: filebrowser legge i file del vault; la home gli resta invisibile"

echo "== FileBrowser"
fbc() { sudo -u filebrowser "$FB" -d "$DB" "$@" 2> >(grep -v -E "No config file used|Using database" >&2); }
SERV_ATTIVO=0; systemctl is-active --quiet filebrowser && { SERV_ATTIVO=1; systemctl stop filebrowser; }   # il database è bloccato mentre gira
if [ ! -f "$DB" ]; then
  fbc config init --address 127.0.0.1 --port "$FB_PORTA" --root /srv/vault >/dev/null 2>&1 && nuovo "configurazione"
fi
fbc config set --address 127.0.0.1 --port "$FB_PORTA" --root /srv/vault --branding.name "Vault" --branding.disableExternal \
  --signup=false --auth.method=json >/dev/null 2>&1 || true
PERM=(--perm.admin=false --perm.create=false --perm.delete=false --perm.download=true --perm.execute=false
      --perm.modify=false --perm.rename=false --perm.share=false --hideDotfiles --lockPassword --locale it --commands "")
if fbc users ls 2>/dev/null | awk '{print $2}' | grep -qx "$UWEB"; then
  fbc users update "$UWEB" "${PERM[@]}" >/dev/null && fatto "utente web $UWEB (permessi riapplicati)"
else
  fbc users add "$UWEB" "$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)" "${PERM[@]}" >/dev/null \
    && nuovo "utente web $UWEB, sola lettura, password casuale: si imposta con sudo filebrowser-password $UWEB"
fi
# File e cartelle nascosti (.claude, .mcp.json, …): vietati, non solo nascosti nell'interfaccia.
fbc rules ls 2>/dev/null | grep -qF '/\.' || { fbc rules add --regex '/\.' >/dev/null && nuovo "regola: vietati i percorsi nascosti"; }
cat > /etc/systemd/system/filebrowser.service <<EOF
[Unit]
Description=FileBrowser in sola lettura sul vault di $CLIENTE
After=network.target
StartLimitIntervalSec=0

[Service]
User=filebrowser
Group=filebrowser
ExecStart=$FB -d $DB
Restart=always
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/lib/filebrowser
PrivateTmp=true
ProtectHome=tmpfs
BindReadOnlyPaths=$VAULT:/srv/vault

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl reset-failed filebrowser 2>/dev/null; systemctl enable --now filebrowser >/dev/null 2>&1; systemctl restart filebrowser
systemctl is-active --quiet filebrowser && fatto "servizio attivo su 127.0.0.1:$FB_PORTA" || male "FileBrowser non parte (journalctl -u filebrowser)"
cat > /usr/local/sbin/filebrowser-password <<EOF
#!/bin/bash
# imposta la password di un utente di FileBrowser senza mostrarla (scritto da web.sh)
set -u; U="\${1:?uso: sudo filebrowser-password <utente>}"
read -rsp "Password per \$U (almeno 12 caratteri): " P; echo
read -rsp "Ripetila: " P2; echo
[ "\$P" = "\$P2" ] || { echo "Le due password non coincidono."; exit 1; }
[ \${#P} -ge 12 ] || { echo "Troppo corta."; exit 1; }
systemctl stop filebrowser
sudo -u filebrowser $FB -d $DB users update "\$U" --password "\$P" >/dev/null && echo "Password impostata per \$U." || echo "Non riuscito."
systemctl reset-failed filebrowser 2>/dev/null; systemctl start filebrowser
EOF
chmod 700 /usr/local/sbin/filebrowser-password; fatto "comando filebrowser-password"

echo "== Caddy e firewall"
cat > /etc/caddy/Caddyfile <<EOF
# Scritto da web.sh (Metis): FileBrowser in sola lettura e l'ingresso delle riunioni.
$NOME {
	encode gzip
	handle /riunione* {
		request_body {
			max_size 400MB
		}
		reverse_proxy 127.0.0.1:$RIU_PORTA
	}
	handle {
		reverse_proxy 127.0.0.1:$FB_PORTA
	}
	header {
		Strict-Transport-Security "max-age=31536000"
		X-Robots-Tag "noindex, nofollow"
		-Server
	}
}
EOF
caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 || { male "Caddyfile non valido"; exit 1; }
for p in 80 443; do ufw status | grep -qE "^$p/tcp" || { ufw allow "$p/tcp" >/dev/null && nuovo "porta $p aperta"; }; done
systemctl reload caddy 2>/dev/null || systemctl restart caddy
fatto "https://$NOME (il certificato arriva al primo accesso, entro un minuto)"
# L'indirizzo va nella configurazione del cliente: i link ai file nelle risposte (link.py) lo usano.
CFGC="/home/$CLIENTE/.config/metis/config"
if [ -f "$CFGC" ]; then
  sudo -u "$CLIENTE" sed -i '/^METIS_WEB_URL=/d' "$CFGC" && echo "METIS_WEB_URL=https://$NOME" | sudo -u "$CLIENTE" tee -a "$CFGC" >/dev/null
  fatto "indirizzo dei link ai file nella configurazione del cliente"
fi
