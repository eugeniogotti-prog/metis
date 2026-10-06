# Procedura d'installazione (per chi installa)

La guida per il cliente è il [README](../README.md); qui il dettaglio per chi prepara e guida la giornata, e la struttura del repository.

## Passo per passo

Chi fa che cosa: **chi installa** prepara e guida, **il cliente** usa tastiera e password, **Claude** conduce l'installazione con la skill `installa`, blocco per blocco, e a ogni blocco esegue il controllo di riuscita. Durata: mezza giornata con il profilo e il primo lavoro; i moduli facoltativi si possono rimandare.

### Prima della giornata (chi installa)

1. **Le domande al cliente**, per mail:
   - Mac e versione di macOS; permessi di amministratore;
   - abbonamento Claude (Pro, Max, oppure Team/Enterprise dell'organizzazione: in quel caso i connettori li governa l'amministratore Claude);
   - posta e calendario: Google o Microsoft 365; se Microsoft 365, chi è l'IT che può dare il consenso al connettore;
   - Obsidian sì o no, e se ha già un vault;
   - **5-10 documenti ben fatti** suoi, di tipi diversi, senza dati riservati di terzi (servono al profilo); meglio ancora coppie «bozza → versione mandata»;
   - **un lavoro vivo** da usare come primo lavoro;
   - Telegram sì o no;
   - **il nome utente GitHub** (o crearne uno): serve per l'accesso al repository.
2. **L'accesso al repository**: invitare il cliente in lettura e fargli accettare l'invito.
   ```bash
   gh api -X PUT repos/eugeniogotti-prog/metis/collaborators/<nome-utente> -f permission=pull
   ```
3. **Le schede di dominio di partenza**, se sono state preparate per questo cliente (file `<materia>.md.txt`, ripulite da nomi e casi di chi le ha scritte): su una chiavetta o in un file da mandargli.
4. **La versione**: prima di una giornata le prove devono passare (`bash tests/test-installa.sh templates/memoria` e le altre in `tests/`).

### 0. Prerequisiti (dieci minuti)

- **Claude Code** installato (claude.com/claude-code) e collegato al **suo** abbonamento: nel Terminale `claude`, poi `/login` se lo chiede.
- Se nel Terminale è impostata una chiave API di Anthropic, Claude Code fatturerebbe sulla Console invece che sull'abbonamento: il blocco 0 lo controlla.
- `/usage` in Claude Code: annotare quanto resta della quota prima di cominciare.

### A. Il plugin (il cliente al Terminale)

1. `brew install gh`, poi `gh auth login`: GitHub.com → HTTPS → **sì** alla domanda «Authenticate Git with your GitHub credentials?» → login dal browser. Controllo: `gh auth status`.
2. Il plugin:
   ```bash
   claude plugin marketplace add eugeniogotti-prog/metis
   claude plugin install metis@metis
   claude plugin list
   ```
   Atteso: `metis@metis` «enabled». Claude Code tiene una copia propria del plugin: sul Mac non resta nessuna cartella da conservare. Se il primo comando dice «Please make sure you have the correct access rights», manca l'invito accettato oppure Git non è collegato a GitHub.

**Ripiego senza GitHub**: copiare la cartella del plugin sul Mac (per esempio in `~/Metis`) e lasciarla lì; `claude plugin marketplace add ~/Metis` e `claude plugin install metis@metis`. Con un catalogo locale, tolta la cartella d'origine `claude plugin list` dà il plugin «failed to load» (provato il 3/10/2026).

### B. L'avvio

`cd "<cartella del vault>"` e `claude` (se il vault non esiste ancora, si crea prima una cartella vuota, per esempio `~/Documents/Vault`). Il cliente scrive **«installa Metis»**. Da qui conduce Claude; chi installa interviene sulle scelte.

### C. Blocco 0: dotazione e scelte

