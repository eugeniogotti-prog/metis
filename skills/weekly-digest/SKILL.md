---
name: weekly-digest
description: Il riepilogo della settimana nella nota settimanale (YYYY-Www): che cosa è entrato e si è prodotto, come si sono mossi i lavori e gli impegni, le attese decadute, le decisioni prese, le persone con cui si è lavorato, ciò che va fatto a inizio mese. Gira da solo il lunedì mattina (modulo routine) o su richiesta. Trigger: "weekly digest", "riepilogo della settimana", "com'è andata la settimana", "weekly".
---

# Weekly digest

Una pagina che il cliente legge il lunedì per vedere la settimana passata tutta insieme e decidere dove mettere la prossima.

## Quale settimana

Il lunedì, o se non si dice altro: la settimana appena chiusa (da lunedì a domenica). Nota: `YYYY-Www.md` nella cartella delle note giornaliere (settimana ISO). Se esiste, si aggiorna la sezione `# Digest`; se non esiste, si crea dal modello di nota settimanale, o con il frontmatter e `# Digest`.

## Da dove si raccoglie

Cartelle dalla tabella dei ruoli in `CLAUDE.md`.
1. **Note della settimana**: create o aggiornate nei sette giorni (`created_at`/`updated_at` nel frontmatter), fuori da Inbox, note giornaliere e cartella di Claude, e fuori dalle sottocartelle `_IN/`, `_fonti/` e `_OUT/`, che tengono documenti e non note. Si raggruppano per lavoro o area.
   **Documenti della settimana**, nelle cartelle dei lavori e delle aree (con `METIS_DOCUMENTI=separati`, nella cartella fonti): ciò che è arrivato in `_IN/`, ciò che è stato consegnato in `_OUT/` (la data è nel nome) e le fonti nuove nella cartella delle risorse. Vanno sotto il lavoro a cui appartengono, non in un elenco a parte.
2. **Lavori**: gli stati in `stati/` toccati nella settimana (voci datate nel log, impegni con date della settimana). Per ciascuno: che cosa si è mosso, a che punto è.
3. **Impegni**: chiusi nella settimana; `palla:me` scaduti; `palla:loro` in riesame.
4. **Attese decadute** (il «funerale» della settimana): righe `⊘ decaduta (auto …)` con una data della settimana, in un elenco unico.
5. **Decisioni**: righe della settimana in `decisioni.md`.
6. **Correzioni**: casi della settimana in `correzioni.md`, con il numero di regole nate dall'inizio (contatore in `_Claude.md`).
7. **Persone**: interlocutori diretti della settimana; quelli senza nota persona o con «Interazioni chiave» ferme.
8. **Calendario** della settimana passata e di quella che viene, se gli strumenti rispondono; altrimenti lo si dichiara.

## Struttura

```markdown
# Digest

### La settimana in tre righe
…

### Lavori
- [[stato]] — che cosa si è mosso · a che punto è · prossimo passo

### Prodotto e raccolto
- [[Nota]] — una riga (raggruppate per lavoro)

### Impegni
- ✅ chiusi: N — i principali · ⏰ scaduti: … · ⏳ in riesame: …
- Decadute questa settimana: … (si riaprono con una parola del cliente)

### Decisioni e correzioni
- decisioni: … · correzioni: N casi; regole nate dalle correzioni finora: N

### Persone
- da aggiornare: …

### La settimana che viene
- eventi e scadenze principali
```

## Inizio mese

Se la settimana che viene contiene il primo giorno del mese: una riga «A inizio mese: distillare i casi di correzione del mese in regole e archiviarli (CLAUDE.md, «Prima sessione del mese»)».

## Regole

- Si legge e si segnala: niente impegni chiusi o stati modificati.
- Una riga per voce, con i wikilink; il dettaglio sta nelle note.
- Una fonte che non risponde si dichiara.
- Registro del profilo del cliente. Nel giro automatico il resoconto finale è di tre righe.
