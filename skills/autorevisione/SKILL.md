---
name: autorevisione
description: Rilettura critica di un output di Claude prima di consegnarlo, modellata sullo sguardo con cui il cliente rivede il lavoro. Da eseguire PRIMA di dichiarare finito un output sostanziale — nota, analisi, parere, verbale, documento per altri, propagazione su più file, risposta consultiva impegnativa. Quattro domande in ordine fisso: è fondato? centra l'obiettivo? è preciso? è detto bene per chi legge? Due livelli — il livello 1, che Claude esegue da sé con le lenti (sempre), e il livello 2, un revisore avversariale lanciato come sottoagente che riapre le fonti primarie (per i lavori ad alta posta o su richiesta del cliente). Trigger: "autorevisione", "rivedi come me", "rivedi come se fossi io", "fai un livello 2", "passa il revisore", "controlla prima di consegnare".
---

# Autorevisione

Questa skill rende ripetibile ciò che il cliente fa quando rivede il lavoro di Claude: uno sguardo con una struttura precisa e un ordine che non cambia. Le sue regole di scrittura e i suoi registri stanno nella cartella di Claude (ruolo CLAUDE della configurazione, `bash "${CLAUDE_PLUGIN_ROOT}/scripts/configura.sh" get METIS_RUOLO_CLAUDE`):
- `profilo-nucleo.md`: onestà epistemica, «Forme da evitare, in ogni testo», tono, testi a suo nome, verso chi riceve il lavoro;
- `profilo-completo.md`: sezione 3 (come si verifica nel suo campo), sezione 4 (come rivede i lavori: gli errori che cerca e le distinzioni del suo dominio), sezione 5 (i registri);
- `regole-di-metodo.md`: le regole di verifica (sezioni 1-3) e quelle su numeri e tabelle (sezione 11).

La skill li cita e li apre al momento della revisione; il loro contenuto vive lì e cresce con le correzioni del cliente.

## I due principi

1. **L'ordine è fisso: fondatezza → obiettivo → precisione → forma.** Un difetto in alto pesa più di uno in basso. Una forma elegante su una base non verificata non vale nulla; un contenuto solido detto male si aggiusta. Non si rifinisce la prosa di un'affermazione ancora da verificare.
2. **La colpa capitale è l'invenzione plausibile.** È peggio di un vuoto dichiarato, perché chi legge non distingue un fatto da una ricostruzione verosimile. Se una fonte manca, è superata o non è stata letta, lo si dichiara; il vuoto resta vuoto (niente riunioni, date, meccanismi, numeri o citazioni ricostruiti).

Il test di fondo è una domanda secca: **«sei sicuro che sia scritto nella fonte?»**. Per ogni affermazione portante Claude deve poter rispondere «sì, ho aperto il testo».

## Quando

