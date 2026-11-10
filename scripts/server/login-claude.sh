#!/bin/bash
# login-claude.sh — login di Claude per l'utente del cliente su un server, senza copiare a mano niente dallo schermo.
# Si lancia come utente del cliente (da amministratore: sudo -iu <cliente> bash <percorso>/login-claude.sh <modo>).
#
# Modi (verificato il 10/11/2026 con Claude Code 2.1.322):
#   token     claude setup-token: token di un anno, SOLO per far lavorare Claude (giri, bot con un giro per messaggio).
#             Non dà Remote Control («Remote Control requires a full-scope login token… Run claude auth login») né i
#             connettori di claude.ai. Il token lo stampa setup-token alla fine, su una riga che va oltre lo schermo: qui
#             lo si cattura da solo (sessione registrata con 400 colonne) e si salva in ~/.config/metis/claude-oauth-token
#             (600) solo se è intero (prefisso sk-ant-oat01-, più di 90 caratteri). Poi installa-cliente.sh lo registra.
#   completo  claude auth login: login completo, che dà Remote Control e i connettori; Claude Code lo rinnova da sé e lo
#             tiene in ~/.claude/.credentials.json. Quanto regga senza rifarlo su un server è da verificare.
# In tutti e due: si apre un link, si autorizza su claude.ai e si incolla nel terminale il CODICE mostrato dalla pagina
# (non è il token: vale una volta sola).

set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
QUI="$(cd "$(dirname "$0")" && pwd)"   # prima del cd: $0 può essere relativo
cd "$HOME/Vault" 2>/dev/null || cd "$HOME"
case "${1:-}" in
  token)
    mkdir -p "$HOME/.config/metis"; L=$(mktemp); chmod 600 "$L"
    echo "=== Apri il link, autorizza, incolla qui il CODICE della pagina. Il token lo salvo io. ==="
    stty cols 400 2>/dev/null
    script -q -c "claude setup-token" "$L"
    T=$(sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' "$L" | tr -d '\r' | grep -o 'sk-ant-oat01-[A-Za-z0-9_-]*' | awk '{ if (length($0) > length(m)) m = $0 } END { print m }')
    shred -u "$L" 2>/dev/null || rm -f "$L"
    if [ ${#T} -gt 90 ]; then
      ( umask 077; printf '%s\n' "$T" > "$HOME/.config/metis/claude-oauth-token" ); chmod 600 "$HOME/.config/metis/claude-oauth-token"
      if printf 'Rispondi solo: ok' | CLAUDE_CODE_OAUTH_TOKEN="$T" bash "$QUI/../con-timeout.sh" 120 claude -p >/dev/null 2>&1; then
        echo "✅ token salvato (${#T} caratteri) e provato: Claude risponde. Si può chiudere."
      else echo "⚠️ token salvato (${#T} caratteri), ma la prova non risponde: rifare il login"; exit 1; fi
    else echo "❌ token non trovato o incompleto (${#T} caratteri): non ho salvato niente. Rilanciare."; exit 1; fi ;;
  completo)
    echo "=== Apri il link, autorizza, incolla qui il CODICE della pagina. ==="
    env -u CLAUDE_CODE_OAUTH_TOKEN claude auth login || exit 1
    env -u CLAUDE_CODE_OAUTH_TOKEN claude auth status 2>/dev/null | grep -q '"loggedIn": true' && echo "✅ login completo fatto" || { echo "❌ login non riuscito"; exit 1; } ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
