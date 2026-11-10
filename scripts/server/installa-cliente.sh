#!/bin/bash
# installa-cliente.sh — installa Metis senza domande per l'utente del cliente su un server preparato con prepara-vps.sh.
# È la stessa installazione della skill «installa» (blocchi 0-3 e moduli), con le scelte già fatte: vault nuovo con la
# struttura PARA, documenti accanto alle note, sessioni senza richieste di permesso. Il cliente non usa il terminale.
#
# Si lancia come utente del cliente (da amministratore: sudo -iu <cliente> bash <percorso>/installa-cliente.sh …).
# Si può rilanciare: ciò che c'è già resta com'è (i file della memoria esistenti non si sovrascrivono).
#
# Uso: installa-cliente.sh --nome "<Nome del cliente>" [--vault ~/Vault] [--giri "daily-digest inbox-processor"]
#                          [--token-bot <file>] [--moduli "markitdown docx telegram routine"]
#   --token-bot  file con il token del bot (dato da @BotFather), letto e poi cancellato: il token non passa dalla riga di comando
#   --moduli     quali moduli installare; google si aggiunge dopo, con il cliente (progetto Google Cloud e consenso)
#                sessione = la sessione principale sempre accesa (Remote Control + messaggi del bot), scripts/sessione-principale.sh
# Login di Claude: --login completo|token lo fa adesso, se manca (serve un terminale: ssh -t), con scripts/server/login-claude.sh.
#   completo = claude auth login: Remote Control e connettori di claude.ai. token = claude setup-token, un anno, solo il lavoro
#   di Claude (niente Remote Control né connettori). Il token in ~/.config/metis/claude-oauth-token diventa METIS_CLAUDE_TOKEN_FILE.
# Prima: il plugin (claude plugin marketplace add … e claude plugin install metis@metis): lo fa questo script se manca.
# Non fa: il login di Claude, la chat del bot (il cliente deve prima scrivergli «ciao»), Google.

set -uo pipefail
NOME=""; VAULT="$HOME/Vault"; GIRI="daily-digest inbox-processor"; TOKEN=""; MODULI="markitdown docx telegram routine sessione"
REPO="${METIS_REPO:-eugeniogotti-prog/metis}"; LOGIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --nome) NOME="${2:-}"; shift 2 ;;
    --vault) VAULT="${2:-}"; shift 2 ;;
    --giri) GIRI="${2:-}"; shift 2 ;;
    --token-bot) TOKEN="${2:-}"; shift 2 ;;
    --moduli) MODULI="${2:-}"; shift 2 ;;
    --login) LOGIN="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "installa-cliente: opzione sconosciuta «$1» (--help)" >&2; exit 2 ;;
  esac
done
[ -n "$NOME" ] || { echo "installa-cliente: serve --nome \"<Nome del cliente>\"" >&2; exit 2; }
[ "$(id -u)" != 0 ] || { echo "installa-cliente: va lanciato come utente del cliente, non da root" >&2; exit 2; }
export PATH="$HOME/.local/bin:$PATH"
passo() { printf '\n== %s\n' "$*"; }
male() { echo "  ❌ $*" >&2; }
ERR=0

passo "Plugin"
command -v claude >/dev/null || { male "Claude Code assente (prepara-vps.sh)"; exit 1; }
if ! claude plugin list 2>/dev/null | grep -q 'metis@metis'; then
  claude plugin marketplace add "$REPO" >/dev/null 2>&1; claude plugin install metis@metis >/dev/null 2>&1
fi
METIS_ROOT=$(python3 -c 'import json,os; d=json.load(open(os.path.expanduser("~/.claude/plugins/installed_plugins.json"))); print(d["plugins"]["metis@metis"][0]["installPath"])' 2>/dev/null)
[ -n "$METIS_ROOT" ] && [ -f "$METIS_ROOT/.claude-plugin/plugin.json" ] || { male "plugin non installato"; exit 1; }
export METIS_ROOT
echo "  ✅ metis@metis $(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$METIS_ROOT/.claude-plugin/plugin.json") in $METIS_ROOT"
S="$METIS_ROOT/scripts"; CFG="bash $S/configura.sh"

passo "Configurazione (blocco 0)"
mkdir -p "$VAULT"
$CFG set METIS_VAULT "$VAULT" >/dev/null
[ -n "$($CFG get METIS_LOG_DIR)" ] || $CFG set METIS_LOG_DIR "$HOME/.local/state/metis" >/dev/null
[ -n "$($CFG get METIS_LABEL)" ] || $CFG set METIS_LABEL "com.metis.$(id -un)" >/dev/null
$CFG set METIS_JOBS "$GIRI" >/dev/null
TOKF="$HOME/.config/metis/claude-oauth-token"
COMPLETO=0; [ -s "$HOME/.claude/.credentials.json" ] && COMPLETO=1
if [ -n "$LOGIN" ]; then
  case "$LOGIN" in
    completo) [ "$COMPLETO" = 1 ] && echo "  ✅ login completo già fatto" || { bash "$METIS_ROOT/scripts/server/login-claude.sh" completo && COMPLETO=1; } ;;
    token) [ -f "$TOKF" ] && echo "  ✅ token già salvato" || bash "$METIS_ROOT/scripts/server/login-claude.sh" token ;;
    *) male "--login vuole completo o token"; exit 2 ;;
  esac
