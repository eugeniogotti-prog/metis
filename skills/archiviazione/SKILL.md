---
name: archiviazione
description: Archivia un lavoro chiuso — distilla ciò che ha insegnato, chiude impegni e attese con il cliente, archivia lo stato, sposta la cartella del lavoro nell'archivio del vault, aggiorna le note delle persone e la mappa — e alla prima sessione del mese propone i lavori fermi da archiviare. Trigger: «archivia il lavoro X», «archivia il progetto X», «chiudi il lavoro X», «elimina il lavoro X» (si archivia, non si cancella), «quali lavori archiviamo», la prima sessione del mese, oppure quando il doctor segnala lavori fermi da tempo.
---

# Archiviazione dei lavori chiusi

Chiudere un lavoro ha due scopi: **non perdere quello che ha insegnato** e **togliere rumore** da lavori, stati e doctor. La parte meccanica la fa `scripts/archivia.py`; la parte di giudizio (che cosa distillare, che cosa dire alle persone) resta a Claude e al cliente.

Due oggetti, spesso ma non sempre insieme:
- il **lavoro nel vault**: una cartella dentro la cartella dei lavori (ruolo PROGETTI della configurazione). Con i documenti accanto alle note (default, `METIS_DOCUMENTI=accanto`) è una cartella sola, con le note nella radice e i documenti in `_IN/`, `_fonti/` e `_OUT/`;
- lo **stato**: `<cartella di Claude>/stati/<nome>.md`, con la cartella del lavoro nel campo `fonte-primaria:` (con `METIS_DOCUMENTI=separati` è la cartella dei documenti, fuori dal vault).

Un lavoro può avere più stati, e uno stato può non avere una cartella nel vault. Si archivia ciò che è chiuso: se un lavoro ha ancora uno stato vivo, si archivia solo lo stato chiuso.

I percorsi vengono dalla configurazione (`bash "${CLAUDE_PLUGIN_ROOT}/scripts/configura.sh" get <CHIAVE>`):
- `METIS_RUOLO_PROGETTI`, `METIS_RUOLO_ARCHIVIO`: dove stanno i lavori e dove vanno a fine lavoro;
- `METIS_ARCHIVIO_PER_ANNO`: «sì» (default) se l'archivio ha una cartella per anno, «no» se è piatto;
- `METIS_FONTI_ARCHIVIO`: conta solo con `METIS_DOCUMENTI=separati`. Vuota (default) se le cartelle dei documenti fuori dal vault restano dove sono; altrimenti la cartella dove il cliente vuole spostarle, solo su suo sì, una per una.

I comandi si lanciano con la configurazione caricata:
```
bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; shift; python3 "$0/scripts/archivia.py" "$@"' "${CLAUDE_PLUGIN_ROOT}" x <argomenti>
```

## Regola d'ingaggio

- **Si archivia solo su decisione del cliente**, per un lavoro preciso. Le proposte del controllo mensile sono proposte.
- **Archiviare, non cancellare.** Anche quando il cliente dice «elimina», si archivia e glielo si dice in una riga; si cancella solo se lo chiede di nuovo dopo la spiegazione.
- Tutto è reversibile, perché si sposta e non si distrugge. A decisione presa, si esegue il giro intero senza chiedere conferma a ogni passo.

## Il giro, in ordine

