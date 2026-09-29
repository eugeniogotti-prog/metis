---
name: daily-digest
description: Il digest della giornata nella nota del giorno. Al mattino il briefing (calendario, posta da gestire, impegni in scadenza, lavori, Inbox, domani con mini-briefing); la sera «La giornata» (che cosa è entrato e perché conta, che cosa si è mosso, il filo del giorno, tre domande per il diario). Gira da solo alle 7 e alle 21 (modulo routine) o su richiesta. Trigger: "daily digest", "briefing", "com'è la giornata", "riepilogo del giorno", "la giornata".
---

# Daily digest

Due momenti con due scopi. Il mattino serve a decidere che cosa attaccare; la sera serve ad assimilare ciò che è passato.

## Modalità

- **Mattino** (prima delle 14, o «modalità mattino» nella richiesta): questo file.
- **Sera** (dalle 14, o «modalità sera»): `references/sera.md`.

## Dove sono le cose

Cartelle dalla tabella dei ruoli in `CLAUDE.md`; stati dei lavori in `stati/` nella cartella di Claude; nota del giorno nella cartella delle note giornaliere, `YYYY-MM-DD.md` (se manca: dal modello di nota giornaliera, o con il solo frontmatter e `# Memo`).

## Mattino: le fonti

| Fonte | Come | Se non risponde |
|---|---|---|
| calendario oggi e domani | strumenti del calendario (connettore o server locale in sola lettura) | «calendario non letto: motivo» |
| posta ricevuta nelle ultime 24 ore | strumenti della posta; leggere il corpo delle mail ambigue | «posta non letta: motivo» |
| impegni | righe `- [ ]` nella sezione `## Impegni` di ogni stato | — |
| lavori | stati con `scadenza:` entro 7 giorni | — |
| Inbox | note in attesa per sottocartella | — |

Una fonte che non risponde si dichiara. Niente riunioni, mail o eventi dedotti per riempire un vuoto.

**Posta.** Da gestire: persone reali con una richiesta. Newsletter notevoli: solo il titolo. Promozioni e notifiche: fuori. Prima di mettere una mail fra quelle da gestire, controllare nel thread se il cliente ha già risposto.

## Mattino: impegni e lavori (la sezione che vale di più)

1. `palla:me` con data passata o entro 7 giorni → «🎯 Fare adesso», per data. Se non c'è niente: «nessun impegno in scadenza».
2. `palla:loro` con `decade:` superata → «attese decadute da chiudere» (le chiude il cliente, o la skill `impegni`).
3. Per ogni evento di domani: cercare lo stato del lavoro collegato; se c'è materiale, un mini-briefing di 3-5 punti con i wikilink.
Urgenza: 🔴 oggi o domani · 🟡 entro 5 giorni · 🟢 il resto.

## Mattino: formato

Sotto `# Memo`, in coda a ciò che c'è già:

```markdown
### Briefing del mattino
**Oggi** · 09:30 Riunione X — [[nota]] · 15:00 Call Y
**Posta da gestire** · Nome — richiesta (in una riga)
**🎯 Fare adesso** · 🔴 **cosa** — [[stato]] | data
**Lavori con scadenza vicina** · [[stato]] — scadenza
**Inbox** · 3 note — le lavora il prossimo giro dell'inbox (orari in `METIS_ORARI_INBOX_PROCESSOR`, default 9, 13, 17)
**Domani** · 10:00 Incontro Z — mini-briefing: …
Fonti non lette: nessuna.
```

Telegrafico: una riga per voce; il dettaglio sta nelle note linkate.

## Messaggio sul telefono (solo con il modulo Telegram)

Dopo aver scritto il briefing, un messaggio breve alla chat del cliente, con lo script del plugin: `python3 <cartella del plugin>/scripts/telegram/metis_telegram.py invia "testo"` (la cartella del plugin è scritta in testa al prompt del giro). Contenuto: la prima riunione, il primo impegno da fare adesso, quante mail da gestire. Se non c'è niente di rilevante, non si manda.

## Regole

- Il digest legge e segnala: non chiude impegni e non modifica stati.
- Si scrive nel registro del profilo del cliente (`profilo-nucleo.md`).
- Nel giro automatico il resoconto finale è di tre righe.
