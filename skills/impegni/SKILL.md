---
name: impegni
description: Le regole sugli impegni e sulle attese dei lavori del cliente — come si scrivono, si chiudono, si verificano e si ripuliscono nella sezione «## Impegni» degli stati. Le regole di scrittura valgono sempre, anche senza invocare la skill. Da invocare per lo sweep degli impegni, per chiudere le attese che il doctor segnala oltre la decadenza, per il riesame delle attese, per riunire uno stato con più sezioni «## Impegni» e per il rastrello mensile. Trigger: «sweep impegni», «controlla gli impegni», «quali impegni sono già fatti», «che cosa aspettiamo», «riesame delle attese», «rastrello», il doctor che segnala righe malformate, attese decadute o più sezioni «## Impegni», la prima sessione del mese.
---

# Impegni e attese

Un impegno vive in un solo posto: la sezione `## Impegni` dello stato del suo lavoro. Questa skill dice come si scrive la riga, quando una cosa merita una riga, come si chiude e come si ripulisce l'elenco. Le regole di scrittura valgono per chiunque scriva in `stati/`: Claude in sessione, le skill `inbox-processor`, `daily-digest`, `archiviazione`, il cliente a mano in Obsidian.

Gli stati stanno in `<cartella di Claude>/stati/`. La cartella di Claude è il ruolo CLAUDE della configurazione (di default `_Claude`), relativa alla radice del vault:
```
CL=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/configura.sh" get METIS_RUOLO_CLAUDE)
```
I comandi `grep` di questa skill si lanciano dalla radice del vault con `$CL` impostato così. I file che iniziano con `_` (il modello di stato) e la cartella `stati/archivio/` restano fuori da ogni conteggio.

## 1. Dove vive un impegno e come si scrive

**Una sola sezione `## Impegni` per stato**, subito dopo «Dove siamo», come nel modello di stato. Le voci datate del log raccontano la storia e non contengono impegni. Quando ogni voce datata apre una sua sezione, lo stesso impegno si ritrova in più copie, quelli già fatti restano aperti e nessuno rilegge l'elenco, perché l'elenco non sta in un posto solo. Il doctor conta le sezioni e segnala gli stati che ne hanno più di una.

Dentro la sezione: aperti in cima, chiusi in coda sotto `**Fatti:**`. I chiusi restano nel file, perché la prova di una chiusura sta spesso nelle righe vicine.

Le caselle aperte `- [ ]` si scrivono solo nella sezione `## Impegni`. Il doctor controlla ogni riga che inizia con `- [ ]` in tutto il file, e una casella aperta nel log o nelle note conta come impegno.

**Il formato della riga.** È quello che leggono il doctor e l'hook di avvio; una riga che se ne scosta resta invisibile ai conteggi o viene segnalata come malformata.
```
- [ ] **Testo** — contesto essenziale | AAAA-MM-GG | palla:me
- [ ] **Testo** — contesto essenziale | AAAA-MM-GG | palla:claude
- [ ] **Testo** — contesto essenziale | AAAA-MM-GG | palla:loro | decade:AAAA-MM-GG
```

- **`palla:`** ha tre valori, scritti in minuscolo:
  - `palla:me` — tocca al cliente;
  - `palla:claude` — tocca a Claude; resta separato da `me`. Il rischio è asimmetrico: un impegno di Claude finito nella lista del cliente è rumore, uno del cliente finito in quella di Claude sparisce dalla sua vista. Nel dubbio, `me`;
  - `palla:loro` — attesa da un interlocutore esterno.
  Qualunque altro valore (`palla:ufficio`, `palla:lui`, `palla:` vuoto) e la riga senza `palla:` sono malformati: il doctor li conta.
