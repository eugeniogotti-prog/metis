# Prova completa del 29/9/2026 — passo 5

Vault vuoto, persona di prova interpretata da un agente, onboarding nelle tre fasi con i documenti d'esempio, tre compiti di scrittura prima e dopo. Claude Code 2.1.284, plugin caricato con `--plugin-dir`, sessioni non interattive (`claude -p`) avviate da `claude-prova.sh`.

## Come si è svolta

1. **Persona.** Un agente ha inventato Paola Rinaldi, consulente del lavoro a Bologna, con una scheda di 15 tratti (12 visibili nei documenti, 3 solo con le domande), sei documenti d'esempio (una coppia prima/dopo compresa), il materiale di un lavoro in corso, tre compiti e una griglia di valutazione. Scheda e griglia sono rimaste fuori dalla portata delle sessioni di prova: il recinto è stato collaudato (lettura negata).
2. **Installazione.** `scripts/installa-modelli.sh` su un vault vuoto, con la configurazione `config`: 8 file copiati, segnaposto sostituiti, sezione della cartella riservata tolta perché non configurata; seconda esecuzione idempotente.
3. **Prima.** I tre compiti in tre sessioni nuove, con il profilo vuoto.
4. **Onboarding**, in sette sessioni nuove, con «riprendi l'onboarding» fra una e l'altra; la cliente rispondeva per iscritto nei file che la skill preparava:
   - fase 1: 14 regole ricavate dai documenti da confermare a blocco e 12 domande singole (il tetto della skill); prova sul campo con una mail; un rilievo della cliente con il gesto è diventato il primo caso in `correzioni.md` e una regola nel profilo, su un esempio inventato. La sessione ha anche tolto dal profilo una regola che aveva aggiunto di suo;
   - fase 2: stato del lavoro pilota, due schede di dominio, due note persona, temi per i tag; la sessione ha segnalato da sola un conto che non tornava nei documenti della cliente e un'incongruenza di date;
   - fase 3: patto, correzione dal vivo, chiusura; stato dell'onboarding archiviato. In tutto 7 casi in `correzioni.md`.
5. **Doctor** (lanciato fuori dalla sessione): verde, 19 controlli, tutti i tetti rispettati. Nucleo del profilo 5.592/10.000; testo iniettato all'avvio 6.747/40.000.
6. **Dopo.** Gli stessi tre compiti in tre sessioni nuove.
7. **Valutazione alla cieca.** Un agente indipendente ha applicato la griglia ai testi, etichettati X e Y in ordine casuale; la chiave è stata aperta dopo.

## Esiti

| Compito | Prima | Dopo | Testo che la cliente manderebbe |
|---|---|---|---|
| 1. Mail a un titolare con un costo e una scelta | 2/8 | 6/8 | dopo |
| 2. Risposta a un lavoratore | 3/7 | 6/7 | dopo |
| 3. Paragrafo di circolare | 1/7 | 6/7 | dopo |
| **Totale** | **6/22** | **18/22** | **3 su 3** |

Profilo contro scheda: 14 tratti su 15 presi per intero (compresi i 3 che emergono solo dalle domande e il tratto misurabile «frasi di al massimo 25 parole, paragrafi di al massimo 4 frasi»); il lessico preferito (T5) preso a metà.

Restano da correggere anche dopo l'onboarding: il contratto collettivo non citato con settore e rinnovo nel compito 1, benché la regola sia nel profilo; una frase che condiziona «La mia indicazione è…»; un paragrafo di cinque frasi; una norma citata con l'atto prima dell'articolo. Sono errori di applicazione di regole già scritte: il ciclo delle correzioni li trasformerebbe in casi.

## Limiti della prova

- **Una sola esecuzione per compito**: la varianza fra esecuzioni non è misurata.
- **Valutatore e persona sono modelli**, della stessa famiglia di chi scrive; la cliente non è una persona reale e ha risposto per iscritto.
- **Contaminazione uguale per prima e dopo**: Claude Code carica comunque il `CLAUDE.md` globale dell'utente della macchina (regole su accenti e onestà sulle fonti), e le sessioni vedono i connettori claude.ai dell'account.
- **Automazioni, connettori di posta e calendario non provati**: `METIS_JOBS` vuoto, posta non collegata.

## Che cosa la prova ha trovato e corretto

1. **File di un plugin caricato**: Claude Code tratta come «sensitive» ogni file dentro la cartella del plugin, anche se è la cartella di lavoro; il vault di prova stava dentro il repository. Per la prova il plugin si carica da una copia; per il cliente non conta, perché il plugin si installa altrove.
2. **Riferimenti della skill illeggibili**: in una sessione senza permessi espliciti Claude non legge i file `references/` della skill dentro la cartella del plugin. Per il prodotto: i permessi preconfigurati (componente decisa il 29/9) devono consentire la lettura della cartella del plugin.
3. **Memoria di Claude Code**: se il vault sta dentro un repository git, Claude Code usa la radice del repository per la cartella di memoria. Corretto in `scripts/lib/config.sh`, con un test.
4. **`CLAUDE.md` segnalato come nota senza frontmatter** dall'hook: falso positivo, corretto in hook e doctor, con un test.
5. **Installazione idempotente**: la seconda esecuzione di `installa-modelli.sh` falliva con l'array vuoto (bash 3.2 con `set -u`); corretto.

Da decidere, emerso dalla fase 2: gli impegni di un collaboratore della cliente non hanno un valore di «palla» (oggi `me`, `claude`, `loro`).

## Dove stanno le cose

In questa cartella, fuori da git tranne questo file e `claude-prova.sh`: `persona/` (scheda e griglia nascoste), `documenti/`, `lavoro/`, `compiti/`, `vault/` (il vault dopo l'onboarding), `esiti/prima`, `esiti/dopo`, `esiti/onboarding-*.txt` (risposte finali di ogni sessione), `trascrizioni/` (le 19 sessioni avviate nel vault di prova, comprese quelle di controllo e di diagnosi), `memoria-claude-code/` (l'indice delle memorie della prova). La valutazione alla cieca con le tabelle è in `esiti/valutazione-cieca.md`.

Per rifare la prova: rimettere `memoria-claude-code/MEMORY.md` nella cartella di memoria ricavata da `scripts/lib/config.sh`, poi `bash claude-prova.sh <uscita> < prompt`.
