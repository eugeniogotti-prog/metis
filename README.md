# Metis

**Il metodo di lavoro con Claude, nel tuo vault.**

Metis fa lavorare Claude Code dentro le tue cartelle, con una memoria organizzata che cresce con le tue correzioni. Claude impara chi sei, come scrivi, su che cosa stai lavorando e che cosa gli hai già corretto, e lo ricorda da una sessione all'altra. Dopo qualche settimana lavora come un collaboratore che ti conosce.

Funziona su Mac, con Claude Code e il tuo abbonamento Claude. Obsidian è consigliato per leggere e scrivere le note.

## Che cosa ottieni

- **Un profilo**: le regole su come scrivi e come vuoi lavorare. Parte da un profilo di partenza, nato da mesi di correzioni, che rivedi regola per regola: restano solo quelle in cui ti riconosci.
- **I tuoi lavori in ordine**: per ogni lavoro un file con l'obiettivo e il perché, a che punto siamo, gli impegni (chi deve muoversi ed entro quando) e i lavori simili già chiusi.
- **Un diario** delle sessioni, con le decisioni e il loro perché.
- **Ciò che Claude sa del tuo campo**, con la fonte e il grado di verifica di ogni affermazione.
- **Una mappa** dei lavori in corso e di quelli chiusi, che a ogni controllo del sistema segnala le cartelle spostate o rinominate.
- **Protezioni**: Claude lavora senza chiederti il permesso a ogni passo, ma mail e messaggi verso altri restano bozze finché non dici di inviarli; prima di cancellare cartelle o di operazioni delicate chiede; una cartella riservata, se la indichi, e le cartelle con le credenziali del Mac non vengono mai lette.
- **Moduli facoltativi**: posta e calendario (Google o Microsoft 365), lettura di PDF e documenti Office, Telegram e note vocali, giri automatici (briefing del mattino, sistemazione degli arrivi, sintesi della sera, riepilogo della settimana).

## Che cosa ti serve

- un Mac con macOS recente e i permessi di amministratore;
- un abbonamento Claude (Pro o Max; con un abbonamento Team o Enterprise dell'organizzazione, i connettori di posta e calendario li abilita l'amministratore);
- **Claude Code** installato (claude.com/claude-code) e collegato al tuo abbonamento;
- un account **GitHub**, con l'invito al repository di Metis accettato (te lo manda chi ti segue nell'installazione);
- se vuoi posta e calendario aziendali Microsoft 365: il consenso, una volta, di un amministratore dell'IT;
- per il profilo: **5-10 tuoi documenti ben fatti**, di tipi diversi, senza dati riservati di altri.

## Installazione

### 1. Collegare il Mac a GitHub (una volta)

Nel Terminale:
```bash
brew install gh
gh auth login
```
Scegli GitHub.com e HTTPS, rispondi **sì** alla domanda «Authenticate Git with your GitHub credentials?» e completa il login nel browser. Se `brew` non c'è, prima installa Homebrew da brew.sh.

### 2. Installare il plugin

```bash
claude plugin marketplace add eugeniogotti-prog/metis
claude plugin install metis@metis
claude plugin list
```
L'ultimo comando deve mostrare `metis@metis` con «enabled».

### 3. Lasciar condurre Claude