- **La data cambia significato con la palla.** Con `palla:me` o `palla:claude` è la **scadenza**: se passa, il doctor la segnala come scaduta (l'hook di avvio mostra quelli di `palla:me`). Con `palla:loro` è la **data di riesame**: se passa, si guarda di nuovo, senza allarme, perché non dipende da noi. La data sta fra due barre, subito prima di `palla:`. Se il cliente non ha una scadenza, se ne sceglie una con lui: una riga senza data non scade mai e scivola fuori dal radar.
- **`decade:`** è obbligatorio su ogni `palla:loro`, di default a **21 giorni** dall'apertura. Senza `decade:` il doctor conta la riga come malformata. Superata la data, l'attesa si chiude come decaduta (§ 6).
- **L'origine.** Se l'impegno non l'ha detto il cliente ma nasce da una fonte (mail, nota vocale, verbale), si scrive in coda la citazione: `🌱 origine: mail di Bianchi del 2026-10-07 — «ci mandi il preventivo entro venerdì»`. Un impegno aperto per errore produce un sollecito su una promessa che nessuno ha fatto; l'origine permette di controllarlo.

Una riga può avere righe figlie indentate sotto (dettagli, passaggi): restano attaccate alla riga madre in ogni spostamento.

## 2. Prima di scrivere un impegno: tre domande

**(a) C'è un'azione che deve compiere il cliente, o Claude?**
- Sì: è un impegno, `palla:me` o `palla:claude`.
- Il passo successivo dipende da un interlocutore: di regola è un **riconoscimento**, una riga `◇ X → cosa farne` nella sezione `## Se arriva` dello stato, senza data, palla né decadenza. Esempio: `◇ parere del consulente del lavoro → aggiornare la bozza di contratto e mandarla al cliente`. Diventa un'**attesa** `palla:loro` solo in tre casi:
  1. il cliente dice di aspettare una risposta;
  2. il documento inviato contiene una domanda esplicita, o serve un'approvazione per procedere;
  3. c'è una scadenza esterna vera (un bando, un'udienza, un termine di legge).
  «Inviato» registra un fatto: una riga nel log, senza attese. Ogni invio che contiene una richiesta genera un `◇`.
- Se il non arrivare di X blocca il lavoro, l'impegno si scrive dal nostro lato: «Y entro il …, con o senza X», `palla:me`.
- Il passo non tocca a nessuno di noi (una scadenza altrui, un evento atteso, una fase del processo che appartiene ad altri): non si scrive. L'errore tipico: il cliente prepara un documento, la consegna a terzi spetta a qualcun altro, e Claude segna «consegnare» come impegno del cliente.

**(b) Esiste già?** Si rilegge la sezione `## Impegni` dello stesso file e si aggiorna la riga esistente invece di scriverne una nuova. Se il dubbio riguarda un altro lavoro:
```
grep -n '^- \[ \]' "$CL"/stati/*.md | grep -i "parola"
```

**(c) È già stato fatto?** Se l'impegno è un invio o una risposta, prima di scriverlo si guarda la posta inviata (strumenti della posta, se collegati). «Da verificare se è partita», scritto per una mail che sta nella posta inviata da un giorno, sposta sul cliente un controllo che tocca a Claude. Se la posta non è collegata, lo si chiede al cliente in una riga.

## 3. Prima di aggiungere una voce datata a uno stato

In quest'ordine, sempre:
1. rileggere la sezione `## Impegni` di quel file;
2. chiudere con `[x]` e la prova ciò che il lavoro appena fatto ha completato;
3. aggiornare le righe che il lavoro ha cambiato (testo, data, palla);
4. aggiungere gli impegni nuovi, nella stessa sezione e nel formato del § 1;
5. chiudere i `◇` di «Se arriva» soddisfatti da ciò che è arrivato: `◇` diventa `◆`, con una riga nel log;
6. scrivere la voce datata nel log, poi il marcatore in fondo al file: `<!-- aggiornato da <istanza> AAAA-MM-GG -->`, dove l'istanza è `cli` per la sessione nel terminale (o il nome che il cliente dà alla sessione, se ne usa più d'una).

**Il fatto chiude l'impegno nello stesso giro.** Chi registra un fatto in uno stato (una mail ricevuta o inviata, un messaggio, l'esito di una riunione, un documento arrivato) guarda la sezione `## Impegni` e si chiede se quel fatto chiude una riga. Se sì, la spunta subito, con la prova, prima di scrivere la voce datata. Lo sweep (§ 5) è la rete di sicurezza.

## 4. Come si chiude

