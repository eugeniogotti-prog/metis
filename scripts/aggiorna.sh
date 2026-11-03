#!/bin/bash
# aggiorna.sh — porta un'installazione esistente alla copia del plugin da cui si lancia, senza toccare il contenuto del
# cliente. Serve quando cambia la copia in uso: un aggiornamento, o il passaggio dal plugin installato da terminale a
# quello caricato nell'app di Claude (tab Code), che sta in un'altra cartella.
#
# Uso:
#   aggiorna.sh controlla         che cosa trova e che cosa farebbe; non scrive niente
#   aggiorna.sh esegui            copia di sicurezza, poi regole dei permessi e automazioni puntate a questa copia, doctor
#   aggiorna.sh togli-terminale   toglie la copia installata da terminale (claude plugin uninstall), se non è questa
#
# Che cosa cambia (esegui): i percorsi della copia vecchia diventano quelli di questa nelle regole dei permessi del vault
# (.claude/settings.json e settings.local.json), nel .mcp.json, nella copia delle regole per i giri automatici e nei
# LaunchAgent di Metis (che si ricaricano); si aggiungono le regole nuove di questa versione (installa-permessi.sh) e le
# cartelle dei ruoli che mancano. Tutto si ripete senza danni: un secondo «esegui» non cambia niente.
# Che cosa non tocca: profilo, stati, correzioni, decisioni, regole di metodo, schede di dominio, CLAUDE.md, note e
# modelli già compilati; la configurazione resta com'è. L'onboarding non si rifà.
# Copia di sicurezza: <cartella della configurazione>/backup/aggiorna-AAAAMMGG-HHMMSS/, con LEGGIMI.txt per rimettere a posto.
# Uscita: 0 fatto, o niente da fare; 1 «controlla» ha trovato qualcosa da fare, o un passo non è riuscito;
#         2 nessuna installazione da aggiornare (configurazione, vault o profilo assenti).

set -uo pipefail
export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"
METIS_ROOT="${METIS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
METIS_ROOT="$(cd "$METIS_ROOT" && pwd -P)"
export METIS_ROOT
source "$METIS_ROOT/scripts/lib/config.sh"

AZ="${1:-}"
case "$AZ" in controlla|esegui|togli-terminale) ;; *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;; esac

metis_carica_config || { echo "aggiorna: ${METIS_ERRORE}. Nessuna installazione da aggiornare: per una nuova, skill installa." >&2; exit 2; }
CFG="${METIS_CONFIG:-$HOME/.config/metis/config}"
CFG_DIR="$(dirname "$CFG")"
LA="${METIS_LAUNCHAGENTS:-$HOME/Library/LaunchAgents}"
PLUGINS_JSON="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
versione() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/.claude-plugin/plugin.json" 2>/dev/null | head -1; }
VERS="$(versione "$METIS_ROOT")"

