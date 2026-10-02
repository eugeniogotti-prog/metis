# Fase 1 — il profilo

**Precondizioni:** modelli e hook installati; `profilo-nucleo.md` e `profilo-completo.md` presenti nella cartella di Claude.

**Esito:** `profilo-nucleo.md` compilato, senza `COMPILARE` né `[da confermare]`, sotto il suo tetto; `profilo-completo.md` compilato tranne le sezioni 3 e 4, che completa la fase 2; il cliente conosce il gesto di correzione.

## 1. Apertura

Claude spiega al cliente, con parole semplici:
- legge alcuni documenti che il cliente considera ben fatti e ne ricava una bozza del suo modo di scrivere e di lavorare;
- il cliente corregge la bozza; ciò che conferma entra nel profilo, che Claude rilegge all'inizio di ogni sessione;
- i file restano dove sono, sul disco del cliente. Per leggerli, il loro testo passa dal servizio Claude con l'abbonamento del cliente, come ogni cosa che Claude legge. Per questo conviene scegliere documenti senza dati riservati di terzi, oppure già resi anonimi;
- nel profilo entrano solo regole e forme. Contenuti, nomi di terzi e cifre restano fuori.

Si chiede il consenso esplicito alla lettura e lo si registra nel log dello stato `onboarding.md` («consenso alla lettura dei documenti d'esempio: sì, YYYY-MM-DD»). Senza consenso si passa al percorso senza documenti (punto 4), e nel profilo restano le sole regole nate dalle risposte.

## 2. I documenti d'esempio

Si chiede una cartella con 5-10 documenti del cliente che lui considera ben fatti, di tipi diversi: per esempio due pareri o relazioni, due mail importanti, un documento per un cliente, un testo breve. Se li ha, anche **coppie prima/dopo**: una bozza (sua, di un collaboratore o di Claude) e la versione mandata dopo averla corretta. Le coppie valgono più dei documenti singoli, perché mostrano che cosa il cliente toglie e che cosa aggiunge.

Se la cartella non è pronta: impegno nello stato `onboarding.md` («portare i documenti d'esempio», `palla:me`, con una data scelta dal cliente) e intanto si fanno le domande del punto 4.

## 3. La lettura

I PDF si leggono direttamente. I documenti Word si convertono in testo con `textutil -convert txt -stdout <file>` (macOS), oppure con lo strumento di conversione del pacchetto se è già installato. Si legge un documento alla volta, per intero, e si controlla che il testo convertito non sia vuoto (`textutil` esce senza errore anche su un file che non trova).

`textutil` toglie i commenti e le note a piè di pagina, e restituisce il testo con le revisioni già accettate. Prima di scrivere osservazioni su come il cliente usa le note o su che cosa corregge:
- note: `unzip -p <file.docx> word/footnotes.xml | grep -c '<w:footnote '` (Word ne mette due di servizio: oltre due, il documento ha note);
- revisioni: `unzip -p <file.docx> word/document.xml | grep -c '<w:del '` (più di zero: il documento ha revisioni).
Se una coppia prima/dopo arriva come un solo file con revisioni, si chiedono al cliente i due file separati, perché la conversione perde il «prima».

Dopo ogni documento si scrivono nel log dello stato `onboarding.md` le osservazioni, senza copiare passi del testo:

| Che cosa guardare | Esempio di osservazione |
|---|---|
| persona grammaticale | «scrive sempre al singolare: "ritengo", "propongo"» |
| apertura e chiusura | «apre con la conclusione; chiude senza formule di cortesia» |
| lunghezza di frasi e paragrafi | «paragrafi di 3-4 righe; elenchi solo per enumerare» |
| struttura dei documenti lunghi | «premessa, quadro normativo, analisi, conclusioni» |
| come cita le fonti | «articolo e comma nel testo, mai in nota» |
| lessico preferito e parole evitate | «usa "rilevare", evita "evidenziare"» |
| forme che toglie (dalle coppie) | «toglie gli avverbi di rinforzo; toglie le premesse» |
| tono verso i diversi destinatari | «caldo con i colleghi, impersonale con gli enti» |
| distinzioni di merito che il cliente tiene separate | «distingue sempre la qualifica civilistica da quella fiscale» |

Quando un tratto si può misurare (frasi per paragrafo, lunghezza delle mail, numero di opzioni proposte), lo si conta su tutti i documenti e la regola porta il numero: «al massimo tre frasi per paragrafo», al posto di «paragrafi brevi».

Una regola entra nella bozza se si vede in almeno due documenti, o in una coppia prima/dopo. Una forma vista una volta sola diventa una domanda. Le distinzioni di merito si annotano per la sezione 4 della pagina completa, che si chiude in fase 2.

## 4. Le domande che i documenti non risolvono

**Il profilo di partenza.** Il nucleo installato contiene già, marcate «[da confermare]», le proposte per Forme da evitare, Tono, In chat, Come lavoro con te, Sintesi per un esperto, Testi a mio nome e «Verso chi riceve il lavoro»: vengono dal profilo di un professionista che lavora con Claude da mesi (decisione del 2/10/2026). La sezione «Onestà epistemica» è del pacchetto e non si tocca: il cliente può aggiungere regole, non toglierle. Per le domande qui sotto la proposta è quella già scritta nel nucleo; Claude la confronta con i documenti letti e dice se la confermano, se la contraddicono (e propone la variante) o se non dicono nulla. Il rischio da evitare è il «sì» a blocco: la regola ereditata si presenta una per volta, con l'esempio, e se il cliente esita si toglie.

Ogni domanda con la sua proposta; dove ci sono due strade, due opzioni e una raccomandazione.
- **Chi è** (nucleo e sezione 1): mestiere, domini in cui ne sa più delle fonti, per chi lavora (per categoria, senza nomi), attività personali che Claude potrebbe incontrare nel vault. Proposta: tre righe ricavate dai documenti.
- **Lingua**: parole che non vuole, come trattare le citazioni in lingua straniera. Proposta dai documenti.
- **Tono verso di sé** (nucleo, «Tono»): come Claude deve parlargli, come esprimere un apprezzamento o un dissenso, che cosa fare quando il cliente critica un output. Proposta: «diretto, senza premesse; se critico un output, adeguati senza difenderlo».
- **Avvisi**: come vuole essere avvisato di un problema. Proposta: «subito, in una riga, con la tua proposta».
- **Come lavorare con lui** (nucleo e sezione 6, «Ritmo»): due opzioni. A: «procedi sulle operazioni tecniche e chiedimi solo quando una scelta è irreversibile o cambia il senso di un mio testo». B: «prima di ogni modifica ai miei file dimmi che cosa farai e aspetta il mio sì». Raccomandazione: A per chi vuole velocità, B nelle prime settimane per chi vuole prima fidarsi.
- **In chat**: quanto vuole leggere mentre si produce un documento, e che cosa fare quando dice «non ho capito». Proposta: «in chat il principio in due frasi e la scelta da confermare; il testo va nel file. Se non capisco, riformula da capo, più semplice, con un esempio».
- **Decisioni**: come vuole le scelte. Proposta dai documenti, se il cliente le pone in un modo riconoscibile; altrimenti «una alla volta, al massimo due opzioni, con la tua raccomandazione».
- **Sintesi per un esperto** (sezione 2): che cosa vuole da una sintesi di un documento del suo campo. Proposta: dati citabili con la fonte; come la fonte incornicia il tema; dove la fonte è attaccabile o conferma ciò che il cliente ha scritto.
- **Documenti in revisione presso altri** (sezione 5): come lavorare su un testo che un interlocutore sta rivedendo. Proposta: commenti ancorati al testo, revisioni minime.
- **Verso l'esterno** (sezione 6): la regola di base è già nel pacchetto (bozze, mai invii senza il suo sì). Si chiede se ha altro da aggiungere.
- **Dove non fidarti del tuo giudizio, ruoli specifici** (sezioni 6 e 7): si chiede se esistono. Spesso la risposta è «no», e le sezioni si cancellano.

## 5. Le forme tipiche da proporre

Queste forme ricorrono nelle correzioni da cui nasce il pacchetto. Le prime sei sono già nel nucleo come «[da confermare]»; la settima, se il cliente la tiene, va in «Lingua». Si propongono una per una, con l'esempio, e si tengono solo quelle in cui il cliente si riconosce. Se i documenti mostrano già la forma, o mostrano che il cliente la usa, lo si dice.

1. **Negazione seguita dall'affermazione**: «Non è una richiesta: è un atto dovuto» → «È un atto dovuto». Anche con la negazione in coda: «previsto come opzione, non come requisito» → «previsto come opzione».
2. **Avverbi e aggettivi di rinforzo**: «risultati davvero notevoli» → «risultati notevoli».
3. **Chiuse a effetto** e motivazioni aggiunte in coda a una frase che si regge da sola.
4. **Giudizi dove basta il fatto**: «un dato preoccupante: il 40% dei fascicoli è incompleto» → «il 40% dei fascicoli è incompleto».
5. **Premesse e avvertenze di rito**: «È importante sottolineare che…», «Come noto…».
6. **Riferimenti interni** che il destinatario non conosce (versioni precedenti, discussioni fra colleghi).
7. **Anglicismi** quando esiste la parola italiana, se il cliente scrive in italiano.

Si propongono a blocco, dopo le regole ricavate dai documenti: «queste forme ricorrono nelle correzioni di altri professionisti; quali tieni?».

## 6. Copertura dei modelli

Ogni sezione dei due modelli ha una fonte. Prima di presentare la bozza si controlla che nessuna resti senza.

| Sezione | Da dove viene |
|---|---|
| nucleo: Chi sono, Lingua | documenti + punto 4 |
| nucleo: Forme da evitare | documenti (coppie) + punto 5 |
| nucleo: Onestà epistemica | già scritta nel modello (regole del pacchetto); si aggiunge ciò che emerge |
| nucleo: Tono | profilo di partenza + punto 4, «Tono verso di sé» |
| nucleo: In chat, Come lavoro con te, Sintesi per un esperto | profilo di partenza + punto 4 |
| nucleo: Testi a mio nome | documenti (persona grammaticale) + profilo di partenza |
| nucleo: Verso chi riceve il lavoro | profilo di partenza; si chiede se il cliente lavora per committenti, enti o superiori, altrimenti si cancella |
| nucleo: Registri specifici | un rimando per ogni sottosezione compilata della sezione 5 della pagina completa |
| completa 1-2 (Chi sono, Come parlarmi, Sintesi per un esperto) | documenti + punto 4; «Forme da evitare» dal punto 5 |
| completa 3 (Come verificare nel mio campo) | documenti (come cita le fonti) + fase 2 |
| completa 4 (errori, distinzioni del dominio) | distinzioni annotate al punto 3 + fase 2 |
| completa 5 (registri) | documenti, una sottosezione per tipo di documento letto; «Documenti in revisione» dal punto 4 |
| completa 6-7 | punto 4 |
| completa 8 | già scritta nel modello; si aggiunge ciò che emerge |

Una sezione che non serve si cancella intera, e il log dello stato dice quale e perché. Anche il commento `COMPILARE` d'intestazione di ciascun modello si cancella a fine fase.

## 7. La bozza e la reazione

1. Si scrive la bozza completa del nucleo e della pagina completa, partendo dal nucleo installato. Le regole ricavate dai documenti sono affermazioni; le proposte del profilo di partenza e del punto 4 restano marcate «[da confermare]». Una regola di partenza che i documenti contraddicono si riscrive nella forma del cliente, sempre marcata.
2. Si presentano al cliente prima le regole ricavate dai documenti, a blocchi, poi le domande singole, non più di dodici per sessione. In chat va il blocco, breve; il file intero è a disposizione se lo vuole leggere.
3. Si recepisce ogni correzione nella forma in cui il cliente la dà. Se il cliente dice che una regola non gli appartiene, la regola si toglie senza difenderla.
4. A sezione confermata: si scrive nel file, si cancella il suo commento `COMPILARE` e ogni «[da confermare]», si passa alla successiva. Una regola di partenza che il cliente non riconosce si cancella, senza difenderla; la sezione può restare vuota, e allora si cancella intera.

**Che cosa va nel nucleo e che cosa nella pagina completa.** Nel nucleo le regole che valgono in ogni testo e in ogni risposta. Nella pagina completa gli esempi estesi, i registri per tipo di documento, le distinzioni del dominio, gli errori che il cliente cerca quando rivede.

## 8. Prova sul campo e gesto di correzione

A profilo scritto, si chiede al cliente un compito breve e vero: una mail, un paragrafo. Claude lo scrive rileggendo il profilo. Prima che il cliente commenti, gli si insegna il gesto, in una riga:

> «Se qualcosa non va, dimmelo così: questo non va perché…, d'ora in poi…»

Ogni rilievo fatto con il gesto diventa un caso in `correzioni.md` e, se è di stile e il cliente lo conferma, una regola nel profilo, nello stesso turno (vedi `SKILL.md`, «Quando una correzione diventa regola»). La fase 3 riprende il gesto e lo inquadra nel patto.

## 9. Controlli di fine fase

- `grep -nE '<!-- COMPILARE|da confermare'` su `profilo-nucleo.md`: nessuna riga. Su `profilo-completo.md`: esattamente due righe, i commenti delle sezioni 3 e 4.
- Dimensione del nucleo sotto il tetto di `_Claude.md`.
- Nomi di terzi e cifre: si fa l'elenco dei nomi propri e delle cifre visti nei documenti d'esempio e lo si cerca nei due file del profilo: nessun risultato (il nome del cliente, in «Chi sono», è atteso).
- Nessuna frase di più di dieci parole copiata da un documento.
- Autorevisione, livello 1.
- Stato `onboarding.md`: tappa 1 `fatto · YYYY-MM-DD`.
