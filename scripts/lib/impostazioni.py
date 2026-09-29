#!/usr/bin/env python3
"""impostazioni.py — aggiunge voci ai file JSON di Claude Code senza togliere quelle del cliente.

Uso:
  impostazioni.py mcp <file .mcp.json> <nome> '<json del server>'     aggiunge o sostituisce il server <nome>
  impostazioni.py lista <file settings.json> <chiave.puntata> <valore>  aggiunge <valore> alla lista, se manca
                                                                        (es. permissions.allow, enabledMcpjsonServers)
  impostazioni.py leggi <file> <chiave.puntata>                          stampa il valore in JSON

Il file si riscrive intero, con indentazione di due spazi; se non esiste si crea. Una copia del file com'era
va in <file>.prima-di-metis la prima volta che Metis lo tocca.
"""
import json, os, shutil, sys


def carica(p):
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    return {}


def salva(p, d):
    if os.path.exists(p) and not os.path.exists(p + ".prima-di-metis"):
        shutil.copy2(p, p + ".prima-di-metis")
    os.makedirs(os.path.dirname(os.path.abspath(p)), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")


def nodo(d, chiave, crea=True):
    parti = chiave.split(".")
    for k in parti[:-1]:
        if k not in d:
            if not crea:
                return None, None
            d[k] = {}
        d = d[k]
    return d, parti[-1]


def main(a):
    if len(a) < 3:
        print(__doc__); return 2
    azione, f = a[0], a[1]
    d = carica(f)
    if azione == "mcp" and len(a) == 4:
        d.setdefault("mcpServers", {})[a[2]] = json.loads(a[3])
        salva(f, d); print(f"server {a[2]} in {f}"); return 0
    if azione == "lista" and len(a) == 4:
        padre, k = nodo(d, a[2])
        lista = padre.setdefault(k, [])
        if a[3] not in lista:
            lista.append(a[3]); salva(f, d); print(f"aggiunto a {a[2]}: {a[3]}")
        else:
            print(f"già presente in {a[2]}: {a[3]}")
        return 0
    if azione == "leggi" and len(a) == 3:
        padre, k = nodo(d, a[2], crea=False)
        print(json.dumps(padre.get(k) if padre else None, ensure_ascii=False)); return 0
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
