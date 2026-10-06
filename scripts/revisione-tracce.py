#!/usr/bin/env python3
"""revisione-tracce.py — prepara le trascrizioni di un mese per la revisione mensile (skill `revisione-mensile`).

Uso (con la configurazione caricata):
  revisione-tracce.py prepara AAAA-MM [--per-lotto 600000]
      cerca le trascrizioni di Claude Code delle sessioni aperte nel vault (o in una sua sottocartella), in
      ~/.claude/projects/<vault>*/ (o $METIS_CLAUDE_PROJECTS); per ogni sessione con messaggi del mese scrive un
      testo leggibile, con token e chiavi oscurati (segreti.py), in una cartella temporanea FUORI dal vault:
      ~/Library/Caches/metis/revisione-AAAA-MM/tracce/; divide i file in lotti (lotti.json) per i subagenti.
  revisione-tracce.py pulisci AAAA-MM
      cancella la cartella temporanea, a revisione finita.

Le trascrizioni non entrano nel vault (decisione del 30/9/2026): la revisione le legge oscurate, fuori dal vault, e
nel vault resta solo il rapporto. Claude Code tiene le proprie trascrizioni per circa 30 giorni: la revisione di un
mese si fa nei primi giorni del mese successivo, prima che spariscano.
"""
import json, os, shutil, sys
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from segreti import oscura

VAULT = os.environ.get("METIS_VAULT", "").rstrip("/")
BASE = os.environ.get("METIS_CLAUDE_PROJECTS") or os.path.expanduser("~/.claude/projects")


def cartella(mese):
    return os.path.expanduser("~/Library/Caches/metis/revisione-%s" % mese)


def slug(p):
    return "".join(c if c.isalnum() else "-" for c in os.path.realpath(p))


def testo(jsonl, mese):
    righe = []
    for riga in open(jsonl, encoding="utf-8", errors="ignore"):
        try:
            o = json.loads(riga)
        except ValueError:
            continue
        ts = o.get("timestamp", "")
        try:
            quando = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
        except ValueError:
            continue
        if quando.strftime("%Y-%m") != mese:
            continue
        tipo = o.get("type")
        cont = (o.get("message") or {}).get("content", "")
        for b in (cont if isinstance(cont, list) else [{"type": "text", "text": cont}]):
            if not isinstance(b, dict):
                continue
            if b.get("type") == "text" and (b.get("text") or "").strip():
                t = b["text"].strip()
                if t.startswith("<system-reminder>"):
                    continue
                righe.append("[%s] %s: %s\n" % (quando.strftime("%d/%m %H:%M"), "Utente" if tipo == "user" else "Claude", oscura(t)))
            elif b.get("type") == "tool_use" and tipo == "assistant":
                righe.append("  [strumento: %s] %s\n" % (b.get("name"), oscura(json.dumps(b.get("input"), ensure_ascii=False))[:300]))
            elif b.get("type") == "tool_result":
                c = b.get("content")
                c = c if isinstance(c, str) else json.dumps(c, ensure_ascii=False)
                righe.append("  [esito] %s\n" % oscura(c)[:300].replace("\n", " "))
    return "".join(righe)


def prepara(mese, per_lotto):
    if not VAULT:
        sys.exit("revisione-tracce: vault non configurato")
    radice = slug(VAULT)
    dirs = [os.path.join(BASE, d) for d in sorted(os.listdir(BASE)) if d == radice or d.startswith(radice + "-")] if os.path.isdir(BASE) else []
    out = cartella(mese)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(os.path.join(out, "tracce"))
    file = []
    for d in dirs:
        for f in sorted(os.listdir(d)):
            if not f.endswith(".jsonl"):
                continue
            t = testo(os.path.join(d, f), mese)
            if not t:
                continue
            primo = t[1:6].replace("/", "-")
            nome = "%s-%s.md" % (primo, f[:8])
            open(os.path.join(out, "tracce", nome), "w", encoding="utf-8").write(t)
            file.append((nome, len(t)))
    lotti, cor, dim = [], [], 0
    for nome, n in sorted(file):
        if cor and dim + n > per_lotto:
            lotti.append(cor); cor, dim = [], 0
        cor.append(nome); dim += n
    if cor:
        lotti.append(cor)
    json.dump({"mese": mese, "cartella": out, "lotti": lotti}, open(os.path.join(out, "lotti.json"), "w"), ensure_ascii=False, indent=1)
    print("revisione-tracce: %d sessioni del %s, %d caratteri, %d lotti → %s" % (len(file), mese, sum(n for _, n in file), len(lotti), out))


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) < 2 or a[0] not in ("prepara", "pulisci"):
        sys.exit(__doc__)
    if a[0] == "pulisci":
        shutil.rmtree(cartella(a[1]), ignore_errors=True)
        print("revisione-tracce: cartella temporanea del %s cancellata" % a[1])
    else:
        n = int(a[a.index("--per-lotto") + 1]) if "--per-lotto" in a else 600000
        prepara(a[1], n)