# Dove sta questa copia: lo si dice al cliente in parole sue.
case "$METIS_ROOT" in
  *"/Application Support/Claude/"*) DOVE="caricata nell'app di Claude" ;;
  */plugins/synced/*) DOVE="sincronizzata dall'account claude.ai" ;;
  */plugins/cache/*) DOVE="installata da terminale (catalogo)" ;;
  *) DOVE="cartella su disco" ;;
esac

# File con i percorsi del plugin dentro. Le regole e i .mcp.json sono JSON; i LaunchAgent sono plist.
FILE_JSON=("$METIS_VAULT/.claude/settings.json" "$METIS_VAULT/.claude/settings.local.json" "$METIS_VAULT/.mcp.json"
           "$CFG_DIR/permessi-routine.json" "$CFG_DIR/mcp-routine.json")
PLIST=()
for p in "$LA/$METIS_LABEL".*.plist; do [ -f "$p" ] && PLIST+=("$p"); done

# Le copie vecchie: le radici a cui puntano regole e LaunchAgent (la cartella che contiene scripts/ o hooks/), diverse
# da questa. Una radice che non esiste più conta lo stesso: le automazioni che la usano sono ferme.
radici_vecchie() {
  python3 - "$METIS_ROOT" "${FILE_JSON[@]}" -- ${PLIST[@]+"${PLIST[@]}"} <<'PY'
import json, os, plistlib, re, sys
root = sys.argv[1]; args = sys.argv[2:]; i = args.index("--"); js, pl = args[:i], args[i + 1:]
# Il percorso può contenere spazi (la cartella dell'app sta in «Application Support»): conta dal primo «/» della regola.
pat = re.compile(r'(/[^"\'*()<>]+?)/((?:scripts|hooks)/[A-Za-z0-9_./-]+)')
trovate = set()
def metis(m):  # è una copia di Metis? Lo stesso script esiste in questa copia, e la cartella (se c'è) è un plugin «metis»
    r, rel = "/" + m.group(1).lstrip("/"), m.group(2).rstrip("/")
    if not os.path.exists(os.path.join(root, rel.split(" ")[0])): return None
    pj = os.path.join(r, ".claude-plugin", "plugin.json")
    if os.path.isdir(r):
        try: return r if json.load(open(pj)).get("name") == "metis" else None
        except Exception: return None
    return r
def stringhe(x):
    if isinstance(x, str): yield x
    elif isinstance(x, dict):
        for v in x.values(): yield from stringhe(v)
    elif isinstance(x, list):
        for v in x: yield from stringhe(v)
for f in js:
    try: d = json.load(open(f))
    except Exception: continue
    for s in stringhe(d): trovate.update(r for m in pat.finditer(s) if (r := metis(m)))
for f in pl:
    try: d = plistlib.load(open(f, "rb"))
    except Exception: continue
    for s in d.get("ProgramArguments", []): trovate.update(r for m in pat.finditer(s) if (r := metis(m)))
# Le copie di Metis (anche quelle che non esistono più) diverse da questa.
for r in sorted(trovate):
    if os.path.realpath(r) == os.path.realpath(root): continue
    print(r)
PY
}

# Le copie installate da terminale: righe «id<TAB>installPath<TAB>versione» da installed_plugins.json.
copie_terminale() {
  [ -f "$PLUGINS_JSON" ] || return 0
  python3 - "$PLUGINS_JSON" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
for k, v in (d.get("plugins") or {}).items():
    if k.split("@")[0] != "metis": continue
    for e in v if isinstance(v, list) else [v]:
        print(f'{k}\t{e.get("installPath", "")}\t{e.get("version", "")}')
PY
}

VECCHIE=(); while IFS= read -r r; do [ -n "$r" ] && VECCHIE+=("$r"); done < <(radici_vecchie)
TERM=(); while IFS= read -r r; do [ -n "$r" ] && TERM+=("$r"); done < <(copie_terminale)
PROFILO="$METIS_CL/profilo-nucleo.md"

riepilogo() {
  echo "Questa copia di $METIS_PRODOTTO: versione ${VERS:-?}, $DOVE ($METIS_ROOT)."
  echo "Vault: $METIS_VAULT"
  if [ -f "$PROFILO" ]; then
    echo "Profilo presente: l'installazione c'è già, l'onboarding non si rifà."
    NA=$(metis_avvio_residui); [ "${NA:-0}" -gt 0 ] && echo "  (il profilo ha ancora $NA sezioni AVVIO: l'avvio si propone come sempre)"
  fi
  if [ "${#VECCHIE[@]}" -eq 0 ]; then echo "Regole e automazioni puntano già a questa copia."
  else
    for r in "${VECCHIE[@]}"; do
      if [ -d "$r" ]; then echo "Da riallineare: puntano a $r (versione $(versione "$r"))."
      else echo "Da riallineare: puntano a $r, che non esiste più (automazioni ferme)."; fi
    done
  fi
  for t in ${TERM[@]+"${TERM[@]}"}; do
    IFS=$'\t' read -r id ip v <<<"$t"
    if [ "$(cd "$ip" 2>/dev/null && pwd -P)" = "$METIS_ROOT" ]; then echo "Copia da terminale $id ($v): è questa."
    else echo "Copia da terminale ancora installata: $id ($v) in $ip → aggiorna.sh togli-terminale, per non averne due."; fi
  done
}

case "$AZ" in
controlla)
  [ -f "$PROFILO" ] || { riepilogo; echo "Profilo assente ($PROFILO): non è un'installazione da aggiornare. Skill installa."; exit 2; }
  riepilogo
  DAFARE=0; [ "${#VECCHIE[@]}" -gt 0 ] && DAFARE=1
  for t in ${TERM[@]+"${TERM[@]}"}; do IFS=$'\t' read -r id ip v <<<"$t"; [ "$(cd "$ip" 2>/dev/null && pwd -P)" = "$METIS_ROOT" ] || DAFARE=1; done
  [ "$DAFARE" -eq 0 ] && echo "Niente da fare."
  exit "$DAFARE" ;;

esegui)
  [ -f "$PROFILO" ] || { echo "aggiorna: profilo assente ($PROFILO): non è un'installazione da aggiornare. Skill installa." >&2; exit 2; }
  # Una copia in una cartella temporanea (estratta per una sola sessione) sparisce: i giri automatici resterebbero senza.
  case "$METIS_ROOT/" in /tmp/*|/private/tmp/*|/private/var/folders/*|/var/folders/*)
    if [ "${METIS_AGGIORNA_PROVA:-}" != 1 ]; then
      echo "aggiorna: questa copia del plugin sta in una cartella temporanea ($METIS_ROOT): non ci punto regole e giri automatici. Si lancia dalla copia installata (nell'app, o da terminale)." >&2; exit 1
    fi ;;
  esac
  riepilogo
  # 1. Copia di sicurezza: i file che cambiano, i LaunchAgent e la cartella di Claude intera (per scrupolo: non si tocca).
  B="$CFG_DIR/backup/aggiorna-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$B/file" || { echo "aggiorna: non riesco a creare la copia di sicurezza in $B" >&2; exit 1; }
  : > "$B/LEGGIMI.txt"
  for f in "$CFG" "${FILE_JSON[@]}" ${PLIST[@]+"${PLIST[@]}"} "$METIS_VAULT/CLAUDE.md" "$METIS_VAULT/CLAUDE.local.md"; do
    [ -f "$f" ] || continue
    n="$(printf '%s' "$f" | sed 's|^/||; s|/|__|g')"
    cp -p "$f" "$B/file/$n" && printf 'file/%s → %s\n' "$n" "$f" >> "$B/LEGGIMI.txt"
  done
  tar -czf "$B/cartella-di-claude.tgz" -C "$METIS_VAULT" "$METIS_RUOLO_CLAUDE" 2>/dev/null \
    && printf 'cartella-di-claude.tgz → %s/%s (estrarre con: tar -xzf cartella-di-claude.tgz -C "%s")\n' "$METIS_VAULT" "$METIS_RUOLO_CLAUDE" "$METIS_VAULT" >> "$B/LEGGIMI.txt"
  { echo; echo "Per tornare a com'era: copiare ogni file al suo posto, poi ricaricare i LaunchAgent (launchctl bootout e bootstrap)."; } >> "$B/LEGGIMI.txt"
  echo "Copia di sicurezza: $B"

  # 2. Percorsi: copia vecchia → questa copia, in ogni stringa delle regole e dei .mcp.json (la struttura resta com'è).
  ERR=0
  if [ "${#VECCHIE[@]}" -gt 0 ]; then
    python3 - "$METIS_ROOT" "${VECCHIE[@]}" -- "${FILE_JSON[@]}" <<'PY' || ERR=1
import json, os, sys
root = sys.argv[1]; a = sys.argv[2:]; i = a.index("--"); vecchie, files = a[:i], a[i + 1:]
def nuovo(s):
    for v in vecchie:
        if s == v: return root
        s = s.replace(v + "/", root + "/")
    return s
def giro(x):
    if isinstance(x, str): return nuovo(x)
    if isinstance(x, dict): return {k: giro(v) for k, v in x.items()}
    if isinstance(x, list):
        out = []
        for v in x:
            v = giro(v)
            if v not in out: out.append(v)          # una regola già presente con il percorso nuovo non si duplica
        return out
    return x
for f in files:
    if not os.path.isfile(f): continue
    try: d = json.load(open(f))
    except Exception as e:
        print(f"aggiorna: {f} non è JSON leggibile, lasciato com'è ({e})", file=sys.stderr); continue
    n = giro(d)
    if n != d:
        json.dump(n, open(f, "w"), indent=2, ensure_ascii=False); print(f"✅ percorsi aggiornati: {f}")
PY
  fi

  # 3. Regole di questa versione. installa-permessi.sh aggiunge al vault le voci mancanti e riscrive da capo la copia
  #    per i giri: le regole che i moduli vi avevano aggiunto (Telegram, Google…) si rimettono dalla copia riallineata.
  R="$CFG_DIR/permessi-routine.json"; RPRIMA="$B/permessi-routine.riallineata.json"
  [ -f "$R" ] && cp "$R" "$RPRIMA"
  bash "$METIS_ROOT/scripts/installa-struttura.sh" crea >/dev/null || ERR=1
  bash "$METIS_ROOT/scripts/installa-permessi.sh" | sed 's/^/  /' || ERR=1
  if [ -f "$RPRIMA" ]; then
    python3 - "$R" "$RPRIMA" <<'PY' || ERR=1
import json, sys
r, prima = sys.argv[1], sys.argv[2]
d, p = json.load(open(r)), json.load(open(prima))
dp, pp = d.setdefault("permissions", {}), p.get("permissions", {})
for k in ("allow", "ask", "deny", "additionalDirectories"):
    l = dp.setdefault(k, [])
    for v in pp.get(k, []):
        if v not in l: l.append(v)
json.dump(d, open(r, "w"), indent=2, ensure_ascii=False)
PY
  fi
  # Le regole degli script del plugin anche con il percorso fra virgolette, come si scrive un percorso con spazi
  # (la copia dell'app sta in «Application Support»): senza, nei giri automatici quei comandi sarebbero negati.
  for f in "$METIS_VAULT/.claude/settings.json" "$R"; do
    [ -f "$f" ] || continue
    python3 - "$f" "$METIS_ROOT" <<'PY' || ERR=1
import json, re, sys
f, root = sys.argv[1], sys.argv[2]
d = json.load(open(f)); p = d.get("permissions", {})
pat = re.compile(re.escape(root) + r'(/scripts/[A-Za-z0-9_./-]+)')
for k in ("allow", "ask", "deny"):
    l = p.get(k, [])
    for v in list(l):
        if v.startswith("Bash(") and (root + "/scripts/") in v and ('"' + root) not in v:
            q = pat.sub(lambda m: '"' + root + m.group(1) + '"', v)
            if q not in l: l.append(q)
json.dump(d, open(f, "w"), indent=2, ensure_ascii=False)
PY
  done

  # 4. LaunchAgent di Metis: stessi giri e orari, con i percorsi di questa copia; si ricaricano.
  for p in ${PLIST[@]+"${PLIST[@]}"}; do
    nome="$(basename "$p" .plist)"; nome="${nome#"$METIS_LABEL".}"
    if [ "${#VECCHIE[@]}" -gt 0 ]; then
      python3 - "$p" "$METIS_ROOT" "${VECCHIE[@]}" <<'PY' || { ERR=1; continue; }
import plistlib, sys
p, root, vecchie = sys.argv[1], sys.argv[2], sys.argv[3:]
d = plistlib.load(open(p, "rb"))
args = d.get("ProgramArguments", [])
nuovi = []
for s in args:
    for v in vecchie: s = s.replace(v + "/", root + "/")
    nuovi.append(s)
if nuovi != args:
    d["ProgramArguments"] = nuovi
    with open(p, "wb") as f: plistlib.dump(d, f)
    print(f"✅ LaunchAgent riallineato: {p}")
PY
      plutil -lint "$p" >/dev/null || { echo "❌ plist non valido dopo la modifica: $p (l'originale è nella copia di sicurezza)"; ERR=1; continue; }
    fi
    bash "$METIS_ROOT/scripts/lib/launchd.sh" carica "$nome" | sed 's/^/  /'
  done

  # 5. Verifica: nessuna regola né automazione punta più alla copia vecchia; poi il doctor.
  PLIST=(); for p in "$LA/$METIS_LABEL".*.plist; do [ -f "$p" ] && PLIST+=("$p"); done
  RESTANO="$(radici_vecchie)"
  if [ -n "$RESTANO" ]; then echo "❌ restano riferimenti a: $RESTANO"; ERR=1
  else echo "✅ regole e automazioni puntano a questa copia ($METIS_ROOT)"; fi
  bash "$METIS_ROOT/scripts/doctor.sh" >/dev/null 2>&1
  [ -f "$METIS_CL/doctor.md" ] && echo "Doctor: $(grep -m1 -E '^\*\*(🟢|🟡|🔴)' "$METIS_CL/doctor.md" | sed 's/\*\*//g')"
  for t in ${TERM[@]+"${TERM[@]}"}; do
    IFS=$'\t' read -r id ip v <<<"$t"
    [ "$(cd "$ip" 2>/dev/null && pwd -P)" = "$METIS_ROOT" ] || echo "Resta da togliere la copia da terminale $id: aggiorna.sh togli-terminale"
  done
  exit "$ERR" ;;

