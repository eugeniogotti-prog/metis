#!/usr/bin/env python3
"""segreti.py — riconosce e oscura i segreti nel testo (token, chiavi API, chiavi private, password).

Uso come modulo:   from segreti import oscura        # testo → testo con i segreti oscurati
Uso da terminale:  segreti.py --cerca DIR [DIR…] [--escludi DIR …]
                   elenca i file .md che contengono segreti: stampa solo il file, il tipo e quante volte, mai il
                   segreto. Le cartelle nascoste e quelle indicate con --escludi (la cartella riservata) si saltano.
                   Uscita 0 = nessuno, 1 = trovati.

Portato il 6/10/2026 dal vault di riferimento, dove un hook che esportava le trascrizioni le scriveva così com'erano
e un token è rimasto in chiaro per mesi. L'oscuramento va fatto dove il testo viene scritto, non dopo: in Metis lo
usa trascrizione.py; la scansione la fa il doctor. Un formato nuovo di segreto si aggiunge qui e vale per tutti.
"""
import os, re, sys

# (nome, espressione, gruppo da conservare davanti al segreto)
REGOLE = [
    ("telegram", re.compile(r"\b\d{8,10}:AA[A-Za-z0-9_-]{30,}"), None),
    ("anthropic/openai", re.compile(r"\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{20,}"), None),
    ("github", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}"), None),
    ("groq", re.compile(r"\bgsk_[A-Za-z0-9]{30,}"), None),
    ("google", re.compile(r"\bAIza[0-9A-Za-z_-]{35}"), None),
    ("aws", re.compile(r"\bAKIA[0-9A-Z]{16}\b"), None),
    ("bearer", re.compile(r"(Bearer\s+)[A-Za-z0-9._~+/-]{20,}=*"), 1),
    ("chiave-privata", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.S), None),
    # password: solo nella forma chiave=valore o chiave: valore, senza spazi nel valore
    ("password", re.compile(r"((?:password|passwd|pwd|api[_-]?key|secret|token)\s*[:=]\s*[\"']?)(?![\[<{($%])[^\s\"'`,;)]{6,}", re.I), 1),
]


def oscura(testo):
    for nome, rx, tieni in REGOLE:
        if tieni:
            testo = rx.sub(lambda m: m.group(tieni) + f"[{nome.upper()}-OSCURATO]", testo)
        else:
            testo = rx.sub(f"[{nome.upper()}-OSCURATO]", testo)
    return testo


def trova(testo):
    return {nome: len(rx.findall(testo)) for nome, rx, _ in REGOLE if rx.search(testo)}


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0] != "--cerca":
        sys.exit(__doc__)
    escludi, radici, i = [], [], 1
    while i < len(a):
        if a[i] == "--escludi" and i + 1 < len(a):
            escludi.append(os.path.abspath(a[i + 1])); i += 2
        else:
            radici.append(a[i]); i += 1
    trovati = 0
    for radice in radici:
        for d, dirs, fs in os.walk(radice):
            dirs[:] = [x for x in dirs if not x.startswith(".") and os.path.abspath(os.path.join(d, x)) not in escludi]
            for f in fs:
                if not f.endswith(".md"):
                    continue
                p = os.path.join(d, f)
                try:
                    r = trova(open(p, encoding="utf-8", errors="ignore").read())
                except OSError:
                    continue
                r.pop("password", None)  # troppo rumorosa per un allarme: vale solo per l'oscuramento
                if r:
                    trovati += 1
                    print(f"{p}\t" + ", ".join(f"{k} ×{v}" for k, v in r.items()))
    sys.exit(1 if trovati else 0)
