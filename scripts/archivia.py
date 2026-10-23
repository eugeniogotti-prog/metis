#!/usr/bin/env python3
"""archivia.py — parte meccanica dell'archiviazione di un lavoro chiuso (skill `archiviazione`).

Uso (le variabili arrivano dalla configurazione, letta da scripts/lib/config.sh):
  archivia.py ricognizione [--filo <stato>] [--lavoro <cartella>]
      stampa che cosa si sta per archiviare: impegni aperti, attese «◇», persone, cartella su disco,
      note del lavoro e quante altre note le citano. Non scrive niente.
  archivia.py esegui [--filo <stato>] [--lavoro <cartella>] --motivo "…" --distillato "…" --istanza <chi>
      1. rifiuta se lo stato ha impegni «- [ ]» o attese «◇» aperte (si chiudono prima, con il cliente);
      2. stato: status chiuso, ultima-mossa e updated_at di oggi, prossima-azione «nessuna (archiviato)»,
         riga di chiusura con motivo e distillato, marcatore; poi lo sposta in <Claude>/stati/archivio/;
      3. cartella del lavoro: dalla cartella PROGETTI all'ARCHIVIO (sotto l'anno, se METIS_ARCHIVIO_PER_ANNO
         non è «no»); rifiuta se la destinazione esiste già;
      4. cartella su disco: resta dov'è (lo stato archiviato conserva `fonte-primaria:` e la mappa la riconosce);
         se però è la cartella del lavoro (documenti accanto alle note, METIS_DOCUMENTI=accanto) si sposta con lui
         e la `fonte-primaria:` dello stato archiviato si aggiorna alla posizione nuova.
         Se METIS_FONTI_ARCHIVIO indica una cartella, stampa la proposta di spostamento: si sposta solo a mano,
         con il sì del cliente, perché spostarla rompe i riferimenti nelle mail e nei documenti.
  --filo e --lavoro: almeno uno. Un lavoro con altri stati ancora vivi non si sposta (lo dice la ricognizione).
  --distillato è obbligatorio: dove è finita la conoscenza riusabile, oppure «nessuno: <motivo>».

Sposta e non cancella: tutto è reversibile. Obsidian risolve i wikilink per nome, quindi di norma i link
reggono; la ricognizione dice quante note citano quelle che si spostano. Non entra nella cartella riservata.
Codici: 0 fatto, 1 rifiutato (il motivo su stdout), 2 uso sbagliato.
"""
import datetime
import os
import re
import shutil
import sys
import unicodedata


def nfc(s):
    return unicodedata.normalize("NFC", s)


E = os.environ.get
VAULT = (E("METIS_VAULT") or "").rstrip("/")
CL = E("METIS_CL") or os.path.join(VAULT, E("METIS_RUOLO_CLAUDE", "_Claude"))
STATI = os.path.join(CL, "stati")
PROGETTI = os.path.join(VAULT, E("METIS_RUOLO_PROGETTI", "")) if E("METIS_RUOLO_PROGETTI") else ""
ARCHIVIO = os.path.join(VAULT, E("METIS_RUOLO_ARCHIVIO", "")) if E("METIS_RUOLO_ARCHIVIO") else ""
RISERVATA = os.path.join(VAULT, E("METIS_RUOLO_RISERVATA")) if E("METIS_RUOLO_RISERVATA") else ""
PER_ANNO = (E("METIS_ARCHIVIO_PER_ANNO") or "sì").lower() not in ("no", "0", "false")
FONTI = os.path.expanduser(E("METIS_FONTI") or "").rstrip("/")
try:
    OGGI = datetime.date.fromisoformat(E("METIS_OGGI")) if E("METIS_OGGI") else datetime.date.today()
except ValueError:
    OGGI = datetime.date.today()


def arg(nome):
    a = sys.argv
    return a[a.index(nome) + 1] if nome in a and a.index(nome) + 1 < len(a) else ""


