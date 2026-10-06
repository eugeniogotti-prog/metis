#!/usr/bin/env python3
"""guardia-docx.py — prima di (ri)scrivere un DOCX, controlla che nessuno ci stia lavorando.

Uso:  guardia-docx.py verifica FILE.docx   uscita 0 = si può scrivere, 3 = fermarsi (motivo su stderr)
      guardia-docx.py registra FILE.docx   dopo aver scritto: annota l'impronta del file prodotto

Due controlli:
1. **Word ha il file aperto**: accanto al documento esiste il lock `~$…` (Word lo crea con
   «~$» più il nome, togliendo i primi due caratteri se il nome è lungo; si cercano entrambe
   le forme).
2. **Il file è stato modificato dopo l'ultimo export**: l'impronta (sha256) scritta da
   `registra` in `.NOME.docx.impronta` non corrisponde più al file. Vuol dire che qualcuno
   l'ha aperto e salvato, e riscriverlo cancellerebbe quelle modifiche. Se l'impronta non
   esiste (file mai prodotto da noi, o prodotto prima del 6/10/2026), non si blocca.

Portato il 6/10/2026 dal vault di riferimento, dove in pochi giorni tre documenti Word sono stati riscritti mentre
il loro autore li aveva aperti, in un caso con le sue modifiche perse, anche dopo che la regola era scritta. La regola da
sola non reggeva: ora la fa rispettare lo script.
"""
import hashlib, os, sys


def impronta_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for blocco in iter(lambda: f.read(1 << 16), b""):
            h.update(blocco)
    return h.hexdigest()


def sidecar(p):
    d, n = os.path.split(os.path.abspath(p))
    return os.path.join(d, f".{n}.impronta")


def lock(p):
    d, n = os.path.split(os.path.abspath(p))
    candidati = {f"~${n}", f"~${n[2:]}" if len(n) > 2 else None}
    return [c for c in candidati if c and os.path.exists(os.path.join(d, c))]


def verifica(p):
    if not os.path.exists(p):
        return 0
    l = lock(p)
    if l:
        print(f"✗ {p} è aperto in Word (lock {l[0]}): chiudilo, oppure scrivi su un altro file con -o.", file=sys.stderr)
        return 3
    s = sidecar(p)
    if os.path.exists(s):
        attesa = open(s).read().strip()
        if attesa and attesa != impronta_file(p):
            print(f"✗ {p} è stato modificato dopo l'ultimo export (qualcuno l'ha aperto e salvato): "
                  f"riscriverlo cancellerebbe quelle modifiche. Scrivi su un altro file con -o, "
                  f"oppure usa --forza se sei sicuro.", file=sys.stderr)
            return 3
    return 0


def registra(p):
    with open(sidecar(p), "w") as f:
        f.write(impronta_file(p) + "\n")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("verifica", "registra"):
        sys.exit(__doc__)
    sys.exit({"verifica": verifica, "registra": registra}[sys.argv[1]](sys.argv[2]))
