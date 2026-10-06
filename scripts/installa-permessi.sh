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
# Sessioni senza richieste di permesso (decisione del 6/10/2026, dopo la misura: 12 richieste in 8 compiti
# con le sole regole «allow»): modalità predefinita bypassPermissions, la stessa di --dangerously-skip-permissions.
# Le protezioni restano e non dipendono dalle richieste: i divieti (deny) valgono anche in questa modalità (provato il
# 6/10: lettura negata di un file vietato), e l'hook guardia blocca la cartella riservata e sudo e chiede conferma per
# invii, cancellazioni ricorsive e push. Con METIS_PERMESSI=con-richieste si torna ad acceptEdits con le regole allow.
# Le routine hanno la loro copia, sempre in acceptEdits con gli strumenti ammessi per nome (metis-agent.sh).

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
    # sola lettura, per i giri automatici (misura del 6/10: 11 azioni negate in 4 giri, quasi tutte comandi composti
    # di sola lettura); nelle sessioni non servono, perché sono senza richieste di permesso
    "Bash(cd *)", "Bash(cat *)", "Bash(sed -n *)", "Bash(sort *)", "Bash(uniq *)", "Bash(cut *)", "Bash(echo *)",
    "Bash(printf *)", "Bash(stat *)", "Bash(file *)", "Bash(basename *)", "Bash(dirname *)", "Bash(test *)",
    "Bash(unzip -l *)", "Bash(mdls *)",
    "Bash(pgrep *)", "Bash(textutil *)", "Bash(unzip -p *)", "Bash(mkdir *)",
    "Bash(obsidian move *)", "Bash(obsidian rename *)", "Bash(obsidian daily:append *)", "Bash(obsidian daily:read*)",
    f"Bash(bash {root}/scripts/doctor.sh)",
    # script del plugin che le skill richiamano nei giri automatici (misura del 6/10)
    f"Bash(bash {root}/scripts/configura.sh get *)", f"Bash(bash {root}/scripts/con-timeout.sh *)",
    # giri automatici: spostare e togliere singoli file (le cancellazioni ricorsive le ferma la guardia),
    # messaggio sul telefono alla sola chat del cliente, lettura delle pagine dei link salvati nell'Inbox
    "Bash(mv *)", "Bash(cp *)", "Bash(rm *)", "Bash(find *)",
    "WebFetch",
    # ricostruzione del log di una sessione non chiusa, dalla trascrizione che Claude Code tiene fuori dal vault
    f"Bash(python3 {root}/scripts/trascrizione.py *)",
]
if fonti:
    allow += [f"Read({ass(fonti)}/**)", f"Edit({ass(fonti)}/**)"]
deny = ["Bash(sudo *)", "Bash(rm -rf /*)", "Bash(rm -rf ~*)",
        # cartelle del Mac con chiavi e credenziali: Claude non le legge mai, in nessuna modalità
        "Read(~/.ssh/**)", "Read(~/.aws/**)", "Read(~/.gnupg/**)", "Read(~/Library/Keychains/**)",
        "Read(~/.config/gh/**)", "Read(~/.netrc)", "Edit(~/.ssh/**)", "Edit(~/.aws/**)", "Edit(~/.gnupg/**)"]
if ris:
    deny += [f"Read({ass(vault)}/{ris}/**)", f"Edit({ass(vault)}/{ris}/**)"]
# cartelle che Claude legge ma non modifica (METIS_SOLA_LETTURA, relative al vault, separate da «|»)
for c in [x.strip() for x in env.get("METIS_SOLA_LETTURA", "").split("|") if x.strip()]:
    deny += [f"Edit({ass(vault)}/{c}/**)", f"Write({ass(vault)}/{c}/**)"]
modo = "acceptEdits" if env.get("METIS_PERMESSI", "senza-richieste") == "con-richieste" else "bypassPermissions"
metis = {"permissions": {"defaultMode": modo, "allow": allow, "deny": deny,
                         "additionalDirectories": [fonti] if fonti else []}}
routine = {"permissions": dict(metis["permissions"], defaultMode="acceptEdits")}

def unisci(base, add):
    p = base.setdefault("permissions", {})
    p["defaultMode"] = add["permissions"]["defaultMode"]   # la modalità di Metis prevale (copia del file in .prima-di-metis)
    for k in ("allow", "deny", "additionalDirectories"):
        lista = p.setdefault(k, [])
        for v in add["permissions"][k]:
            if v not in lista: lista.append(v)
    return base

s = env["S"]
base = json.load(open(s)) if os.path.exists(s) else {}
json.dump(unisci(base, metis), open(s, "w"), indent=2, ensure_ascii=False)
json.dump(routine, open(env["R"], "w"), indent=2, ensure_ascii=False)
print(f"installa-permessi: modalità {modo}, {len(allow)} regole allow, {len(deny)} deny → {s}")
print(f"installa-permessi: copia per le routine → {env['R']}")
PY