- **Livello 1, sempre**, prima di dichiarare «fatto» un output sostanziale. Esclusi i turni di conversazione e le modifiche banali (un refuso, una rinomina, un'aggiunta meccanica).
- **Livello 2, il revisore avversariale**, quando la posta è alta o quando il cliente lo chiede:
  - documento destinato ad altri (clienti, controparti, enti, organi collegiali);
  - pareri, atti, testi regolatori con citazioni di norme, sentenze o clausole;
  - azioni irreversibili o verso l'esterno (invio, pubblicazione, condivisione);
  - quando Claude stesso ha segnalato bassa confidenza, fatti a fonte singola o letti da una scansione (OCR), assunzioni non verificate;
  - su richiesta del cliente, a prescindere dalla posta.

---

## Livello 1 — Claude rilegge da sé

Rileggere l'output con le quattro domande, in quest'ordine; correggere nel testo e sistemare ogni domanda prima di passare alla successiva. Il dettaglio di ogni controllo, con la ragione, è in `references/lenti.md`.

### 1. È fondato? (la verifica che non si salta)
- **Scritto o dedotto.** Ogni affermazione su una fonte è nel testo, parola per parola, o è una deduzione? Le deduzioni sono marcate («non è scritto, ma suppongo che…»). Mai «la fonte dice esplicitamente» se il testo non lo dice.
- **Citazioni una per una sul testo primario:** norme con articolo, comma e lettera, guardando anche i commi vicini; sentenze (esistenza, pertinenza, numero e anno, tipo di provvedimento); clausole di contratti e documenti (versione, data, chi l'ha approvata). Una citazione ereditata da una bozza precedente si ricontrolla come una nuova.
- **Attribuzione alla fonte reale.** La regola sta nell'atto citato, o gliel'abbiamo attribuita perché il tema è affine? La disciplina generale della materia e la fonte speciale del caso restano distinte.
- **Nomi ed entità** verificati sulle note della cartella delle persone e sugli stati: le trascrizioni vocali storpiano i nomi.
- Le regole di verifica del cliente sono in `regole-di-metodo.md`, sezioni 1-3, e in `profilo-completo.md`, sezione 3.

### 2. Centra l'obiettivo?
- Leggere la sezione `## Obiettivo e perché` in cima allo stato del lavoro (`<cartella di Claude>/stati/<lavoro>.md`, scritta con la skill `definizione-obiettivi`) e misurare a due livelli: l'output soddisfa il **successo osservabile** della tappa che serve, e quella tappa fa avanzare l'**obiettivo finale**? Controllare anche **Cosa NON è** (il confine). Se la sezione manca, dirlo al cliente e proporre `definizione-obiettivi`.
- Se lo stato ha **criteri di verifica**, spuntarli uno per uno (soddisfatto o mancante). Poi dare comunque un giudizio d'insieme sull'obiettivo e riportare i due esiti separati: una lista tutta spuntata può convivere con un lavoro che manca lo scopo, perché a forza di inseguire la lista si ottimizza la lista.
- Tutto dentro il perimetro, senza aggiunte fuori tema per completezza.
- La proposta del cliente è rimasta intera: la prudenza si esercita sulla forma, e un dubbio di merito diventa un punto aperto nella nota di accompagnamento.
- Nessun meccanismo che il sistema di riferimento non prevede; l'approccio più semplice valutato prima di quello complesso.

### 3. È preciso?
- **Distinzioni fini.** Quelle del dominio del cliente sono in `profilo-completo.md`, sezione 4. Valgono per tutti: fatto e inferenza; reazione di apprezzamento e decisione presa; dato registrato in un sistema e documento firmato; disciplina generale e fonte speciale. Altre in `references/lenti.md`, famiglia E.
- **Numeri.** Assoluti e percentuali dalla stessa rilevazione e dallo stesso periodo, conti rifatti, totali che tornano (`regole-di-metodo.md`, sezione 11).
- **Concessioni.** Ogni concessione alla tesi opposta è verificata come la tesi, nel regime specifico: una concessione mal posta lavora contro il documento.
- **Onestà positiva.** Il testo dice dove l'argomento è debole o parziale.

### 4. È detto bene per chi legge?
- **Per ogni testo destinato ad altri, aprire prima `profilo-completo.md`** alla sezione 5 (il registro giusto). Il nucleo, caricato all'avvio, contiene le regole sempre valide; i registri per tipo di testo stanno nella pagina completa.
- **Forme da evitare:** rileggere il testo contro l'elenco di `profilo-nucleo.md`, «Forme da evitare, in ogni testo», voce per voce.
- **Registro per chi firma e per chi riceve:** la persona grammaticale dei testi a nome del cliente (`profilo-nucleo.md`, «Testi a mio nome»); tono prescrittivo in linee guida e regolamenti; atti asciutti, con le premesse ridotte alle norme portanti.
- **Lingua:** accenti corretti, niente anglicismi evitabili.
- **Documenti per altri:** tolti i residui di lavorazione (note di versione, «da verificare», marcatori interni, commenti).
- **Chat:** il contenuto sta nel file; in chat il principio, i conteggi, la scelta da confermare.

### Controlli trasversali
- **Sweep.** Corretto un errore che può ripetersi, cercare con `grep` tutte le occorrenze nel documento e nei file collegati (tabelle riepilogative, rimandi interni, elenchi di punti aperti). Rileggere le righe modificate: una sostituzione meccanica lascia sbagliate le concordanze.
- **Esito reale.** Un'operazione su un file, uno spostamento, un invio: controllare il risultato (il file, la cartella di arrivo, la posta inviata). Un messaggio di successo dello strumento vale come indizio.
- **Lo stato reale prima del prompt.** Prima di proporre o rifare qualcosa, guardare i file esistenti.

### Esito del livello 1
In chat un verdetto breve: che cosa è stato controllato, che cosa corretto, quale incertezza resta (fatti a fonte singola, assunzioni non verificate). Se è emerso un motivo di alta posta, si passa al livello 2.

---

## Livello 2 — il revisore avversariale

Un sottoagente separato che non si fida dell'output e ha il compito di demolirlo. Il suo valore principale è un secondo contesto, libero dal ragionamento che ha prodotto il testo, che riapre le fonti da zero.

### Come si lancia
Strumento **Agent**, tipo `general-purpose`, con il mandato qui sotto e:
1. **l'output** da rivedere (il percorso del file);
2. **l'obiettivo** (copiato dalla sezione `## Obiettivo e perché` dello stato, o dichiarato) e il **destinatario**;
3. **le fonti primarie**, con i percorsi, perché il revisore le riapra da sé. Prima di lanciarlo, controllare che **ogni fonte citata nel documento** sia nell'elenco: un rilievo di assenza su una fonte non passata è un difetto del mandato, e se arriva come capitale distoglie dai rilievi veri;
4. per i lavori di **copertura** (adattare, integrare o rivedere un insieme di documenti): l'istruzione esplicita di cercare anche che cosa manca rispetto all'obiettivo e al corpus.

**Il modello.** Se la sessione non usa già il modello più capace disponibile, passarlo nel parametro `model` dello strumento Agent. Se lo usa già, il revisore gira sullo stesso modello: un revisore meno capace perde gli errori sottili e produce falsi positivi da smontare a mano.

### Il mandato (da mettere nel prompt)
> Sei il revisore avversariale. Non ti fidi di questo output. Attaccalo nell'ordine **fondatezza → obiettivo → precisione → forma**, e fermati a lungo sulla fondatezza. Per ogni affermazione portante chiediti «è scritto nella fonte?» e **riapri la fonte primaria** per verificarlo; parafrasi e «suona giusto» non bastano. Tratta l'**invenzione plausibile** come colpa capitale: ogni numero, data, citazione o meccanismo che non poggia su una fonte è un rilievo. **Non concludere mai «assente» o «inventato» da una ricerca letterale:** i riferimenti compaiono in forme diverse («n. 12» per «decreto 12/2025», «inferiore a 5» per «5 partecipanti»), e un'assenza trovata con grep è a sua volta un'inferenza. Prima di dichiararla, leggi il passaggio e cerca il concetto con rese diverse. Controlla che il lavoro centri l'obiettivo e resti nel perimetro, che non confonda distinzioni fini, che le concessioni siano fondate, che dichiari dove è debole. Se ci sono criteri di verifica, spuntali uno per uno e dai comunque un giudizio d'insieme indipendente; riporta i due esiti separati: criteri tutti soddisfatti con giudizio d'insieme negativo è un rilievo capitale. Restituisci un **verdetto** (passa / non passa) e un elenco **numerato** di rilievi, ciascuno con la gravità (capitale / sostanziale / forma), il punto esatto e che cosa serve per risolverlo. Non addolcire.

### Come si risponde ai rilievi
- Ogni rilievo riceve una risposta, partendo dai capitali. Per quelli di fondatezza Claude **riapre la fonte** e corregge l'affermazione, o la declassa a inferenza dichiarata.
- **Le assenze e le invenzioni segnalate si vagliano sulla fonte primaria**, leggendo: il revisore può aver cercato la forma sbagliata.
- **Lo stesso vale per le sue conferme.** Un «verificato parola per parola» del revisore si controlla sulle righe citate prima di promuovere un'affermazione a fondata: un revisore può inventare un riscontro, e una conferma inventata fa passare un errore per verificato.
- **Le conclusioni che escludono** («non può», «non si applica», «manca la competenza») si verificano sul quadro completo, compresi gli atti successivi che richiamano la fonte e ne estendono l'ambito.
- Una regola che contraddice la fonte può essere una scelta deliberata del cliente o di chi decide: prima di toglierla, cercarla in `decisioni.md` e nello stato del lavoro.
- In chat la sintesi: rilievi sollevati, come sono stati risolti, quali restano aperti e perché (per esempio: fonte non disponibile in questa sessione).

**Guardia contro i giri a vuoto: al massimo due tentativi sullo stesso rilievo.** Se lo stesso punto torna dopo due correzioni, la terza correzione dello stesso tipo non si tenta. Ci si ferma a cercare l'assunzione sbagliata: forse si corregge la frase mentre la causa è una lettura errata della fonte o un perimetro sbagliato. Lo si dice al cliente.

### I giri successivi: mirati
Dopo una revisione fatta bene, un secondo giro completo rende poco e rimette in circolo falsi positivi. Dal secondo giro in poi il revisore si lancia **mirato**: sugli argomenti nuovi mai attaccati, sui punti a fonte singola, sui controlli di coerenza fra file. Il giro completo si rifà solo se la revisione ha toccato l'impianto del documento.

---

## Composizione con le altre skill

Questa è la sede unica dello sguardo di revisione. Le skill che producono documenti la richiamano in chiusura invece di ripeterla, con il livello 2 come regola quando il documento esce dal vault.

## Le lenti crescono con le correzioni

Quando il cliente corregge un output, il caso va in `<cartella di Claude>/correzioni.md` nello stesso turno (`CLAUDE.md`, «Il ciclo delle correzioni»). Se la correzione porta un tipo di errore che le lenti non coprivano, la regola va nel vault del cliente: le distinzioni del suo dominio e gli errori che cerca in `profilo-completo.md`, sezione 4; le regole di verifica in `regole-di-metodo.md`. Il catalogo `references/lenti.md` fa parte del plugin e un aggiornamento lo sostituisce: le lenti proprie del cliente stanno nei suoi file.