### 0. Ricognizione
1. `archivia.py ricognizione --filo <stato> --lavoro <cartella>`: impegni aperti, attese «◇», persone, cartella dei documenti (e se si sposta con il lavoro), note del lavoro e quante altre note le citano, destinazione, altri stati vivi legati al lavoro.
2. Leggere per intero gli stati coinvolti: obiettivo, impegni, «Se arriva», ultime voci.
3. Per ogni impegno aperto e ogni «◇»: **chiedere al cliente**, una riga ciascuno. Si chiude (`[x]` con l'esito, oppure `⊘ decaduta (archiviazione AAAA-MM-GG)`) o il lavoro non è chiuso. Lo script rifiuta di archiviare finché ne resta uno.

### 1. Distillare (il passo che non si salta)
Rispondere a: *che cosa sa il vault, grazie a questo lavoro, che domani servirà altrove?*
- conoscenza di merito (norme, dati, prassi di un ente o di un cliente) → la scheda di `dominio/` pertinente, con il grado di verifica, la fonte e la data;
- il perché e le lezioni di metodo che valgono per tutti i lavori → `carta-del-perche.md` nella cartella di Claude (si crea al primo distillato; vedi la skill `definizione-obiettivi`);
- una regola di metodo nata da una correzione → verificare che sia già in `regole-di-metodo.md` o nel profilo; non duplicarla;
- documenti definitivi utili oltre il caso (una norma, un manuale, uno studio nella `_fonti/` del lavoro) → proporre al cliente di spostarli nella cartella delle risorse, nel tema giusto, lasciando il rimando nel `README.md` della `_fonti/`: dopo l'archiviazione gli altri lavori non li cercherebbero nell'archivio.

Il risultato va nell'argomento `--distillato` («dominio/appalti.md, due asserzioni»). Se non c'è niente da distillare si scrive «nessuno: <motivo>»: lo script non accetta un distillato vuoto.

### 2. Persone
Per ogni persona dello stato con una nota nella cartella delle persone: una riga nelle interazioni (data, «chiusura del lavoro X», esito in una frase).

### 3. Esecuzione
`archivia.py esegui --filo <stato> --lavoro <cartella> --motivo "…" --distillato "…" --istanza <chi>`:
- lo stato diventa `status: chiuso`, con le date di oggi, `prossima-azione: nessuna (archiviato)`, la riga di chiusura e il marcatore; poi va in `stati/archivio/`;
- la cartella del lavoro va in `<ARCHIVIO>/<anno>/` (o in `<ARCHIVIO>/` se l'archivio non è per anno);
- con i documenti accanto alle note (default, `METIS_DOCUMENTI=accanto`) la cartella del lavoro contiene anche i documenti: si sposta intera, con `_IN/`, `_fonti/` e `_OUT/`, e lo script aggiorna la `fonte-primaria:` dello stato archiviato alla posizione nuova. Le fonti comuni restano nella cartella delle risorse: servono ad altri lavori;
- con `METIS_DOCUMENTI=separati` la cartella su disco resta dov'è: lo stato archiviato la conserva in `fonte-primaria:`, ed è così che la mappa sa a quale lavoro chiuso appartiene. Se `METIS_FONTI_ARCHIVIO` è impostata, lo script stampa la proposta di spostamento: si sposta a mano, solo con il sì del cliente, perché spostarla rompe i riferimenti nelle mail e nei documenti.

Obsidian risolve i wikilink per nome: di norma i link alle note spostate reggono. Se la ricognizione ha contato note che le citano, dopo lo spostamento se ne controllano due o tre.

### 4. Chiusura del giro
1. `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/mappa.py"` (con la configurazione caricata, come sopra): il lavoro esce da `mappa-inventario.md` ed entra in `mappa-archivio.md`, dove lo troverà chi avvia un lavoro simile.
2. Log di sessione: «Archiviato: X (motivo), distillato in Y».
3. Al cliente, in breve: che cosa è stato spostato e dove, che cosa è stato distillato, che cosa è rimasto dov'era (le fonti comuni nelle risorse; con `METIS_DOCUMENTI=separati`, la cartella dei documenti).

## Il controllo mensile

Alla prima sessione del mese (`CLAUDE.md`, «Prima sessione del mese»), un solo elenco al cliente:
- i lavori della sezione «Lavori fermi da oltre … giorni» di `mappa-inventario.md`;
- gli stati `dormiente` da oltre 60 giorni e quelli `chiuso` non ancora in archivio.

Per ciascuno una riga: nome, ultima attività, impegni aperti, proposta (archiviare, tenere, chiedere). Il cliente risponde in una riga («archivia 1 e 3; il 2 resta»); i lavori scelti passano per il giro, uno alla volta.

## Errori da evitare
- Archiviare senza distillare: il lavoro sparisce dalla vista e la lezione con lui.
- Chiudere d'ufficio impegni o attese per poter archiviare: si chiede.
- Con `METIS_DOCUMENTI=separati`: spostare le cartelle dei documenti fuori dal vault senza il sì del cliente.
- Spostare nell'archivio, insieme al lavoro, una fonte che sta nelle risorse: serve anche ad altri lavori.
- Scambiare «fermo» per «chiuso»: un lavoro fermo da tre mesi può essere in attesa di un bando o di una risposta. La mappa propone, il cliente decide.
