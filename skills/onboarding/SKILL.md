---
name: onboarding
description: Mette Claude in condizione di lavorare con il cliente in dieci minuti del suo tempo, e completa il resto nell'uso. L'avvio chiede solo ciò senza cui l'assistente non parte - come funziona, chi è il cliente, quanta autonomia, dove stanno i file, la prova di posta e calendario, il primo lavoro. Il profilo di partenza vale da subito e si corregge con il gesto; stile dai documenti d'esempio, schede di dominio, persone e temi si fanno quando servono, con le procedure delle tre fasi. Da invocare dopo l'installazione, quando l'hook di avvio segnala «Avvio da fare», o su richiesta, anche per una sola procedura. Trigger - "onboarding", "avvio", "riprendi l'onboarding", "compiliamo il profilo", "configuriamo Claude su di me", "come ti insegno il mio modo di lavorare", "affina il mio profilo con i miei documenti".
---

# Onboarding

Il cliente compra un Claude che lo conosce e che migliora con le sue correzioni. L'onboarding gli costa **dieci minuti**: all'inizio si chiede solo ciò senza cui l'assistente non parte. Il resto parte con i valori del pacchetto e si corregge lavorando, con il ciclo delle correzioni descritto in `CLAUDE.md` (decisione del 24/10/2026).

## I principi

1. **Dieci minuti, poi l'uso.** Nell'avvio non si chiede niente che si possa correggere dopo. Le questioni minori si lasciano al gesto di correzione.
2. **Bozza e reazione.** Ogni domanda arriva con una proposta già scritta; dove ci sono due strade, due opzioni e una raccomandazione. Una domanda alla volta, in prosa breve.
3. **Il profilo di partenza vale da subito.** Le regole marcate `[di partenza]` sono attive. Una regola corretta con il gesto diventa del cliente e perde il marcatore; quelle mai toccate si rivedono in un solo elenco alla prima sessione del mese (`CLAUDE.md`, «Prima sessione del mese»).
4. **Il resto solo se necessario.** Una sezione vuota del profilo si compila quando un compito ne ha bisogno, con una domanda sola in quel momento: per esempio la persona grammaticale al primo testo a firma del cliente. Niente riproposte periodiche e niente promemoria all'avvio.
5. **I documenti del cliente restano suoi.** Si leggono dove stanno, sul suo disco. Nel profilo entrano regole e forme; restano fuori passi dei documenti, nomi di terzi, dati e cifre. Gli esempi «prima → dopo» si riscrivono su casi inventati.
6. **Si scrive subito.** Ogni risposta va nel file nello stesso turno. Una sessione può chiudersi a metà senza perdere niente.

## Dove si tiene il segno

