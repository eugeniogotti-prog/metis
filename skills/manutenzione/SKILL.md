---
name: manutenzione
description: Ripara da sola ciò che il doctor ha trovato fuori posto nel vault, senza chiedere al cliente che cosa fare, e gli manda un rendiconto breve di ciò che ha sistemato. Chiede solo le scelte di merito, gli invii a terzi, le spese e le cancellazioni definitive. Gira ogni mattina dopo il doctor (giro automatico «manutenzione») o su richiesta. Trigger: «manutenzione», «sistema il vault», «ripara quello che dice il doctor», «metti a posto».
---

# Manutenzione: il vault si ripara da solo

Principio (decisione del 10/11/2026): **il doctor trova, la manutenzione ripara, il cliente riceve un rendiconto.** Al cliente non si chiede che cosa fare quando la risposta è ovvia o è una regola del vault. Gli si chiede solo ciò che è davvero suo:
- scelte di merito (che cosa scrivere a qualcuno, che posizione prendere, che cosa conta di più);
- invii a terzi (restano bozze: skill `consegna`);
- spese;
- cancellazioni definitive (mai `rm` ricorsivo; si archivia invece di cancellare).

## Prima di cominciare

1. Leggere il rapporto del doctor: `<cartella di Claude>/doctor.md`, la cartella del ruolo CLAUDE (di default `_Claude`). Se ha più di un giorno, rilanciarlo: `bash <cartella del plugin>/scripts/doctor.sh`.
2. Leggere `regole-di-metodo.md` nella cartella di Claude.

## Che cosa si ripara da sé

Per ogni riga ⚠️ o ❌ del rapporto, la riparazione qui sotto. Una riga che non compare qui, o che richiede una scelta di merito, va nella sezione «Da decidere» del rendiconto, con la proposta.

| Il doctor dice | Riparazione |
|---|---|
| Note ferme nell'Inbox, Inbox sopra la soglia | eseguire la skill `inbox-processor` in modalità giro automatico: tutto si colloca, niente resta fermo |
| Trascrizione di una riunione senza un lavoro a cui appartiene | creare il lavoro adatto (cartella in quella dei progetti, con `_IN`, `_fonti`, `_OUT`, e uno stato in `stati/` dal modello), collocarci sintesi e trascrizione (`trascrizioni/`), dirlo nel rendiconto |
| Frontmatter incompleto, tag senza prefisso | completare `created_at` (dalla data nel nome o nel contenuto, mai dalla data del file), `tags` con prefisso, `up` verso la cartella genitore |
| Righe d'impegno malformate | riscriverle nel formato della skill `impegni`, senza cambiarne il significato; se il significato non è chiaro, «Da decidere» |
| Attese oltre la decadenza | chiuderle come `⊘ decaduta (auto <data>)` (skill `impegni`) |
| Stati con più sezioni «## Impegni» | riunirle (skill `impegni` § 7) |
| File sciolti nella radice di una cartella | portarli nella `_IN/` del lavoro a cui appartengono; se non si capisce, nella cartella del lavoro più vicino, con una riga nel rendiconto |
| Cartelle di lavoro senza `_IN`, `_fonti`, `_OUT` | crearle |
| Log di sessione del mese prima da compattare, inizio mese non fatto | eseguire le operazioni di inizio mese della routine di fine sessione |
| Mappa non generata | `python3 <cartella del plugin>/scripts/mappa.py` |
| Impegni `palla:me` scaduti | **non** si chiudono da soli: vanno nel rendiconto, una riga ciascuno, con la proposta (nuova data, chiusura con prova, decaduto) |
| Servizi fermi, sincronizzazione bloccata, accessi in scadenza | li gestisce il controllo del mattino del server (`controllo-giornaliero.sh`), che riavvia ciò che si può riavviare; qui solo una riga se il rapporto li segnala ancora |
| Tetti del contesto superati | distillare o spostare nel livello «su richiesta» solo se l'operazione non cambia il senso di una regola del cliente; altrimenti «Da decidere» |

**Prudenza:** ogni spostamento con `obsidian move` se l'app è aperta, altrimenti `mv`, dichiarando che i collegamenti non sono aggiornati. Prima di spostare o riscrivere, si verifica che il file di destinazione non esista già. Le note del cliente non si riscrivono: si completano.

## Il rendiconto

1. **Nella nota del giorno**, sotto `# Memo`:
   `- 🔧 HH:MM manutenzione: N cose sistemate · M da decidere.` Poi una riga per ciascuna, con il wikilink a ciò che è stato toccato.
2. **Su Telegram**, solo se c'è almeno una cosa sistemata o da decidere: un messaggio breve con lo script del plugin (`python3 <cartella del plugin>/scripts/telegram/metis_telegram.py invia`):
   ```
   Ho sistemato 3 cose nel vault:
   - la riunione di ieri sui corsi ITS: progetto nuovo «Corsi ITS 2027», con sintesi e trascrizione
   - 2 note con l'intestazione incompleta
   Da decidere (1): la scadenza «preventivo al fornitore» è passata il 12/11: la sposto al 19/11?
   ```
   Se non c'è niente, non si scrive al cliente.

## Giro automatico

Niente domande in corso d'opera: si ripara, si scrive il rendiconto, e le domande vere stanno tutte nella sezione «Da decidere». Il resoconto finale è di tre righe: quante riparazioni, quante cose da decidere, che cosa non è stato possibile fare e perché.
