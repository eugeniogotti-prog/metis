---
name: onboarding
description: Costruisce con il cliente, nelle prime sessioni, ciò che serve a Claude per lavorare con lui. Fase 1, il profilo (nucleo e pagina completa), ricavato dai suoi documenti d'esempio con il metodo bozza e reazione. Fase 2, il primo lavoro, la prima scheda di dominio, le persone. Fase 3, il patto di collaborazione e il primo caso di correzione. Da invocare dopo l'installazione, quando l'hook di avvio segnala punti COMPILARE, o su richiesta, anche per una sola fase. Trigger: "onboarding", "riprendi l'onboarding", "onboarding fase 1", "fase 2 dell'onboarding", "compiliamo il profilo", "configuriamo Claude su di me", "come ti insegno il mio modo di lavorare".
---

# Onboarding

Il cliente compra un Claude che lo conosce e che migliora con le sue correzioni. Questa skill costruisce il punto di partenza: chi è, come scrive, su che cosa lavora, e come si corregge Claude. Dopo l'onboarding il sistema cresce con il ciclo delle correzioni descritto in `CLAUDE.md`.

## I principi

1. **Bozza e reazione.** Claude propone, il cliente corregge. Ogni domanda arriva con una proposta già scritta; quando la scelta ha due strade ragionevoli (per esempio sull'autonomia), si danno due opzioni e una raccomandazione. Una domanda alla volta, in prosa breve.
2. **Poche domande.** Ciò che i documenti mostrano con chiarezza si scrive e si fa confermare a blocchi («ho ricavato queste sei regole: le riconosci?»). Le domande singole si riservano a ciò che i documenti non dicono. Per sessione, non più di dodici domande singole; il resto va alla sessione successiva, annotato nello stato.
3. **Ciò che non si può dedurre si chiede.** Tono, struttura e forme ricorrenti si ricavano dai documenti. Come il cliente vuole essere trattato da Claude, il perché dei suoi lavori e i confini si chiedono, marcando la bozza come ipotesi.
4. **I documenti del cliente restano suoi.** Si leggono dove stanno, sul suo disco. Nel profilo entrano regole e forme. Restano fuori i passi dei documenti, i nomi di terzi, i dati e le cifre. Gli esempi «prima → dopo» si riscrivono su casi inventati.
5. **Si scrive subito.** Ogni sezione confermata va nel file nello stesso turno; le osservazioni sui documenti vanno nel log dello stato dell'onboarding appena fatte. Una sessione può chiudersi a metà, o essere compattata, senza perdere niente.
6. **Il cliente decide il ritmo.** Le tre fasi possono stare in una giornata o in più sessioni. La fase 1 viene prima delle altre, perché il profilo entra nell'avvio di ogni sessione successiva.

## Dove si tiene il segno

L'onboarding è il primo lavoro del cliente e ha il suo stato: `stati/onboarding.md` nella cartella di Claude (la riga «memoria operativa di Claude» della tabella dei ruoli in `CLAUDE.md`; in un vault nuovo è `_Claude/`). Si crea all'inizio con il testo di `references/stato-onboarding.md`. Le tre fasi sono le sue tappe; una tappa chiusa si scrive nella forma fissa `fatto · YYYY-MM-DD`. Alla fine della fase 3 lo stato si archivia in `stati/archivio/`.

## Da dove riprendere

All'avvio, prima di parlare al cliente, si guarda dove si è arrivati, sui file, e lo si riporta in una riga. Se il cliente ha chiesto una fase precisa, si controllano solo le sue precondizioni (in testa a ogni reference).

| Fase | Fatta quando | Controllo |
|---|---|---|
| 1. Profilo | la tappa 1 è `fatto` nello stato; `profilo-nucleo.md` non ha più marcatori `<!-- COMPILARE` né `[da confermare]`; in `profilo-completo.md` restano solo i marcatori delle sezioni 3 e 4, che completa la fase 2 | `grep -nE '<!-- COMPILARE\|da confermare'` sui due file: nessuna riga nel nucleo, esattamente due nella pagina completa; lettura della tappa |
| 2. Lavori | la tappa 2 è `fatto`; esiste uno stato oltre a `onboarding.md` senza segnaposto fra doppie graffe; `CLAUDE.md` e `profilo-completo.md` non hanno più marcatori `<!-- COMPILARE` né `{{COMPILARE` | `grep -c '{{'` sullo stato del lavoro; `grep -cE '<!-- COMPILARE\|\{\{COMPILARE'` sui due file |
| 3. Patto | la tappa 3 è `fatto` e nomina l'intestazione del caso fatto dal vivo; quell'intestazione esiste in `correzioni.md` | lettura della tappa; `grep` dell'intestazione in `correzioni.md` |

Si riprende dalla prima fase non finita. Se è tutto fatto, lo si dice e si propone di archiviare lo stato `onboarding.md`.

## Le tre fasi

Le durate sono stime da misurare con i primi clienti; al cliente si dicono come tali.
- **Fase 1, profilo** → `references/fase-1-profilo.md`. Stima: un'ora, più la lettura dei documenti. Dopo l'installazione di modelli e hook.
- **Fase 2, lavori, domini, persone** → `references/fase-2-lavori.md`. Stima: un'ora per il primo lavoro. Dopo i connettori di posta e calendario, se il cliente li ha scelti.
- **Fase 3, patto e primo caso di correzione** → `references/fase-3-patto.md`. Stima: mezz'ora. A fine installazione, dopo le automazioni.

Si legge il file della fase prima di cominciarla.

## Quando una correzione diventa regola

Vale durante l'onboarding e dopo, ed è la stessa regola di `CLAUDE.md`, «Il ciclo delle correzioni»:
- il **caso** si registra sempre in `correzioni.md`, nello stesso turno, qualunque sia il tipo di correzione;
- la **regola** entra subito nel profilo se riguarda lo stile o il rapporto con il cliente, è univoca e il cliente la conferma; altrimenti aspetta la distillazione di inizio mese.

## Dipendenze

La skill usa componenti che nel pacchetto arrivano con passi successivi. Finché mancano, vale il ripiego.

| Componente | Dove serve | Ripiego se manca |
|---|---|---|
| skill `autorevisione` | controllo di fine fase | rileggere i file con le quattro domande della sezione 4 del modello `profilo-completo.md` (fondato, obiettivo, preciso, detto bene) |
| skill `impegni` | righe d'impegno negli stati | il formato scritto nel commento della sezione `## Impegni` del modello di stato |
| skill `definizione-obiettivi` | obiettivo del lavoro pilota, fase 2 | il metodo descritto in `references/fase-2-lavori.md`, punto 2 |
| modello di nota persona | fase 2 | i campi minimi in `references/fase-2-lavori.md`, punto 4 |
| conversione di PDF e Word | lettura dei documenti, fase 1 | PDF: si leggono direttamente; Word: `textutil -convert txt -stdout <file>` (macOS), che però toglie commenti, note a piè di pagina e revisioni (vedi `references/fase-1-profilo.md`, punto 3); se il cliente ha lo strumento di conversione del pacchetto, quello |
| `routine-fine-sessione.md` | chiusura di sessione | i passi della sezione «Chiusura sessione» di `CLAUDE.md` |
| doctor | fine fase 2 e fase 3 | il comando che l'installazione scrive in `_Claude.md`; se non c'è, si salta e lo si dice |

## Regole di scrittura dei file che si compilano

- Si scrive nella lingua del cliente; le regole del profilo parlano a Claude in seconda persona («scrivi», «evita»), come nel modello.
- Ogni regola porta, quando serve, un esempio «prima → dopo» su un caso inventato.
- Si rispettano i tetti di `_Claude.md`, «Tetti del contesto». Il nucleo contiene solo ciò che vale in ogni testo; il dettaglio va nella pagina completa.
- Una sezione del modello che non serve al cliente si cancella intera, e nel log dello stato si scrive quale e perché, con le parole del cliente.
- Prima di dichiarare finita una fase: autorevisione, livello 1, sui file scritti. Il controllo principale è la fondatezza: ogni regola del profilo viene da un documento letto o da una risposta del cliente, e lo si sa dire.

## Chiusura di ogni sessione di onboarding

Anche se l'onboarding non è finito:
1. aggiornare lo stato `onboarding.md` (dove siamo, domande rimaste, impegni) e la sua riga in «Lavori attivi» di `_Claude.md`, con il contatore;
2. aggiornare la riga dell'onboarding in «Ultime sessioni» di `_Claude.md` (all'installazione dice «onboarding da fare»);
3. log della sessione; dei documenti letti si registrano i nomi dei file, senza passi del testo;
4. dire al cliente in due righe che cosa è fatto e che cosa resta, e come riprendere («quando vuoi, scrivi: riprendi l'onboarding»).
