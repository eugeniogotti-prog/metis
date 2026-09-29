#!/bin/bash
# installa-modelli.sh — copia i modelli della memoria in un vault e sostituisce i segnaposto d'installazione.
# È il cuore del blocco «memoria e regole» dell'installazione; la skill di installazione lo chiamerà.
#
# Uso: METIS_CONFIG=<config> bash installa-modelli.sh <cartella dei modelli> "<Nome del cliente>"
#   <cartella dei modelli> contiene CLAUDE.md.txt, _Claude/*.md.txt, memory/MEMORY.md.txt
#   (fino alla migrazione nel repository i modelli stanno nel kit).
#
# Idempotente sui file del cliente: un file che esiste già nel vault non si sovrascrive, e lo si dice.
# I segnaposto «{{COMPILARE: …}}» restano: li chiude l'onboarding.

set -uo pipefail
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"
MOD="${1:?uso: installa-modelli.sh <cartella dei modelli> \"<Nome del cliente>\"}"
NOME="${2:?manca il nome del cliente}"
metis_carica_config || { echo "installa-modelli: ${METIS_ERRORE}" >&2; exit 2; }
[ -f "$MOD/CLAUDE.md.txt" ] || { echo "installa-modelli: modelli non trovati in $MOD" >&2; exit 2; }

CL="$METIS_CL"
mkdir -p "$CL"/{stati/archivio,dominio,sessioni/archivio,archivio} "$METIS_MEMORY_DIR/archivio"
for r in INBOX PROGETTI AREE RISORSE ARCHIVIO PERSONE JOURNAL TEMPLATE; do
  d=$(metis_ruolo "$r"); [ -n "$d" ] && mkdir -p "$d"
done

COPIATI=()
copia() {  # copia <sorgente> <destinazione>
  if [ -e "$2" ]; then echo "già presente, lasciato com'è: $2"; return; fi
  cp "$1" "$2" && COPIATI+=("$2")
}
for f in "$MOD"/_Claude/*.md.txt; do copia "$f" "$CL/$(basename "$f" .txt)"; done
copia "$MOD/CLAUDE.md.txt" "$METIS_VAULT/CLAUDE.md"
copia "$MOD/memory/MEMORY.md.txt" "$METIS_MEMORY_DIR/MEMORY.md"

if [ "${#COPIATI[@]}" -eq 0 ]; then echo "installa-modelli: nessun file nuovo, vault già installato"; exit 0; fi

COMANDO_DOCTOR="METIS_CONFIG=\"${METIS_CONFIG:-$HOME/.config/metis/config}\" bash \"$METIS_ROOT/scripts/doctor.sh\""
export NOME COMANDO_DOCTOR OGGI="$(date +%F)"
for f in "${COPIATI[@]}"; do
  # Sostituzioni fatte in perl con i valori passati per ambiente: nessun carattere dei valori viene interpretato.
  perl -pi -e '
    s/\{\{PRODOTTO\}\}/$ENV{METIS_PRODOTTO}/g; s/\{\{Nome\}\}/$ENV{NOME}/g;
    s/\{\{VAULT\}\}/$ENV{METIS_VAULT}/g; s/\{\{FONTI\}\}/$ENV{METIS_FONTI}/g;
    s/\{\{YYYY-MM-DD\}\}/$ENV{OGGI}/g; s/\{\{COMANDO_DOCTOR\}\}/$ENV{COMANDO_DOCTOR}/g;
    s/\{\{RUOLO_([A-Z]+)\}\}/$ENV{"METIS_RUOLO_$1"}/g;
  ' "$f"
done

# Cartella riservata assente: si toglie la sezione dal CLAUDE.md appena copiato.
if [ -z "$METIS_RUOLO_RISERVATA" ] && printf '%s\n' "${COPIATI[@]}" | grep -qx "$METIS_VAULT/CLAUDE.md"; then
  perl -0pi -e 's/\n## Cartella riservata\n.*\z/\n/s' "$METIS_VAULT/CLAUDE.md"
fi

RESTANO=$(grep -rhoE '\{\{[^}]*\}\}' "${COPIATI[@]}" 2>/dev/null | grep -v '^{{COMPILARE' | sort -u)
if [ -n "$RESTANO" ]; then echo "installa-modelli: segnaposto non sostituiti: $RESTANO" >&2; exit 1; fi
echo "installa-modelli: ${#COPIATI[@]} file copiati in $METIS_VAULT"