Entra nella cartella del tuo vault (o creane una vuota, per esempio `~/Documents/Vault`) e apri Claude Code:
```bash
cd ~/Documents/Vault
claude
```
Scrivi **«installa Metis»**. Claude conduce l'installazione un passo alla volta, ti fa le domande e controlla che ogni passo sia riuscito:
1. **il tuo Mac**: che cosa c'è e che cosa manca; se manca un programma, Claude ti dà il comando da lanciare;
2. **le cartelle**: se hai già un vault, Claude propone il ruolo di ogni cartella (lavori, aree, risorse, persone, archivio, arrivi, diario) e **non sposta nessuna nota**; se parti da zero, propone una struttura. Ti chiede anche in quale cartella del disco tieni i documenti di lavoro: resta quella che usi già;
3. **la memoria**: profilo, regole, modelli delle note. Tieni **Obsidian chiuso** in questo passo;
4. **le protezioni**: alla fine Claude ti chiederà di chiudere Claude Code, riaprirlo nella cartella del vault e **accettare la finestra che chiede se ti fidi della cartella** (ed eventualmente l'avviso sulla modalità senza richieste di permesso). Senza quel sì le protezioni non valgono;
5. **il profilo**: Claude legge i tuoi documenti d'esempio, se acconsenti, e ti presenta il profilo di partenza regola per regola. Circa un'ora;
6. **i moduli** che scegli, uno alla volta, anche in giorni diversi: «installa google», «installa microsoft», «installa markitdown», «installa telegram», «installa voce», «installa routine»;
7. **il primo lavoro**: ne scegli uno vivo e Claude ne scrive obiettivo, perché e impegni, in bozza da correggere.

## Come si lavora: quattro gesti

Pensa a Claude come a un collaboratore junior appena arrivato: capace e veloce, ma all'inizio non conosce te né il tuo lavoro. Lo formi lavorando insieme e lui cresce; a differenza di un junior in carne e ossa, non dimentica niente di ciò che gli insegni, perché lo scrive.

1. **Aprire**: Claude Code nella cartella del vault. Prima che tu dica una parola, Claude ha già letto il tuo profilo, lo stato dei lavori, gli impegni in scadenza e l'esito dell'ultimo controllo del sistema.
2. **Correggere**: quando un risultato non va, spiega il perché e lascia che il lavoro lo rifaccia lui: **«questo non va perché…, d'ora in poi…»**. Se lo sistemi a mano, non impara. Le regole di stile che confermi entrano subito nel profilo; ogni mese le correzioni diventano regole stabili.
3. **Chiudere**: prima di uscire scrivi **«chiudi sessione»**, poi `/exit`. Claude scrive il diario, aggiorna i lavori, le persone e ciò che ha imparato. Se esci senza chiudere, il giorno dopo te lo segnala e propone di ricostruire il diario.
4. **Decidere**: Claude prepara, tu approvi. Quanto deve chiederti e quanto può fare da solo è una regola del profilo, che cambi quando vuoi.

La guida breve per tutti i giorni è in [docs/guida-cliente.md](docs/guida-cliente.md).

## Abbonamento, quota e login

- Claude Code usa il tuo abbonamento: la quota è una sola per claude.ai e Claude Code, e la consumano anche i giri automatici. `/usage` in Claude Code mostra quanto ne resta.
- Posta e calendario passano dai connettori che attivi su claude.ai (Impostazioni → Connettori). Nei giri automatici Claude li legge e non invia niente.
- Se il login scade, i giri automatici non leggono più posta e calendario e il controllo del mattino lo segnala: apri Claude Code e scrivi `/login`.
- I giri automatici partono solo con il Mac acceso agli orari scelti.

## Aggiornare

Quando esce una versione nuova:
```bash
claude plugin marketplace update metis
claude plugin update metis@metis
```

## Se qualcosa non va

| Che cosa vedi | Che cosa fare |
|---|---|
| `marketplace add` dice «Please make sure you have the correct access rights» | l'invito al repository non è stato accettato, oppure Git non è collegato a GitHub: rifai `gh auth login` e rispondi sì alla domanda su Git |
| All'apertura non compare l'orientamento di Metis | riapri Claude Code dentro la cartella del vault; controlla con `claude plugin list` che il plugin sia attivo |
| Le protezioni sembrano non valere | manca il sì alla finestra di fiducia: riapri Claude Code nella cartella del vault e accettala |
| Il controllo del mattino è giallo o rosso | chiedi a Claude «che cosa dice il doctor?»: legge il report e ti propone il rimedio |
| Claude non vede più posta o calendario | `/login` in Claude Code; poi controlla su claude.ai che i connettori siano attivi |
| L'installazione si è interrotta a metà | scrivi di nuovo «installa Metis» (o «installa <modulo>»): riprende dal primo passo non riuscito |

---

*Per chi installa e mantiene Metis: [docs/procedura-installazione.md](docs/procedura-installazione.md).*
