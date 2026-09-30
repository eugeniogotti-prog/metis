#!/usr/bin/env python3
"""trascrizione.py — rende leggibile la trascrizione di una sessione di Claude Code, per ricostruire il log di una
sessione chiusa senza «chiudi sessione». Stampa sullo schermo e non salva niente: la trascrizione resta dov'è,
in ~/.claude/projects/, fuori dal vault.

Uso: trascrizione.py <file .jsonl> [--giorno YYYY-MM-DD]
Stampa i messaggi dell'utente, i testi di Claude e i nomi degli strumenti usati, in ordine; con --giorno solo quelli
di quel giorno (ora locale). Gli avvisi di sistema si saltano.
"""
import json, sys
from datetime import datetime


def main(a):
    if not a:
        print(__doc__); return 2
    giorno = a[a.index("--giorno") + 1] if "--giorno" in a else None
    for riga in open(a[0], encoding="utf-8", errors="ignore"):
        try:
            o = json.loads(riga)
        except ValueError:
            continue
        ts = o.get("timestamp", "")
        if giorno and ts:
            try:
                if datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%d") != giorno:
                    continue
            except ValueError:
                pass
        tipo = o.get("type")
        contenuto = (o.get("message") or {}).get("content", "")
        blocchi = contenuto if isinstance(contenuto, list) else [{"type": "text", "text": contenuto}]
        for b in blocchi:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "text" and (b.get("text") or "").strip():
                t = b["text"].strip()
                if t.startswith("<system-reminder>"):
                    continue
                print(("Utente: " if tipo == "user" else "Claude: ") + t + "\n")
            elif b.get("type") == "tool_use" and tipo == "assistant":
                print(f"  [strumento: {b.get('name')}]")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
