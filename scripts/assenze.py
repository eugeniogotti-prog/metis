#!/usr/bin/env python3
"""assenze.py — trova le assenze dichiarate senza dire dove e come si è cercato.

Uso:  assenze.py < testo        stampa una riga per ogni assenza senza ricerca dichiarata
                                (uscita 0 = nessuna, 1 = trovate)

Un'«assenza» è una frase come «la mail non risulta», «non c'è nessuna bozza», «non trovo il file», «mai arrivata».
È accompagnata da una ricerca dichiarata se entro tre righe compare dove o come si è cercato (cercato, grep,
verificato, controllato, query, in:sent, occorrenze…) oppure la marca esplicita «[non verificato]».

Portato il 6/10/2026 dal vault di riferimento, dove l'errore più frequente di un mese era dichiarare che qualcosa non
c'è dopo una ricerca che non poteva trovarlo, nonostante la regola «verificare per smentire». La regola da sola non
reggeva: questo controllo, chiamato dall'hook valida-scrittura.sh sulle scritture negli stati, nei log di sessione e in
dominio/, la ricorda nel momento in cui serve. Le affermazioni di merito («la norma non prevede…») non lo fanno scattare.
"""
import re, sys

OGGETTI = (r"(?:file|mail|e-?mail|messaggi?o?|nota|note|riga|righe|cartell[ae]|documento|"
           r"allegat[oi]|bozz[ae]|risposta|traccia|tracce|impegno|evento|eventi|log|script|job|"
           r"commit|transcript|pdf|docx|thread)")
VERBI = (r"(?:non c'è|non c'era|non c'erano|non esiste|non esistono|non risulta|non risultano|"
         r"non trovo|non ho trovato|non si trova|mai (?:arrivat|partit|inviat)\w)")
ASSENZA = re.compile(VERBI + r"\s+(?:\S+\s+){0,3}?" + OGGETTI + "|" + OGGETTI + r"\s+(?:\S+\s+){0,4}?" + VERBI, re.I)
RICERCA = re.compile(r"cercat|cerco|grep|verific|ricerc|controllat|controll[oa]|query|search|in:sent|"
                     r"letto|riaperto|scansion|occorrenz|\[non verificato\]|non ho verificato", re.I)


def trova(testo):
    righe = testo.split("\n")
    out = []
    for i, r in enumerate(righe):
        m = ASSENZA.search(r)
        if m and not RICERCA.search("\n".join(righe[max(0, i - 3):i + 4])):
            out.append(r[max(0, m.start() - 50):m.end() + 50].strip())
    return out


if __name__ == "__main__":
    trovate = trova(sys.stdin.read())
    for t in trovate:
        print(t)
    sys.exit(1 if trovate else 0)
