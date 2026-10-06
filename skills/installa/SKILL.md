---
name: installa
description: Installa Metis sul Mac e nel vault del cliente, un blocco alla volta, con un controllo di riuscita alla fine di ogni blocco. Fondamenta (dotazione, struttura del vault, memoria, hook e permessi), poi il profilo con la skill onboarding, poi i moduli facoltativi (MarkItDown, Word, Google, Microsoft 365, Telegram, voce, routine), ciascuno rilanciabile da solo. Trigger: "installa", "installa Metis", "installa telegram", "installa google", "installa microsoft", "installa markitdown", "installa docx", "installa voce", "installa routine", "rifai il blocco", "controlla l'installazione".
---

# Installa

Claude conduce l'installazione; il cliente fa solo ciò che richiede la sua persona: login, consensi, permessi di macOS, creazione del bot, scelte.

## I principi

1. **Un blocco alla volta, e ogni blocco si chiude con il suo controllo.** Il controllo si esegue e il suo esito si riporta al cliente. Se non passa, il blocco resta aperto e si dice che cosa manca.
2. **Si può rilanciare.** Ogni blocco e ogni modulo guarda che cosa esiste già e fa solo ciò che manca. «Installa telegram» rifà il solo modulo Telegram.
3. **Le note del cliente non si toccano.** In un vault esistente non si sposta, non si rinomina e non si riscrive nessuna nota; si creano solo le cartelle che mancano. PARA si propone solo per un vault nuovo (decisione del 29/9).
4. **Si installa solo ciò che il cliente ha scelto.** La scelta dei moduli si fa al blocco 0 e si scrive nella configurazione (`METIS_MODULI`).
5. **Niente invii, niente segreti in chiaro.** Chiavi e token vanno in file con permessi 600 fuori dal vault; le prove dei canali in uscita si fanno solo verso il cliente stesso.

## Gli strumenti

Gli script stanno nella cartella del plugin (`scripts/`); la configurazione in `~/.config/metis/config`, righe `CHIAVE=valore`, lette e mai eseguite.
- `configura.sh get|set|aggiungi|mostra` — legge e scrive la configurazione, una chiave alla volta.
- `verifica-dotazione.sh [modulo ...]` — che cosa c'è sul Mac e che cosa manca per ciascun modulo.
- `installa-struttura.sh albero|crea|controlla` — cartelle del vault e mappatura dei ruoli.
- `installa-modelli.sh <modelli> "<Nome>"` — i file della memoria.
- `installa-permessi.sh` — le regole di Claude Code per il vault e per le routine.
- `doctor.sh` — il controllo giornaliero, usato anche come controllo di riuscita.

## La sequenza

| Blocco | Riferimento | Controllo di riuscita |
|---|---|---|
| 0. Dotazione e scelte | `references/blocco-0-dotazione.md` | `verifica-dotazione.sh fondamenta <moduli scelti>` esce con 0; configurazione scritta |
| 1. Struttura del vault | `references/blocco-1-struttura.md` | `installa-struttura.sh controlla` esce con 0 |
| 2. Memoria | `references/blocco-2-memoria.md` | doctor: sezione «Tetti del contesto» tutta ✅ |
| 3. Hook e permessi | `references/blocco-3-hook-permessi.md` | alla sessione nuova compare l'orientamento; una lettura nella cartella riservata è bloccata |
| 4. Profilo | skill `onboarding`, fase 1 | criteri della skill `onboarding` |
| 5. Moduli scelti | `references/moduli.md` | il controllo di ciascun modulo |
| 6. Primo lavoro | skill `onboarding`, fase 2 | criteri della skill `onboarding` |
| 7. Patto e chiusura | skill `onboarding`, fase 3 | doctor verde, o giallo con motivi noti |

Le fondamenta (blocchi 0-3) vengono prima di tutto; il profilo prima dei connettori; i connettori prima della fase 2 dell'onboarding, che può partire dalla posta.

## Da dove riprendere

All'avvio si legge la configurazione (`configura.sh mostra`) e si eseguono i controlli dei blocchi in ordine, senza cambiare niente: il primo che non passa è il punto da cui si riprende. Si riporta al cliente in una riga per blocco. «Installa <modulo>» salta questa ricognizione e va al modulo, dopo aver controllato che le fondamenta passino.

## Stato dell'installazione

L'installazione è un lavoro del cliente come gli altri: `stati/installazione.md` nella cartella di Claude, dal modello di stato, con un impegno per ogni blocco o modulo non chiuso (per esempio «creare il bot con @BotFather», `palla:me`). Si crea al blocco 2, quando la cartella di Claude esiste; per i blocchi 0 e 1 fa fede la configurazione.

## Chiusura di ogni sessione d'installazione

1. Aggiornare lo stato `installazione.md`: blocchi chiusi con la data e l'esito del controllo; impegni rimasti.
2. Lanciare il doctor e riportare il semaforo, se la cartella di Claude esiste già (dal blocco 2); prima del blocco 2 si dice che il controllo arriva con la memoria.
3. Dire al cliente in due righe che cosa è fatto, che cosa resta e come riprendere («quando vuoi, scrivi: installa»).
