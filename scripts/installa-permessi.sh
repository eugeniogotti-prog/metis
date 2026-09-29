#!/bin/bash
# installa-permessi.sh — blocco 3 dell'installazione: i permessi preconfigurati di Claude Code per il vault.
# Uso: installa-permessi.sh            (configurazione in $METIS_CONFIG o ~/.config/metis/config)
#
# Scrive due file:
#   <vault>/.claude/settings.json      regole per le sessioni interattive. Claude Code le applica solo dopo che il
#                                      cliente ha aperto Claude Code nel vault e ha accettato la finestra di fiducia.
#   <config>/permessi-routine.json     le stesse regole, da passare con --settings ai giri automatici (claude -p),
#                                      dove valgono anche senza la finestra di fiducia (verificato con 2.1.284).
# Le regole di Metis stanno fra quelle del cliente senza sostituirle: si aggiungono le voci mancanti; quelle del
# cliente restano. Una copia del file precedente va in <vault>/.claude/settings.json.prima-di-metis (solo la prima volta).
# Niente --dangerously-skip-permissions: modalità predefinita acceptEdits, comandi ammessi per nome, divieti espliciti;
# le azioni irreversibili e gli invii li ferma l'hook guardia.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
metis_carica_config || { echo "installa-permessi: ${METIS_ERRORE}" >&2; exit 2; }

S="$METIS_VAULT/.claude/settings.json"
R="$(dirname "${METIS_CONFIG:-$HOME/.config/metis/config}")/permessi-routine.json"
mkdir -p "$METIS_VAULT/.claude" "$(dirname "$R")"
[ -f "$S" ] && [ ! -f "$S.prima-di-metis" ] && cp "$S" "$S.prima-di-metis"

export S R METIS_ROOT
python3 - <<'PY'
import json, os
env = os.environ
vault = env["METIS_VAULT"]; fonti = env.get("METIS_FONTI", ""); root = env["METIS_ROOT"]
ris = env.get("METIS_RUOLO_RISERVATA", "")
ass = lambda p: "/" + p if p.startswith("/") else p          # percorso assoluto nella sintassi dei permessi: //percorso
allow = [
    "Read(~/.claude/plugins/**)",                              # riferimenti delle skill dentro il plugin (passo 5)
    f"Read({ass(root)}/**)",
    "Bash(ls *)", "Bash(wc *)", "Bash(grep *)", "Bash(head *)", "Bash(tail *)", "Bash(date *)",
    "Bash(pgrep *)", "Bash(textutil *)", "Bash(unzip -p *)", "Bash(mkdir *)",
    "Bash(obsidian move *)", "Bash(obsidian rename *)", "Bash(obsidian daily:append *)", "Bash(obsidian daily:read*)",
    f"Bash(bash {root}/scripts/doctor.sh)",
    # giri automatici: spostare e togliere singoli file (le cancellazioni ricorsive le ferma la guardia),
    # messaggio sul telefono alla sola chat del cliente, lettura delle pagine dei link salvati nell'Inbox
    "Bash(mv *)", "Bash(cp *)", "Bash(rm *)", "Bash(find *)",
    f"Bash(python3 {root}/scripts/telegram/metis_telegram.py invia *)",
    "WebFetch",
]
if fonti:
    allow += [f"Read({ass(fonti)}/**)", f"Edit({ass(fonti)}/**)"]
deny = ["Bash(sudo *)", "Bash(rm -rf /*)", "Bash(rm -rf ~*)"]
if ris:
    deny += [f"Read({ass(vault)}/{ris}/**)", f"Edit({ass(vault)}/{ris}/**)"]
metis = {"permissions": {"defaultMode": "acceptEdits", "allow": allow, "deny": deny,
                         "additionalDirectories": [fonti] if fonti else []}}

def unisci(base, add):
    p = base.setdefault("permissions", {})
    p.setdefault("defaultMode", add["permissions"]["defaultMode"])
    for k in ("allow", "deny", "additionalDirectories"):
        lista = p.setdefault(k, [])
        for v in add["permissions"][k]:
            if v not in lista: lista.append(v)
    return base

s = env["S"]
base = json.load(open(s)) if os.path.exists(s) else {}
json.dump(unisci(base, metis), open(s, "w"), indent=2, ensure_ascii=False)
json.dump(metis, open(env["R"], "w"), indent=2, ensure_ascii=False)
print(f"installa-permessi: {len(allow)} regole allow, {len(deny)} deny → {s}")
print(f"installa-permessi: copia per le routine → {env['R']}")
PY