Claude controlla il Mac (macOS, Claude Code, python3, git, jq, Homebrew, Obsidian) e chiede: dove sta il vault, **in quale cartella del disco il cliente tiene i documenti di lavoro** (resta quella che usa già, fuori dal vault), posta e calendario, Telegram, voce, Mac acceso di giorno, cartella riservata, cartelle da leggere senza toccare. Se manca un programma, Claude dà il comando e il cliente lo esegue (Homebrew chiede la password del Mac).

### D. Blocco 1: struttura del vault e mappa

- **Vault esistente**: Claude legge l'albero delle cartelle e propone quale fa da ingresso, lavori, aree, risorse, persone, archivio, diario. Il cliente corregge. **Nessuna nota si sposta.**
- **Vault nuovo**: struttura PARA.
- Quattro domande per la mappa e l'archivio, con le risposte già proposte: quali cartelle tenere d'occhio; se nella cartella dei documenti c'è un «contenitore» i cui figli sono lavori distinti; archivio per anno o piatto; cartelle su disco ferme a fine lavoro (consigliato) o spostate.

### E. Blocco 2: memoria (Obsidian chiuso)

- **Chiudere Obsidian**: si copiano anche i modelli della nota del giorno e della settimana, che Templater potrebbe alterare appena compaiono (da verificare la prima volta).
- Se ci sono le schede di partenza, copiarle prima sul Mac e dare a Claude il percorso: vanno in `dominio/`.
- Claude installa profilo di partenza, stato attuale, regole di metodo, correzioni, decisioni, routine di fine sessione, protocollo di propagazione, `CLAUDE.md`. Se il cliente ha già un suo `CLAUDE.md`, resta com'è e il nucleo di Metis va in `CLAUDE.local.md`.
- Controllo: il doctor ha i tetti in verde; l'avviso «Onboarding non finito» è atteso.

### F. Blocco 3: hook e permessi

Claude installa protezioni e regole: sessioni **senza richieste di permesso** (`bypassPermissions`, decisione del 6/10/2026), con i divieti e la guardia che restano attivi. Poi **il cliente chiude Claude Code, lo riapre nel vault e accetta la finestra che chiede se si fida della cartella**: senza quel sì le regole non valgono. Tre prove: all'apertura compare l'orientamento; una lettura nella cartella riservata viene bloccata; una nota senza intestazione produce un avviso.

### G. Profilo (onboarding, fase 1; circa un'ora)

«Riprendi l'onboarding». Claude chiede il consenso a leggere i documenti d'esempio, li legge uno per uno e presenta il **profilo di partenza regola per regola**, dicendo se i documenti la confermano o la contraddicono. Restano solo le regole in cui il cliente si riconosce. Poi le domande che i documenti non risolvono (quanta autonomia, come vuole le risposte), al massimo dodici. Prova finale: Claude scrive un testo breve vero e il cliente lo corregge con il gesto.

### H. Moduli (ciascuno facoltativo: «installa <modulo>»)

- **Posta e calendario.** Google: su claude.ai → Impostazioni → Connettori si attivano Gmail, Calendar e Drive; prova «che cosa ho in calendario domani?»; poi `installa google` mette le routine in sola lettura. Microsoft 365: il connettore di claude.ai, con il consenso di un amministratore dell'IT una volta (testo per l'IT in `skills/installa/references/procedura-m365.md`); poi `installa microsoft`.
- **Documenti Office e PDF**: `installa markitdown`.
- **Telefono**: `installa telegram`. Il cliente crea il bot con @BotFather (Claude lo guida a parole) e incolla il token nel comando che Claude gli indica: il token non compare a schermo e non passa dalla chat. Scrive «ciao» al bot; Claude trova la chat e manda una prova. Se vuole, l'ascoltatore: ciò che manda al bot finisce nell'Inbox e può parlare con Claude. Voce: `installa voce`, con una chiave creata dal cliente su console.groq.com.
- **Giri automatici**: `installa routine`, con gli orari del cliente. Controllo: un briefing di prova scrive la sua riga nella nota del giorno. Costi da dire: Mac acceso agli orari, quota dell'abbonamento.