fi
[ "$COMPLETO" = 1 ] && echo "  ✅ login completo di Claude (Remote Control e connettori)"
if [ -f "$TOKF" ]; then chmod 600 "$TOKF"; $CFG set METIS_CLAUDE_TOKEN_FILE "$TOKF" >/dev/null; echo "  ✅ login di Claude dal token di lunga durata"
elif [ "$COMPLETO" = 0 ]; then echo "  ⏳ login di Claude non ancora fatto: bash $METIS_ROOT/scripts/server/login-claude.sh completo (o token)"; fi
echo "  ✅ vault $VAULT · giri: $GIRI"
bash "$S/verifica-dotazione.sh" fondamenta $MODULI | grep -E '❌|⚠️' && { male "manca qualcosa (sopra): prepara-vps.sh"; ERR=1; } || echo "  ✅ dotazione completa"

passo "Struttura del vault (blocco 1)"
bash "$S/installa-struttura.sh" crea | sed 's/^/  /'

passo "Memoria e regole (blocco 2)"
bash "$S/installa-modelli.sh" "$METIS_ROOT/templates/memoria" "$NOME" | tail -3 | sed 's/^/  /'

passo "Protezioni e permessi (blocco 3)"
bash "$S/installa-permessi.sh" | tail -2 | sed 's/^/  /'
# La fiducia nella cartella: sul Mac il cliente la accetta alla prima apertura; qui nessuno apre Claude a mano.
python3 - "$VAULT" <<'PY'
import json, os, sys
p = os.path.expanduser("~/.claude.json"); v = os.path.realpath(sys.argv[1])
try: d = json.load(open(p))
except (OSError, ValueError): d = {}
pr = d.setdefault("projects", {}).setdefault(v, {})
cambiato = not pr.get("hasTrustDialogAccepted")
pr["hasTrustDialogAccepted"] = True
if cambiato:
    t = p + ".tmp"; json.dump(d, open(t, "w"), indent=2); os.chmod(t, 0o600); os.replace(t, p)
print(f"  ✅ fiducia nella cartella {v}" + (" (impostata)" if cambiato else ""))
PY

for m in $MODULI; do
  passo "Modulo $m"
  case "$m" in
    markitdown|docx) bash "$S/moduli/$m.sh" installa 2>&1 | tail -2 | sed 's/^/  /' ;;
    telegram)
      if [ -n "$TOKEN" ] && [ -f "$TOKEN" ]; then
        bash "$S/moduli/telegram.sh" token < "$TOKEN" 2>&1 | sed 's/^/  /' && rm -f "$TOKEN" && echo "  ✅ file del token cancellato"
      fi
      if bash "$S/moduli/telegram.sh" chat 2>/dev/null | sed 's/^/  /'; then
        bash "$S/moduli/telegram.sh" ascoltatore 2>&1 | tail -1 | sed 's/^/  /'
      else
        echo "  ⏳ chat del cliente non ancora nota: il cliente scrive «ciao» al bot, poi si rilancia questo script"
      fi ;;
    routine) bash "$S/moduli/routine.sh" installa 2>&1 | tail -3 | sed 's/^/  /' ;;
    sessione)
      # Una sessione che nessuno guarda non deve fermarsi su una domanda: prima configurazione già fatta, modalità
      # senza permessi già accettata, niente suggerimenti di prompt.
      python3 - <<'PY'
import json, os
def aggiorna(p, f):
    try: d = json.load(open(p))
    except (OSError, ValueError): d = {}
    f(d); t = p + ".tmp"; json.dump(d, open(t, "w"), indent=2); os.chmod(t, 0o600); os.replace(t, p)
os.makedirs(os.path.expanduser("~/.claude"), exist_ok=True)
aggiorna(os.path.expanduser("~/.claude/settings.json"),
         lambda d: d.update(skipDangerousModePermissionPrompt=True, promptSuggestionEnabled=False))
aggiorna(os.path.expanduser("~/.claude.json"), lambda d: (d.update(hasCompletedOnboarding=True), d.setdefault("theme", "dark")))
print("  ✅ Claude Code senza domande alla prima apertura")
PY
      bash "$S/sessione-principale.sh" installa 2>&1 | tail -1 | sed 's/^/  /' ;;
    *) male "modulo «$m» non gestito qui (si installa con la skill)"; ERR=1 ;;
  esac
done

passo "Controllo"
bash "$S/doctor.sh" 2>&1 | grep -E "^Doctor|🔴|🟡|🟢" | tail -2 | sed 's/^/  /'
echo "  Manca ancora: Google (modulo google con il cliente)."
exit "$ERR"
