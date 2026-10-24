# Fase 3 — il patto di collaborazione e il gesto di correzione

> Procedura da usare **solo se necessario**, quando la voce matura nell'uso o il cliente la chiede (`SKILL.md`, «Nell'uso, solo se necessario»). Non fa parte dell'avvio in dieci minuti.

**Precondizioni:** avvio fatto; automazioni scelte installate, altrimenti il doctor resta giallo e lo si dice.

**Esito:** il cliente conosce il patto; un caso in `correzioni.md` fatto da lui con il gesto, registrato durante questa fase.

## 1. Il patto, detto al cliente

Si dice in chat, con queste parole o con parole vicine, adattate al registro del cliente:

> Da oggi tratta Claude come un collaboratore junior. Quando un suo lavoro non va, spiegagli che cosa non funziona e come deve cambiare il metodo, e lascia il file com'è. Una correzione fatta a mano resta in quel file; una correzione spiegata diventa una regola, e Claude non la ripete. Così il collaboratore junior diventa senior, e impara sia il merito del tuo lavoro sia il tuo metodo.

Poi si spiega dove finiscono le correzioni, in tre righe: il caso in `correzioni.md`, subito, per ogni correzione; la regola nel profilo subito se è di stile, in `dominio/` se è di merito, altrimenti a inizio mese in `regole-di-metodo.md`; il doctor che ogni mattina controlla che il ciclo giri.

## 2. Il gesto

Il cliente l'ha già visto a fine fase 1. Qui si riprende la forma, facile da ricordare:

> «Questo non va perché…, d'ora in poi…»

Esempi da mostrare, inventati:
- «Questa mail non va perché apre con i ringraziamenti; d'ora in poi con i colleghi entra subito nel merito.»
- «Questo riassunto non va perché ripete cose che so già; d'ora in poi, sui miei temi, dimmi solo che cosa c'è di nuovo e dove la fonte sbaglia.»
- «Questa scadenza non va perché l'hai presa dal riassunto; d'ora in poi le date si prendono dal documento.»

Quando riceve il gesto, Claude:
1. registra il caso in `correzioni.md` nello stesso turno, nel formato dell'intestazione del file (che cosa è successo, perché, regola);
2. se la regola riguarda lo stile o il rapporto con il cliente, è univoca e il cliente la conferma, la scrive subito nel profilo; se riguarda il merito, in `dominio/`; se riguarda un solo lavoro, nel suo stato; le altre aspettano la distillazione di inizio mese;
3. rifà il lavoro applicando la regola;
4. dice in una riga dove l'ha scritta.

## 2b. Il gesto di chiusura

Il secondo gesto da insegnare, in una riga: **prima di uscire da Claude Code con `/exit`, scrivere «chiudi sessione»**. Claude scrive il log della sessione, aggiorna gli stati dei lavori toccati, le persone e lo stato attuale. Chi esce senza chiudere perde ciò che non è già nei file: il mattino dopo il doctor lo segnala («ieri sono state toccate N note ma manca il log di sessione»).

## 3. La prima correzione, dal vivo

Si chiede al cliente di scegliere un output della giornata (la prova della fase 1, lo stato della fase 2, un testo nuovo) e di correggerlo con il gesto. Claude esegue i quattro passi sopra. Se il cliente corregge a mano, glielo si fa notare con garbo e si ripete il gesto sulla stessa correzione.

## 4. Che cosa succede dopo

Si dice al cliente, in breve:
- ogni mattina il doctor controlla che il sistema giri, e all'avvio della sessione Claude riporta ciò che non va;
- a inizio mese, alla prima sessione, Claude propone di trasformare i casi del mese in regole: al cliente si chiede di confermarle, in pochi minuti (stima da misurare con i primi clienti);
- i primi 30 giorni sono il rodaggio: il segno che funziona è che Claude smette di ripetere gli errori già corretti, e che le regole nate dalle sue correzioni crescono (il contatore sta in «Stato attuale» di `_Claude.md`).

## 5. Chiusura dell'onboarding

1. Routine di fine sessione (`routine-fine-sessione.md`, oppure «Chiusura sessione» di `CLAUDE.md`).
2. Doctor: si lancia con il comando che l'installazione ha scritto in `_Claude.md` e si legge il semaforo con il cliente. Atteso verde, oppure giallo con motivi noti (per esempio un'automazione non ancora installata).
3. In `_Claude.md`: contatori aggiornati.
4. Lo stato `onboarding.md`: nel log, il titolo del caso fatto dal vivo («## YYYY-MM-DD — …»). Lo stato si archivia in `stati/archivio/` quando le sue due tappe sono fatte.
5. Se sono emerse scelte rilevanti (autonomia, canali), una riga in `decisioni.md` con la data.