### I. Primo lavoro (fase 2)

Il cliente sceglie il lavoro vivo. Claude (skill `definizione-obiettivi`) cerca i precedenti (al primo giorno non ce ne sono, e lo dice), scrive lo stato con obiettivo e perché in bozza da correggere, gli impegni, le note delle persone coinvolte, i temi per i tag.

### J. Patto e chiusura (fase 3)

- Il patto: Claude è un **collaboratore junior** che si forma lavorando; quando sbaglia, gli si spiega perché e come migliorare il metodo, senza correggere il file a mano.
- Il cliente corregge un risultato della giornata con il gesto «questo non va perché…, d'ora in poi…»; Claude registra il caso e, se è di stile, la regola nel profilo.
- Il cliente scrive **«chiudi sessione»**: Claude scrive il diario, lo stato dell'installazione e un riepilogo.

### Prima di andare via

- [ ] doctor verde, o giallo con motivi noti (di solito: onboarding da completare);
- [ ] plugin attivo (`claude plugin list`);
- [ ] la guida per il cliente, [`guida-cliente.md`](guida-cliente.md), letta insieme;
- [ ] `/usage` a fine giornata;
- [ ] fissata la call di rodaggio a trenta giorni.

### Se qualcosa va storto

| Problema | Che cosa fare |
|---|---|
| Manca Homebrew o un programma | la verifica dà il comando; il cliente lo esegue; si rilancia «installa» |
| Il catalogo su GitHub non si aggiunge | invito non accettato, oppure Git non collegato: `gh auth login`, sì alla domanda su Git |
| La posta aziendale non si collega | si prosegue: testo per l'IT, e intanto le mail utili si salvano a mano |
| L'orientamento non compare | riaprire Claude Code nel vault; controllare che il plugin risulti attivo (`claude plugin list`) |
| Le regole sembrano non valere | manca la finestra di fiducia: riaprire Claude Code nel vault e accettarla |
| Un giro automatico fallisce | la nota del giorno ha la riga «⚠️ metis-agent» con il file di log; il doctor lo segnala il mattino dopo |
| Si rompe qualcosa a metà | ogni blocco si rilancia: «installa <modulo>», oppure «installa» riprende dal primo blocco che non passa |
| Il tempo non basta | si rimandano telefono, voce e giri automatici: memoria, profilo e primo lavoro sono la parte che conta |

## Aggiornare Metis

Chi mantiene il plugin alza la versione in `.claude-plugin/plugin.json` e pubblica (`git push`). Sul Mac del cliente:
```bash
claude plugin marketplace update metis
claude plugin update metis@metis
```
Poi `bash scripts/installa-permessi.sh` dalla cartella del plugin installato (lo fa Claude su «aggiorna i permessi di Metis»): le regole contengono il percorso del plugin, che cambia a ogni versione. Il doctor avvisa se le regole puntano a una versione vecchia.
Con il ripiego locale, prima si copia la versione nuova sopra la cartella del plugin.

## Che cosa c'è

- `skills/` — installa, onboarding, definizione-obiettivi, impegni, autorevisione, archiviazione, daily-digest, weekly-digest, inbox-processor.
- `hooks/` — orientamento all'avvio, guardia sulle azioni rischiose, controllo delle scritture, salvataggio prima della compattazione.
- `scripts/` — configurazione e ruoli delle cartelle (`lib/config.sh`, `configura.sh`), installazione (`installa-*.sh`, `verifica-dotazione.sh`), `doctor.sh`, `mappa.py`, `archivia.py`, giri automatici (`metis-agent.sh`), moduli (`moduli/`), Telegram e voce, `trascrizione.py`.
- `templates/memoria/` — i modelli copiati nel vault del cliente.
- `docs/guida-cliente.md` — la guida breve per il cliente.
- `tests/` — prove su vault temporanei: `test-passo3.sh` e `test-installa.sh` (con `templates/memoria`), `test-mappa.sh`, `test-telegram.sh`, `test-routine-google.sh`.