def leggi(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def aperti(testo):
    """(impegni aperti, attese ◇ ancora vive). Si saltano i commenti e le righe d'esempio del modello ({{…}})."""
    righe = [r for r in re.sub(r"<!--.*?-->", "", testo, flags=re.S).splitlines() if "{{" not in r]
    imp = [r.strip() for r in righe if re.match(r"^\s*- \[ \]", r)]
    att = [r.strip() for r in righe if re.match(r"^\s*(- )?◇", r)]
    return imp, att


def campo(testo, chiave):
    m = re.search(r"^%s:\s*(.*)$" % re.escape(chiave), testo.split("\n---", 1)[0], re.M)
    return re.sub(r"\s+#.*$", "", m.group(1)).strip().strip("'\"") if m else ""


def assoluto(fp):
    """fonte-primaria come percorso assoluto, con le regole del doctor: assoluta, con ~, o relativa alla cartella fonti."""
    if not fp:
        return ""
    if fp.startswith("/") or fp.startswith("~"):
        return os.path.expanduser(fp).rstrip("/")
    return os.path.join(FONTI, fp).rstrip("/") if FONTI else ""


def dentro(p, cartella):
    return bool(p and cartella) and (os.path.realpath(p) == os.path.realpath(cartella) or os.path.realpath(p).startswith(os.path.realpath(cartella) + os.sep))


def imposta(testo, chiave, valore):
    """Imposta una chiave del frontmatter: la sostituisce se c'è, altrimenti la aggiunge in fondo."""
    if not testo.startswith("---\n"):
        return testo
    fine = testo.index("\n---", 4)
    fm, resto = testo[:fine], testo[fine:]
    riga = "%s: %s" % (chiave, valore)
    if re.search(r"^%s:" % re.escape(chiave), fm, re.M):
        fm = re.sub(r"^%s:.*$" % re.escape(chiave), riga, fm, count=1, flags=re.M)
    else:
        fm += "\n" + riga
    return fm + resto


def tokens(x):
    return {t for t in re.split(r"[^a-z0-9àèéìòù]+", nfc(x).lower()) if len(t) >= 2}


def note_di(cartella):
    out = []
    for dp, dn, fn in os.walk(cartella):
        dn[:] = [d for d in dn if not d.startswith(".")]
        out += [os.path.join(dp, f) for f in fn if f.endswith(".md")]
    return out


def citanti(note, escludi):
    """Quante note del vault fuori da `escludi` linkano almeno una delle note date."""
    nomi = {nfc(os.path.basename(n)[:-3]) for n in note}
    if not nomi:
        return 0
    pat = re.compile(r"\[\[(%s)(\||#|\]\])" % "|".join(re.escape(n) for n in nomi))
    n = 0
    for dp, dn, fn in os.walk(VAULT):
        dn[:] = [d for d in dn if not d.startswith(".") and not (RISERVATA and os.path.join(dp, d) == RISERVATA)]
        if nfc(dp).startswith(nfc(escludi)):
            continue
        for f in fn:
            if f.endswith(".md"):
                try:
                    if pat.search(nfc(leggi(os.path.join(dp, f)))):
                        n += 1
                except OSError:
                    pass
    return n


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("ricognizione", "esegui"):
        print(__doc__)
        return 2
    if not VAULT or not os.path.isdir(VAULT):
        print("archivia: vault non configurato")
        return 2
    filo, lavoro = arg("--filo"), arg("--lavoro")
    if not filo and not lavoro:
        print("archivia: serve --filo o --lavoro")
        return 2
    sp = os.path.join(STATI, filo + ".md") if filo else ""
    if filo and not os.path.isfile(sp):
        print("archivia: stato non trovato: %s" % sp)
        return 1
    lp = os.path.join(PROGETTI, lavoro) if lavoro and PROGETTI else ""
    if lavoro and not os.path.isdir(lp):
        print("archivia: cartella del lavoro non trovata: %s" % lp)
        return 1
    testo = leggi(sp) if sp else ""
    imp, att = aperti(testo)
    altri = []
    if lavoro:   # altri stati vivi che citano o seguono questo lavoro
        for f in sorted(os.listdir(STATI)):
            if f.endswith(".md") and not f.startswith("_") and f != filo + ".md":
                t = leggi(os.path.join(STATI, f))
                ts, tl = tokens(f[:-3]), tokens(lavoro)
                per_nome = bool(ts) and (ts <= tl or (len(tl) >= 2 and tl <= ts))   # stesso criterio della mappa
                if per_nome or (E("METIS_RUOLO_PROGETTI", "") + "/" + lavoro) in t or "[[" + lavoro + "]]" in t:
                    altri.append(f[:-3])
    anno = str(OGGI.year)
    dest = os.path.join(ARCHIVIO, anno, lavoro) if (lavoro and PER_ANNO) else (os.path.join(ARCHIVIO, lavoro) if lavoro else "")

    if sys.argv[1] == "ricognizione":
        print("## Ricognizione per l'archiviazione (%s)" % OGGI.isoformat())
        if sp:
            print("- stato: %s (status: %s, ultima mossa: %s)" % (filo, campo(testo, "status") or "—", campo(testo, "ultima-mossa") or "—"))
            print("- impegni aperti: %d%s" % (len(imp), "".join("\n    " + x for x in imp)))
            print("- attese ◇: %d%s" % (len(att), "".join("\n    " + x for x in att)))
            print("- persone: %s" % (campo(testo, "persone") or "—"))
            if lp and dentro(assoluto(campo(testo, "fonte-primaria")), lp):
                print("- cartella su disco: %s (è la cartella del lavoro: si sposta con lui)" % campo(testo, "fonte-primaria"))
            else:
              print("- cartella su disco: %s (resta dov'è%s)" % (campo(testo, "fonte-primaria") or "—",
                  "; proposta di spostamento in %s solo con il sì del cliente" % E("METIS_FONTI_ARCHIVIO") if E("METIS_FONTI_ARCHIVIO") else ""))
        if lp:
            note = note_di(lp)
            print("- lavoro: %s, %d note, citate da %d note fuori dal lavoro" % (lavoro, len(note), citanti(note, lp)))
            print("- destinazione: %s%s" % (os.path.relpath(dest, VAULT), " (ESISTE GIÀ)" if os.path.exists(dest) else ""))
            if altri:
                print("- altri stati attivi legati al lavoro: %s → la cartella non si sposta finché sono vivi" % ", ".join(altri))
        if imp or att:
            print("→ prima di archiviare: chiudere con il cliente ogni impegno e ogni ◇ ([x] con esito, oppure ⊘ decaduta)")
        return 0

    motivo, distillato, istanza = arg("--motivo"), arg("--distillato"), arg("--istanza")
    if not motivo or not distillato or not istanza:
        print("archivia: servono --motivo, --distillato e --istanza")
        return 2
    if imp or att:
        print("archivia: rifiutato, %d impegni e %d attese ◇ ancora aperti in %s" % (len(imp), len(att), filo))
        return 1
    if lavoro and altri:
        print("archivia: rifiutato, il lavoro %s è legato a stati ancora attivi: %s" % (lavoro, ", ".join(altri)))
        return 1
    if dest and os.path.exists(dest):
        print("archivia: rifiutato, la destinazione esiste già: %s" % dest)
        return 1
    fatti = []
    # Documenti accanto alle note: se la fonte-primaria è la cartella del lavoro (o sta dentro), si sposta con lui e lo
    # stato archiviato deve puntare alla posizione nuova, in forma assoluta (con ~ se sta nella home).
    fp_vecchia = campo(testo, "fonte-primaria") if sp else ""
    fp_segue = bool(lp and dest and dentro(assoluto(fp_vecchia), lp))
    if fp_segue:
        nuova = os.path.join(dest, os.path.relpath(assoluto(fp_vecchia), lp)).rstrip("/.")
        casa = os.path.expanduser("~")
        fp_nuova = ("~" + nuova[len(casa):]) if nuova.startswith(casa + os.sep) else nuova
    if sp:
        t = testo
        if fp_segue:
            t = imposta(t, "fonte-primaria", "'%s/'" % fp_nuova)
        for k, v in (("status", "chiuso"), ("ultima-mossa", "'%s'" % OGGI.isoformat()),
                     ("prossima-azione", "'nessuna (archiviato)'"), ("updated_at", "'%s'" % OGGI.isoformat())):
            t = imposta(t, k, v)
        t = t.rstrip("\n") + "\n\n*%s:* lavoro chiuso e archiviato — %s. Distillato: %s.\n<!-- aggiornato da %s %s (archiviazione) -->\n" % (
            OGGI.isoformat(), motivo, distillato, istanza, OGGI.isoformat())
        os.makedirs(os.path.join(STATI, "archivio"), exist_ok=True)
        nuovo = os.path.join(STATI, "archivio", filo + ".md")
        if os.path.exists(nuovo):
            print("archivia: rifiutato, esiste già %s" % nuovo)
            return 1
        with open(sp, "w", encoding="utf-8") as f:
            f.write(t)
        os.replace(sp, nuovo)
        fatti.append("stato %s → %s" % (filo, os.path.relpath(nuovo, VAULT)))
    if lp:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.move(lp, dest)
        fatti.append("cartella %s → %s" % (os.path.relpath(lp, VAULT), os.path.relpath(dest, VAULT)))
    fp = campo(testo, "fonte-primaria")
    if fp_segue:
        fatti.append("cartella su disco: era la cartella del lavoro, spostata con lui (fonte-primaria → %s/)" % fp_nuova)
    elif fp:
        fatti.append("cartella su disco %s: resta dov'è%s" % (fp, " (proposta: %s, solo con il sì del cliente)" % E("METIS_FONTI_ARCHIVIO") if E("METIS_FONTI_ARCHIVIO") else ""))
    print("archivia: fatto — " + "; ".join(fatti))
    return 0


if __name__ == "__main__":
    sys.exit(main())