togli-terminale)
  [ "${#TERM[@]}" -eq 0 ] && { echo "Nessuna copia di $METIS_PRODOTTO installata da terminale."; exit 0; }
  CL_BIN="${METIS_CLAUDE:-$(command -v claude || true)}"
  ERR=0
  for t in "${TERM[@]}"; do
    IFS=$'\t' read -r id ip v <<<"$t"
    if [ "$(cd "$ip" 2>/dev/null && pwd -P)" = "$METIS_ROOT" ]; then
      echo "La copia da terminale $id è quella in uso adesso: non la tolgo. Prima si carica lo zip nell'app e si apre una sessione nuova nel tab Code."
      ERR=1; continue
    fi
    if [ -z "$CL_BIN" ]; then echo "Comando claude non trovato. Nel Terminale: claude plugin uninstall $id"; ERR=1; continue; fi
    "$CL_BIN" plugin uninstall "$id" && echo "✅ tolta la copia da terminale $id" || { echo "❌ claude plugin uninstall $id non riuscito"; ERR=1; }
    # Il catalogo da cui veniva, se si chiama come il plugin e non serve ad altro (strada senza GitHub: catalogo «metis»).
    mk="${id#*@}"
    if [ "$mk" = metis ] && [ -n "$CL_BIN" ]; then
      "$CL_BIN" plugin marketplace remove "$mk" >/dev/null 2>&1 && echo "✅ tolto anche il catalogo «${mk}»"
    fi
    case "$ip" in "$HOME"/Metis|"$HOME"/Metis/) echo "La cartella $ip non serve più: si può cancellare dopo aver controllato che il doctor sia verde." ;; esac
  done
  exit "$ERR" ;;
esac