Tre esiti, e nessun altro:
- `[x]` con l'esito e la prova: `- [x] **Mandare il preventivo a Bianchi** ✅ 2026-10-09 — inviato alle 18:31, oggetto «Preventivo revisione contratti», verificato nella posta inviata`;
- `[x] … ⊘ decaduta (motivo, AAAA-MM-GG)` quando la risposta non arriverà, oppure `⊘ decaduta (auto AAAA-MM-GG)` per un'attesa chiusa alla decadenza (§ 6). Il testo della riga si conserva;
- la data spostata avanti: la data di riesame per `palla:loro` (con `decade:` spostato di conseguenza), la scadenza per `palla:me` e `palla:claude`.

La riga chiusa si sposta sotto `**Fatti:**`.

- **Un'attesa ha sempre uno dei tre esiti.** Una casella aperta con un testo che racconta la chiusura è una voce fantasma: i conteggi la vedono aperta, chi legge la crede chiusa.
- **Si chiude su prova.** «Non trovo tracce» non prova niente: molti impegni passano per telefono, a voce o per messaggio. L'errore è asimmetrico: un impegno aperto di troppo si vede al rastrello, uno chiuso e non fatto sparisce. Senza prova, si chiede al cliente; una chiusura sulla sua parola si scrive così: `✅ AAAA-MM-GG — fatto, a detta del cliente`.
- **Nessun automatismo chiude da solo**, con un'eccezione dichiarata: le attese `palla:loro` oltre `decade:` (§ 6).
- **La casella si cerca in tutti gli stati.** Quando un fatto chiude qualcosa, la riga corrispondente può stare in un lavoro diverso da quello del fatto, o in più copie:
  ```
  grep -n '^- \[ \]' "$CL"/stati/*.md | grep -i "destinatario o parola dell'oggetto"
  ```
  Si spuntano tutte le copie trovate. Una riga nel log, senza casella, si scrive solo se la casella non esiste.
- **Archiviare un lavoro** richiede che ogni impegno aperto e ogni `◇` siano chiusi con il cliente: lo fa la skill `archiviazione`, con l'esito `⊘ decaduta (archiviazione AAAA-MM-GG)` per ciò che il cliente lascia cadere.

## 5. Lo sweep: dall'impegno alla prova

Va nel verso opposto alla registrazione dei fatti: parte dagli impegni aperti e cerca la prova che siano già fatti. Trova gli impegni vecchi e quelli finiti nel lavoro sbagliato. Si fa su richiesta del cliente; conviene una volta alla settimana, per esempio il giorno del weekly digest.

1. Censire gli aperti: `grep -c '^- \[ \]' "$CL"/stati/*.md`, poi l'elenco con `grep -n`.
2. Isolare quelli con una formula d'invio o di consegna: «mandare», «inviare», «trasmettere», «rispondere», «riscontro a», «consegnare», «scrivere a».
3. Per ciascuno cercare la prova, dal canale meno costoso: la posta inviata degli ultimi 60 giorni con il destinatario o una parola dell'oggetto, aprendo il corpo della mail, perché l'oggetto non basta a sapere se una mail chiude l'impegno e gli allegati dicono se l'invio era completo; poi gli altri canali collegati.
4. Classificare: **chiudibile** (data, ora, destinatario, oggetto) · **parziale** (che cosa manca) · **nessuna prova** · **non verificabile per posta** (passa per altri canali).
5. Segnalare a parte i **duplicati** (lo stesso impegno in più righe o più stati) e i `palla:me` che **dipendono da terzi** (§ 2a): vanno riqualificati come `◇` o cancellati, con il sì del cliente.
6. Presentare l'elenco al cliente. Le chiusure si applicano dopo aver vagliato le prove una per una con lui; i «nessuna prova» restano aperti.

I **parziali** sono il risultato che vale di più: la mail c'era ma non copriva l'impegno. Una risposta di cortesia («ci lavoro e le mando tutto nei prossimi giorni») a una richiesta di sostanza rinnova la promessa: l'impegno si riscrive con la promessa nuova e la data nuova, e resta aperto. Sono i casi che un automatismo chiuderebbe per sbaglio.

## 6. Le attese: decadenza e riesame