L'onboarding ha il suo stato: `stati/onboarding.md` nella cartella di Claude (la riga «memoria operativa di Claude» della tabella dei ruoli in `CLAUDE.md`; in un vault nuovo è `_Claude/`). Si crea all'inizio dell'avvio con il testo di `references/stato-onboarding.md`. Una tappa chiusa si scrive nella forma fissa `fatto · YYYY-MM-DD`. Le voci rimandate stanno nella sua sezione `## Da completare nell'uso`: non sono impegni, non hanno data né palla, e si chiudono quando l'uso le ha coperte.

## Da dove riprendere

All'avvio, prima di parlare al cliente, si guarda dove si è arrivati, sui file, e lo si riporta in una riga.

| Che cosa | Fatto quando | Controllo |
|---|---|---|
| Avvio | la tappa 1 è `fatto` nello stato; nel profilo non restano commenti `<!-- AVVIO`; esiste uno stato di lavoro oltre a `onboarding.md` | `grep -c '<!-- AVVIO'` su `profilo-nucleo.md` e `profilo-completo.md`: zero; elenco di `stati/` |
| Revisione delle regole di partenza | la tappa 2 è `fatto`; nel profilo non restano `[di partenza]` | `grep -c '\[di partenza\]'` sui due file del profilo: zero |

Se l'avvio non è fatto, si riprende dal primo passo mancante. Se è fatto, non si propone niente: il resto arriva con l'uso. Fatte le due tappe, si propone di archiviare lo stato `onboarding.md`.

## L'avvio in dieci minuti

Una sessione sola. Le durate sono stime da misurare con i primi clienti. Se a installare è stato un professionista per conto del cliente, i dieci minuti sono quelli del cliente; le scelte tecniche le ha già fatte l'installazione.

| # | Che cosa | Come | Dove si scrive | Minuti |
|---|---|---|---|---|
| 1 | **Come funziona** | Tre righe, con parole vicine a queste: «Io preparo, tu decidi. Quando un mio lavoro non va, dimmelo così: questo non va perché…, d'ora in poi… Lo scrivo e non lo ripeto. Prima di uscire, scrivi "chiudi sessione"» | niente | 1 |
| 2 | **Chi sei** | Nome, mestiere, materie in cui ne sai più delle fonti, per chi lavori (per categoria, senza nomi), lingua di lavoro. Se l'installazione ha già scritto qualcosa, si conferma | nucleo «Chi sono» (si cancella il commento `AVVIO`), pagina completa sezione 1 | 3 |
| 3 | **Quanta autonomia** | A: «procedi e chiedimi solo quando una scelta è irreversibile o cambia il senso di un mio testo». B: «prima di ogni modifica ai miei file dimmi che cosa farai e aspetta il mio sì». Raccomandazione: A per chi vuole velocità, B per chi vuole prima fidarsi | nucleo «Come lavoro con te»: la regola scelta perde `[di partenza]`, il commento `AVVIO` si cancella | 1 |
| 4 | **Dove stanno i tuoi file** | Dove sono oggi i documenti dei lavori in corso. Proposta: la struttura scritta in `CLAUDE.md` (una cartella per lavoro con `_IN/`, `_fonti/` e `_OUT/`). Non si sposta niente: si annota dove stanno gli originali | log dello stato `onboarding.md` | 2 |
| 5 | **Posta e calendario** | Se l'installazione li ha collegati, una prova sola: «che cosa ho domani?» e la ricerca di una mail recente. Se non sono collegati, si dice in una riga come collegarli e si va avanti | esito nel log dello stato `onboarding.md` | 2 |
| 6 | **Il primo lavoro** | Il nome di un lavoro vivo. Claude crea la cartella del lavoro e lo stato minimo: titolo, obiettivo in una riga marcato come ipotesi, «Dove siamo» in una riga | `stati/<lavoro>.md` dal modello di stato | 1 |

Alla fine: tappa 1 `fatto · YYYY-MM-DD` nello stato `onboarding.md`; la riga dell'onboarding in «Ultime sessioni» di `_Claude.md` diventa «avvio fatto»; al cliente due righe su che cosa succede adesso («lavoriamo; quando qualcosa non ti somiglia, usa il gesto»).

## Nell'uso, solo se necessario

| Che cosa | Quando | Procedura |
|---|---|---|
| Una sezione vuota del profilo (lingua, testi a mio nome, registri, documenti in revisione, verso l'esterno, ruoli) | quando un compito ne ha bisogno: una domanda sola, con la proposta | `references/fase-1-profilo.md`, punto 4, per la domanda e la proposta |
| Le regole `[di partenza]` | si correggono con il gesto; quelle mai toccate si rivedono alla prima sessione del mese | `CLAUDE.md`, «Prima sessione del mese» |
| Lo stile ricavato dai documenti d'esempio | se il cliente lo chiede, o se le correzioni di stile si ripetono e mostrano che il profilo non gli somiglia: allora lo si propone una volta | `references/fase-1-profilo.md`, punti 1-3 e 7 |
| L'obiettivo completo di un lavoro | alla prima sessione vera su quel lavoro | skill `definizione-obiettivi`; `references/fase-2-lavori.md`, punto 2 |
| La scheda di dominio, le sezioni 3-4 della pagina completa | alla prima norma o fonte del campo usata in un lavoro | `references/fase-2-lavori.md`, punto 3; routine di fine sessione, «Dominio» |
| Le note delle persone | al primo interlocutore diretto di un lavoro | `references/fase-2-lavori.md`, punto 4; routine di fine sessione, «Persone» |
| I temi per i tag | quando i lavori ne mostrano tre o più ricorrenti: si propone l'elenco una volta | `references/fase-2-lavori.md`, punto 5 |
| Il patto e la prima correzione dal vivo | il patto è nel passo 1 dell'avvio; la prima correzione arriva da sola | `references/fase-3-patto.md`, se il cliente vuole il quadro completo |

Quando una voce matura, la si fa e si chiude la sua riga in `## Da completare nell'uso`. Una voce che l'uso non fa mai maturare resta lì senza costo.

## Quando una correzione diventa regola

Vale durante l'onboarding e dopo, ed è la stessa regola di `CLAUDE.md`, «Il ciclo delle correzioni»:
- il **caso** si registra sempre in `correzioni.md`, nello stesso turno;
- la **regola** entra subito nel profilo se riguarda lo stile o il rapporto con il cliente, è univoca e il cliente la conferma; altrimenti aspetta la distillazione di inizio mese. Se corregge una regola `[di partenza]`, la si riscrive nella forma del cliente, senza marcatore.

## Dipendenze

| Componente | Dove serve | Ripiego se manca |
|---|---|---|
| skill `definizione-obiettivi` | obiettivo completo di un lavoro | `references/fase-2-lavori.md`, punto 2 |
| skill `impegni` | righe d'impegno negli stati | il formato nel commento della sezione `## Impegni` del modello di stato |
| skill `autorevisione` | controllo del profilo dopo un affinamento | le quattro domande della sezione 4 del modello `profilo-completo.md` |
| connettori di posta e calendario | passo 5 dell'avvio | si salta il passo e lo si scrive nel log |
| doctor | fine avvio | il comando che l'installazione scrive in `_Claude.md`; se non c'è, si salta e lo si dice |

## Regole di scrittura dei file che si compilano

- Si scrive nella lingua del cliente; le regole del profilo parlano a Claude in seconda persona («scrivi», «evita»), come nel modello.
- Si rispettano i tetti di `_Claude.md`, «Tetti del contesto». Il nucleo contiene solo ciò che vale in ogni testo; il dettaglio va nella pagina completa.
- Una sezione del modello che non serve al cliente si cancella intera, e nel log dello stato si scrive quale e perché, con le parole del cliente.
- Ogni regola del profilo viene da una risposta del cliente, da un suo documento o da una sua correzione, oppure è `[di partenza]`: lo si sa dire.

## Chiusura della sessione di avvio

1. Aggiornare lo stato `onboarding.md` (dove siamo, voci rimandate) e la sua riga in «Lavori attivi» di `_Claude.md`.
2. Log della sessione.
3. Dire al cliente in due righe che cosa è fatto e come si continua.
