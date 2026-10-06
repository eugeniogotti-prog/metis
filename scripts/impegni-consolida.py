#!/usr/bin/env python3
"""impegni-consolida.py — porta un file di stato a UNA sola sezione «## Impegni».

Uso:
  impegni-consolida.py FILE.md [FILE.md …]                          # prova: dice cosa farebbe, non scrive
  impegni-consolida.py --scrivi [--istanza CHI] FILE.md [FILE.md …]  # applica, con una copia di ogni file in
      <cartella di Claude>/archivio/stati-prima-del-consolidamento-AAAA-MM-GG/ (con METIS_CL; altrimenti in
      ~/Library/Caches/metis/)

Applica la skill impegni § 7 (una sola sezione `## Impegni` per stato):
- la sezione che resta è la PRIMA `## Impegni` del file;
- le righe aperte `- [ ]` delle altre sezioni Impegni ci vengono spostate **come blocchi** (con le
  righe figlie indentate subito sotto) e **con il loro ^id**, in coda agli aperti (prima di `**Fatti:**`
  se c'è);
- le righe chiuse `- [x]` e tutto il resto restano dove sono: sono cronaca, e spostarle staccherebbe
  la prova dal fatto;
- l'intestazione delle sezioni in più diventa testo (`**Impegni di questa voce (sezione consolidata il
  …):**`), così il conteggio delle sezioni scende a 1;
- sotto l'intestazione che resta, un commento HTML vieta di crearne altre.
Controllo: il numero di righe `- [ ]` prima e dopo deve essere identico, altrimenti non scrive.
Doppioni: NON li fonde (serve giudizio su quale formulazione tenere); elenca le coppie di righe aperte
molto simili, da vagliare a mano.

Portato il 6/10/2026 dal vault di riferimento, dove il controllo del doctor sulle sezioni multiple ne ha trovate più
di cento in cinquanta stati, con punte di diciassette in un solo file. Il doctor del plugin le segnala; questo le ripara.
"""
import datetime, difflib, os, re, shutil, sys

SEZ = re.compile(r"^## Impegni(\s.*)?$")
APERTA = re.compile(r"^- \[ \]")
COMMENTO = "<!-- Unica sezione «Impegni» di questo stato: non crearne altre (skill impegni § 1; consolidamento del {d}) -->"


def consolida(testo, oggi):
    righe = testo.split("\n")
    sezioni = [i for i, r in enumerate(righe) if SEZ.match(r)]
    if len(sezioni) <= 1:
        return None, 0, []
    prima = sezioni[0]
    da_spostare, togli = [], set()
    for s in sezioni[1:]:
        j = s + 1
        while j < len(righe) and not righe[j].startswith("## ") and not righe[j].startswith("# "):
            if APERTA.match(righe[j]):
                blocco = [righe[j]]; togli.add(j); k = j + 1
                while k < len(righe) and righe[k].strip() and (righe[k].startswith("  ") or righe[k].startswith("\t")):
                    blocco.append(righe[k]); togli.add(k); k += 1
                da_spostare.append(blocco); j = k
            else:
                j += 1
    # fine della prima sezione e punto d'inserimento (dopo l'ultimo aperto, prima di **Fatti:**)
    fine = prima + 1
    while fine < len(righe) and not righe[fine].startswith("## ") and not righe[fine].startswith("# "):
        fine += 1
    ins = None
    for i in range(prima + 1, fine):
        if righe[i].strip().startswith("**Fatti"):
            ins = i; break
    if ins is None:
        ultimo = prima
        for i in range(prima + 1, fine):
            if APERTA.match(righe[i]) or (ultimo > prima and righe[i].startswith(("  ", "\t")) and righe[i].strip()):
                ultimo = i
        ins = ultimo + 1
    nuove = []
    for i, r in enumerate(righe):
        if i == ins:
            for b in da_spostare:
                nuove.extend(b)
        if i in togli:
            continue
        if i in sezioni[1:]:
            titolo = r[2:].strip()
            nuove.append(f"**{titolo} — sezione consolidata il {oggi}: gli aperti sono nella sezione «Impegni» in alto**")
            continue
        nuove.append(r)
        if i == prima and not (i + 1 < len(righe) and "Unica sezione «Impegni»" in righe[i + 1]):
            nuove.append(COMMENTO.format(d=oggi))
    if ins >= len(righe):
        for b in da_spostare:
            nuove.extend(b)
    aperte = [r for r in nuove if APERTA.match(r)]
    simili = []
    norm = [re.sub(r"\^[a-z0-9]{4,8}\s*$|\|.*$|\*\*", "", a).strip().lower() for a in aperte]
    for x in range(len(aperte)):
        for y in range(x + 1, len(aperte)):
            if difflib.SequenceMatcher(None, norm[x], norm[y]).ratio() > 0.8:
                simili.append((aperte[x][:110], aperte[y][:110]))
    return "\n".join(nuove), len(da_spostare), simili


if __name__ == "__main__":
    a = sys.argv[1:]
    scrivi = "--scrivi" in a
    istanza = a[a.index("--istanza") + 1] if "--istanza" in a and a.index("--istanza") + 1 < len(a) else "cli"
    files = [x for i, x in enumerate(a) if x not in ("--scrivi", "--istanza") and not (i > 0 and a[i - 1] == "--istanza")]
    if not files:
        sys.exit(__doc__)
    oggi = datetime.date.today().isoformat()
    cl = os.environ.get("METIS_CL")
    bak = os.path.join(cl, "archivio", f"stati-prima-del-consolidamento-{oggi}") if cl else \
        os.path.expanduser(f"~/Library/Caches/metis/stati-prima-del-consolidamento-{oggi}")
    for f in files:
        testo = open(f, encoding="utf-8").read()
        prima_n = len(re.findall(r"(?m)^## Impegni(\s.*)?$", testo))
        nuovo, n, simili = consolida(testo, oggi)
        if nuovo is None:
            print(f"{os.path.basename(f)}: già una sola sezione"); continue
        a0 = len(re.findall(r"(?m)^- \[ \]", testo)); a1 = len(re.findall(r"(?m)^- \[ \]", nuovo))
        s1 = len(re.findall(r"(?m)^## Impegni(\s.*)?$", nuovo))
        stato = "OK" if a0 == a1 and s1 == 1 else "ERRORE"
        print(f"{os.path.basename(f)}: sezioni {prima_n} → {s1}; aperti {a0} → {a1}; blocchi spostati {n}; {stato}")
        for x, y in simili:
            print(f"   possibile doppione:\n     · {x}\n     · {y}")
        if scrivi and stato == "OK":
            os.makedirs(bak, exist_ok=True)
            shutil.copy2(f, os.path.join(bak, os.path.basename(f)))
            nuovo = nuovo.rstrip("\n") + f"\n<!-- aggiornato da {istanza} {oggi} (consolidamento impegni: {prima_n} sezioni → 1) -->\n"
            open(f, "w", encoding="utf-8").write(nuovo)
            print("   scritto (copia di prima in " + bak + ")")