**Decadenza.** Il doctor segnala le attese `palla:loro` con `decade:` superata. Alla prima sessione dopo la segnalazione, Claude le chiude senza chiedere: `- [x] **Testo** … ⊘ decaduta (auto AAAA-MM-GG)`, con la data del giorno in cui le chiude, conservando il testo, e le sposta sotto `**Fatti:**`. Le decadute della settimana finiscono in un solo elenco nel weekly digest, e il cliente le riapre con una parola: un'attesa riaperta torna `palla:loro` con data di riesame e `decade:` nuovi. Per trovarle a mano:
```
grep -n '^- \[ \].*palla:loro' "$CL"/stati/*.md
```
e confrontare `decade:` con la data di oggi.

**Riesame.** Le attese `palla:loro` con la data di riesame passata e `decade:` ancora futura (il weekly digest le elenca «in riesame») si presentano al cliente una volta sola, tutte insieme. Tre esiti per ciascuna: viva (data di riesame avanti), decaduta (`⊘ decaduta (motivo, data)`), da sollecitare (diventa `palla:me` con una scadenza: «sollecitare Bianchi», con la data scelta dal cliente).

## 7. Riunire più sezioni «## Impegni»

Sintomo: il doctor segnala lo stato, oppure `grep -c '^## Impegni' file.md` restituisce più di 1. Il conteggio prende ogni intestazione che inizia con `## Impegni`, anche «## Impegni aperti».

1. Copia di sicurezza del file nella cartella temporanea della sessione.
2. Contare le `- [ ]` **prima**.
3. Raccogliere le `- [ ]` di tutte le sezioni come blocchi, con le righe figlie indentate.
4. Lasciare i `[x]` dove sono, nelle voci datate: sono cronaca, e spostarli stacca la prova dal fatto. L'intestazione `## Impegni` residua di quelle voci si rinomina (per esempio `**Impegni chiusi in questa voce:**`), altrimenti il conteggio delle sezioni non scende.
5. Scrivere una sola sezione `## Impegni` dopo «Dove siamo», con il commento del modello di stato, aperti in cima e `**Fatti:**` in coda.
6. Togliere i doppioni: fra due formulazioni della stessa cosa si tiene la più recente e la più precisa.
7. Verificare: le `- [ ]` **dopo** sono al massimo quante erano prima, e la differenza sono i doppioni, da elencare al cliente; poi `bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"` e, nel report `doctor.md` della cartella di Claude, la sezione «Lavori (stati)» senza quello stato fra quelli con più sezioni.
8. Marcatore: `<!-- aggiornato da <istanza> AAAA-MM-GG (riunione impegni: N sezioni → 1) -->`.

Se un'altra sessione sta lavorando sullo stesso stato, si aspetta che abbia finito: due scritture sullo stesso file si sovrascrivono.

## 8. Il rastrello mensile

Alla prima sessione del mese (`CLAUDE.md`, «Prima sessione del mese»), nello stesso giro in cui la skill `archiviazione` propone i lavori fermi, un solo elenco al cliente:
- i `palla:me` e `palla:claude` scaduti o superati dai fatti, uno per riga, con la proposta (chiudere con l'esito, spostare la data, lasciar cadere);
- i `◇` di «Se arriva» più vecchi di 12 mesi.

Il cliente risponde in una riga («chiudi 1 e 4, sposta il 2 a fine mese, il resto cade»). Per i `palla:me` non esiste una decadenza automatica: un impegno del cliente si chiude solo con una sua parola.

## 9. Come si vede se il sistema funziona

Tre cifre, una volta alla settimana (il weekly digest le riporta):
- **aperti**: `grep -c '^- \[ \]' "$CL"/stati/*.md`;
- **scaduti**: i `palla:me` e `palla:claude` con la data passata, che il doctor conta (l'hook di avvio mostra i `palla:me`);
- **chiusi nella settimana**: le righe `[x]` con `✅` e una data della settimana.

Il doctor segnala anche le righe malformate e i lavori fermi da più di 30 giorni. Se aperti e scaduti non scendono nelle settimane, gli impegni si scrivono senza chiudersi: è il momento di uno sweep e di un rastrello fuori calendario. Un controllo che tace non si distingue da un controllo che non gira: se il report del doctor è vecchio di giorni, lo si dice al cliente.
