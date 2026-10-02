#!/bin/bash
# installa-modelli.sh — copia i modelli della memoria in un vault e sostituisce i segnaposto d'installazione.
# È il cuore del blocco «memoria e regole» dell'installazione; la skill di installazione lo chiamerà.
#
# Uso: METIS_CONFIG=<config> bash installa-modelli.sh <cartella dei modelli> "<Nome del cliente>" [<cartella delle schede di partenza>]
#   <cartella delle schede di partenza>: facoltativa, file <materia>.md.txt preparati dal consulente per questo cliente;
#   si copiano in dominio/ così come sono (decisione del 2/10/2026).
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
case "$MOD" in /*) ;; *) [ -d "$MOD" ] || MOD="$METIS_ROOT/$MOD" ;; esac   # percorso relativo: prima la cartella corrente, poi il plugin
NOME="${2:?manca il nome del cliente}"
SCHEDE="${3:-}"
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
# Modelli di stato: si copiano come sono, perché i loro segnaposto servono ogni volta che nasce uno stato.
for f in "$MOD"/_Claude/stati/*.md.txt; do
  [ -f "$f" ] || continue; d="$CL/stati/$(basename "$f" .txt)"
  if [ -e "$d" ]; then echo "già presente, lasciato com'è: $d"; else cp "$f" "$d"; fi
done
# Un CLAUDE.md del cliente resta com'è: il nucleo di Metis va in CLAUDE.local.md, che Claude Code carica insieme (verificato con 2.1.284).
if [ -f "$METIS_VAULT/CLAUDE.md" ] && ! grep -q "Installato da" "$METIS_VAULT/CLAUDE.md"; then
  echo "CLAUDE.md del cliente presente: il nucleo di $METIS_PRODOTTO va in CLAUDE.local.md"
  copia "$MOD/CLAUDE.md.txt" "$METIS_VAULT/CLAUDE.local.md"
else
  copia "$MOD/CLAUDE.md.txt" "$METIS_VAULT/CLAUDE.md"
fi
copia "$MOD/memory/MEMORY.md.txt" "$METIS_MEMORY_DIR/MEMORY.md"

# Schede di dominio di partenza: si copiano senza sostituzioni, non contano fra i file del modello.
if [ -n "$SCHEDE" ]; then
  [ -d "$SCHEDE" ] || { echo "installa-modelli: cartella delle schede non trovata: $SCHEDE" >&2; exit 2; }
  NS=0
  for f in "$SCHEDE"/*.md.txt; do
    [ -f "$f" ] || continue; d="$CL/dominio/$(basename "$f" .txt)"
    if [ -e "$d" ]; then echo "già presente, lasciato com'è: $d"; else cp "$f" "$d" && NS=$((NS+1)); fi
  done
  echo "installa-modelli: $NS schede di dominio di partenza copiate in $CL/dominio"
fi

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
for c in "$METIS_VAULT/CLAUDE.md" "$METIS_VAULT/CLAUDE.local.md"; do
  if [ -z "$METIS_RUOLO_RISERVATA" ] && printf '%s\n' "${COPIATI[@]}" | grep -qxF "$c"; then
    perl -0pi -e 's/\n## Cartella riservata\n.*\z/\n/s' "$c"
  fi
done

RESTANO=$(grep -rhoE '\{\{[^}]*\}\}' "${COPIATI[@]}" 2>/dev/null | grep -v '^{{COMPILARE' | sort -u)
if [ -n "$RESTANO" ]; then echo "installa-modelli: segnaposto non sostituiti: $RESTANO" >&2; exit 1; fi
echo "installa-modelli: ${#COPIATI[@]} file copiati in $METIS_VAULT"
