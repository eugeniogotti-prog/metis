#!/usr/bin/env python3
"""connettori.py — stato dei connettori di claude.ai visti da Claude Code, per i controlli dei moduli google e microsoft.

Due fonti, perché nessuna basta da sola (verificato il 6/11/2026, Claude Code 2.1.318-319):
- `claude mcp list`: righe «claude.ai Gmail: <url> - ✔ Connected» (oppure «! Needs authentication», «✗ Failed…»).
  È la fonte affidabile: su Linux senza schermo i connettori funzionano ma non compaiono nell'evento di avvio.
- l'evento di avvio di `claude -p --output-format stream-json --verbose` (mcp_servers con nome e stato). Prima dell'evento
  ci possono essere gli eventi degli hook: si legge tutto il testo, non solo le prime righe.

Uso: connettori.py <file con l'uscita di mcp list> <file con l'uscita stream-json> <chiave> [<chiave> ...]
     chiave = parola da cercare nel nome del connettore (gmail, calendar, drive, microsoft)
Stampa una riga per chiave: «<chiave>\t<stato>\t<nome>», stato = connected | needs-auth | failed | assente.
"""
import json, re, sys

lista, avvio, chiavi = sys.argv[1], sys.argv[2], sys.argv[3:]
stati = {}  # nome → stato
try:
    for r in open(lista, encoding="utf-8", errors="replace"):
        m = re.match(r"^(claude\.ai [^:]+):.* - (.+)$", r.strip())
        if not m: continue
        s = m.group(2).lower()
        stati[m.group(1)] = "connected" if "connected" in s else ("needs-auth" if "auth" in s else "failed")
except OSError:
    pass
try:
    for r in open(avvio, encoding="utf-8", errors="replace"):
        try: d = json.loads(r)
        except ValueError: continue
        if d.get("type") == "system" and d.get("subtype") == "init":
            for x in d.get("mcp_servers", []):
                n = x.get("name", "")
                if n.startswith("claude.ai") and n not in stati: stati[n] = x.get("status") or "failed"
except OSError:
    pass
for k in chiavi:
    s = sorted(n for n in stati if k.lower() in n.lower())
    if not s: print(f"{k}\tassente\t"); continue
    # se ci sono più connettori con la chiave nel nome, conta il primo collegato
    buono = next((n for n in s if stati[n] == "connected"), s[0])
    print(f"{k}\t{stati[buono]}\t{buono}")
