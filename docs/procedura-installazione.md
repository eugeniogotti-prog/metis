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
   - Telegram sì o no.
   Il repository è pubblico: al cliente non servono un account GitHub né un invito.
2. **Le schede di dominio di partenza**, se sono state preparate per questo cliente (file `<materia>.md.txt`, ripulite da nomi e casi di chi le ha scritte): su una chiavetta o in un file da mandargli.
3. **La versione**: prima di una giornata le prove devono passare (`bash tests/test-installa.sh templates/memoria` e le altre in `tests/`).

### 0. Prerequisiti (dieci minuti)

- **Claude Code** installato (claude.com/claude-code) e collegato al **suo** abbonamento: nel Terminale `claude`, poi `/login` se lo chiede.
- Se nel Terminale è impostata una chiave API di Anthropic, Claude Code fatturerebbe sulla Console invece che sull'abbonamento: il blocco 0 lo controlla.
- `/usage` in Claude Code: annotare quanto resta della quota prima di cominciare.

### A. Il plugin (il cliente al Terminale)

1. Il plugin (nessun login a GitHub: il repository è pubblico):
   ```bash
   claude plugin marketplace add eugeniogotti-prog/metis
   claude plugin install metis@metis
   claude plugin list
   ```
   Atteso: `metis@metis` «enabled». Claude Code tiene una copia propria del plugin: sul Mac non resta nessuna cartella da conservare. Se il primo comando non trova il catalogo, controllare la connessione e il nome `eugeniogotti-prog/metis`.

**Ripiego senza GitHub**: copiare la cartella del plugin sul Mac (per esempio in `~/Metis`) e lasciarla lì; `claude plugin marketplace add ~/Metis` e `claude plugin install metis@metis`. Con un catalogo locale, tolta la cartella d'origine `claude plugin list` dà il plugin «failed to load» (provato il 3/10/2026).

### B. L'avvio

`cd "<cartella del vault>"` e `claude` (se il vault non esiste ancora, si crea prima una cartella vuota, per esempio `~/Documents/Vault`). Il cliente scrive **«installa Metis»**. Da qui conduce Claude; chi installa interviene sulle scelte.

### C. Blocco 0: dotazione e scelte

Claude controlla il Mac (macOS, Claude Code, python3, git, jq, Homebrew, Obsidian) e chiede: dove sta il vault, **dove stanno i documenti di lavoro**: per default insieme alle note, una cartella per lavoro nella struttura del vault (progetti, aree, risorse, archivio), con `_IN/`, `_fonti/` e `_OUT/`; solo chi usa Obsidian e vuole un vault di sole note li tiene in una cartella fuori dal vault (`METIS_DOCUMENTI=separati`). Le cartelle che il cliente ha già non si riordinano all'installazione; posta e calendario, Telegram, voce, Mac acceso di giorno, cartella riservata, cartelle da leggere senza toccare. Se manca un programma, Claude dà il comando e il cliente lo esegue (Homebrew chiede la password del Mac).

### D. Blocco 1: struttura del vault e mappa

- **Vault esistente**: Claude legge l'albero delle cartelle e propone quale fa da ingresso, lavori, aree, risorse, persone, archivio, diario. Il cliente corregge. **Nessuna nota si sposta.**
- **Vault nuovo**: struttura PARA.
- Quattro domande per la mappa e l'archivio, con le risposte già proposte: quali cartelle tenere d'occhio; se fra le cartelle dei lavori c'è un «contenitore» i cui figli sono lavori distinti; archivio per anno o piatto; a fine lavoro la cartella si archivia intera, documenti compresi (con `separati`: cartelle dei documenti ferme, consigliato, o spostate).

### E. Blocco 2: memoria (Obsidian chiuso)

- **Chiudere Obsidian**: si copiano anche i modelli della nota del giorno e della settimana, che Templater potrebbe alterare appena compaiono (da verificare la prima volta).
- Se ci sono le schede di partenza, copiarle prima sul Mac e dare a Claude il percorso: vanno in `dominio/`.
- Claude installa profilo di partenza, stato attuale, regole di metodo, correzioni, decisioni, routine di fine sessione, protocollo di propagazione, `CLAUDE.md`. Se il cliente ha già un suo `CLAUDE.md`, resta com'è e il nucleo di Metis va in `CLAUDE.local.md`.
- Controllo: il doctor ha i tetti in verde; l'avviso «Avvio non fatto» è atteso.

### F. Blocco 3: hook e permessi

Claude installa protezioni e regole: sessioni **senza richieste di permesso** (`bypassPermissions`, decisione del 6/10/2026), con i divieti e la guardia che restano attivi. Poi **il cliente chiude Claude Code, lo riapre nel vault e accetta la finestra che chiede se si fida della cartella**: senza quel sì le regole non valgono. Tre prove: all'apertura compare l'orientamento; una lettura nella cartella riservata viene bloccata; una nota senza intestazione produce un avviso.

### G. Moduli (ciascuno facoltativo: «installa <modulo>»)

- **Posta e calendario.** Google: su claude.ai → Impostazioni → Connettori si attivano Gmail, Calendar e Drive; prova «che cosa ho in calendario domani?»; poi `installa google` mette le routine in sola lettura. Microsoft 365: il connettore di claude.ai, con il consenso di un amministratore dell'IT una volta (testo per l'IT in `skills/installa/references/procedura-m365.md`); poi `installa microsoft`.
- **Documenti Office e PDF**: `installa markitdown`.
- **Consegne in Word**: `installa docx` (serve `brew install pandoc`; facoltativo il modello Word del cliente in `METIS_DOCX_MODELLO`).
- **Telefono**: `installa telegram`. Il cliente crea il bot con @BotFather (Claude lo guida a parole) e incolla il token nel comando che Claude gli indica: il token non compare a schermo e non passa dalla chat. Scrive «ciao» al bot; Claude trova la chat e manda una prova. Se vuole, l'ascoltatore: ciò che manda al bot finisce nell'Inbox e può parlare con Claude. Voce: `installa voce`, con una chiave creata dal cliente su console.groq.com.
- **Giri automatici**: `installa routine`, con gli orari del cliente. Controllo: un briefing di prova scrive la sua riga nella nota del giorno. Costi da dire: Mac acceso agli orari, quota dell'abbonamento.

### H. Avvio dell'onboarding (dieci minuti del cliente)

Dopo i moduli di posta e calendario, il cliente scrive «avvio» (skill `onboarding`). Sei passi, una domanda alla volta con la proposta già scritta:
1. come funziona, in tre righe: Claude prepara e il cliente decide; il gesto «questo non va perché…, d'ora in poi…»; «chiudi sessione» prima di uscire;
2. chi è: nome, mestiere, materie, per chi lavora (per categoria);
3. quanta autonomia: A (procedi, chiedi solo per le scelte irreversibili) o B (chiedi prima di ogni modifica ai miei file);
4. dove stanno i suoi file oggi: non si sposta niente;
5. prova di posta e calendario: «che cosa ho domani?» e la ricerca di una mail;
6. il primo lavoro: cartella e stato minimo.

Il profilo di partenza vale da subito, con le regole marcate `[di partenza]`: il cliente le corregge lavorando, e alla prima sessione del mese decide in un solo elenco quali tenere. Lo stile dai documenti d'esempio, le schede di dominio, le persone e i temi si fanno nell'uso, solo quando servono (decisione del 24/10/2026).

### Prima di andare via

- [ ] avvio fatto e doctor verde, o giallo con motivi noti (di solito: un modulo non ancora installato);
- [ ] plugin attivo (`claude plugin list`);
- [ ] la guida per il cliente, [`guida-cliente.md`](guida-cliente.md), letta insieme;
- [ ] `/usage` a fine giornata;
- [ ] fissata la call di rodaggio a trenta giorni.

### Se qualcosa va storto

| Problema | Che cosa fare |
|---|---|
| Manca Homebrew o un programma | la verifica dà il comando; il cliente lo esegue; si rilancia «installa» |
| Il catalogo su GitHub non si aggiunge | connessione assente o nome del repository scritto male; in alternativa il ripiego senza GitHub (sezione A) |
| La posta aziendale non si collega | si prosegue: testo per l'IT, e intanto le mail utili si salvano a mano |
| L'orientamento non compare | riaprire Claude Code nel vault; controllare che il plugin risulti attivo (`claude plugin list`) |
| Le regole sembrano non valere | manca la finestra di fiducia: riaprire Claude Code nel vault e accettarla |
| Un giro automatico fallisce | la nota del giorno ha la riga «⚠️ metis-agent» con il file di log; il doctor lo segnala il mattino dopo |
| Si rompe qualcosa a metà | ogni blocco si rilancia: «installa <modulo>», oppure «installa» riprende dal primo blocco che non passa |
| Il tempo non basta | si rimandano telefono, voce e giri automatici: memoria, profilo e primo lavoro sono la parte che conta |

## Connettori e protezioni nell'app di Claude

Verificato il 23/10/2026 in una prova con l'app di Claude e Metis installato:

- **Nomi degli strumenti.** Nell'app i connettori di claude.ai si chiamano `mcp__<identificativo>__<azione>` (per esempio `mcp__0a1b2c3d-…__send_message`), con un identificativo che cambia da un account all'altro. In Claude Code al Terminale lo stesso strumento si chiama `mcp__claude_ai_Gmail__send_message`. Una regola di permesso scritta per nome (un `deny` su `mcp__claude_ai_Gmail__send_message`) nell'app quindi **non scatta**. La guardia riconosce l'azione dalla fine del nome (`send_message`, `reply`, `share_file`, `create_event`…) e vale con entrambe le forme. Un divieto o un permesso su un connettore che deve valere anche nell'app va scritto come hook che legge la fine del nome, non come regola per nome.
- **Modalità Auto.** La richiesta di conferma della guardia (`ask`) arriva al cliente come finestra di conferma: se conferma, l'azione parte. È il comportamento voluto: un invio parte solo con il suo via. Per un «mai», invece, serve un hook che risponda `deny`.
- **Routine.** Le regole delle routine (`installa google`, `installa microsoft`) restano per nome: i giri automatici girano in Claude Code (`claude -p`), dove i nomi sono `mcp__claude_ai_…`.

## Aggiornare Metis

Chi mantiene il plugin alza la versione in `.claude-plugin/plugin.json` e pubblica (`git push`). Sul Mac del cliente:
```bash
claude plugin marketplace update metis
claude plugin update metis@metis
```
Poi, in una sessione nel vault, «aggiorna Metis»: `scripts/aggiorna.sh esegui` dalla copia nuova fa una copia di sicurezza (nella cartella della configurazione, `backup/aggiorna-…`) e riallinea al percorso nuovo le regole del vault, quelle dei giri automatici e i LaunchAgent, aggiunge le regole nuove della versione e lancia il doctor. Non tocca profilo, stati, correzioni, schede, `CLAUDE.md` né note; l'onboarding non si rifà. L'orientamento all'avvio segnala l'aggiornamento da fare quando regole e giri puntano a una copia sparita o di un'altra versione.
Con il ripiego locale, prima si copia la versione nuova sopra la cartella del plugin.

## Passare dal Terminale all'app di Claude (tab Code)

Per un cliente che ha Metis installato da Terminale e vuole lavorare dall'app. Passi per il cliente: `docs/guida-app.md`. Che cosa c'è sotto:

- **Un solo plugin, due modi di installarlo.** Lo zip per l'app si fa con `git archive` (manifest alla radice); l'app lo carica da Impostazioni → Plugin come plugin dell'account (catalogo «My Uploads») e lo tiene nella propria cartella dati, `~/Library/Application Support/Claude/local-agent-mode-sessions/<…>/<…>/rpm/plugin_<id>/`: un percorso con uno spazio, per questo le regole degli script esistono anche con il percorso fra virgolette [verificato il 3/11/2026 con la 0.4.3: le skill `metis:` compaiono nel tab Code, `aggiorna.sh` riconosce la copia dell'app]. Se un'altra versione dello zip, ricaricata, resti nello stesso `plugin_<id>` non è provato: se cambia, l'orientamento all'avvio segnala l'aggiornamento da fare.
- **La fiducia.** All'apertura di una cartella nuova il tab Code chiede se fidarsi della cartella [verificato il 3/11]: si risponde sì, altrimenti le regole del vault non valgono.
- **Le sessioni del tab Code leggono le stesse impostazioni del Terminale** (`~/.claude/settings.json`, impostazioni del vault, plugin installati) [documentazione di Claude Code, pagina dei plugin]. Quindi la copia installata da Terminale è attiva anche nel tab Code.
- **Due copie non convivono.** Al caricamento l'app controlla se un plugin installato da Terminale usa gli stessi nomi e, se sì, rifiuta lo zip [dal codice dell'app, non provato]. Con due copie, il tab Code usa quella dell'app e il Terminale quella installata a mano, e gli hook di una delle due non girano [documentazione, «Name conflicts»]. Per questo la copia da Terminale si toglie prima (`claude plugin uninstall metis@metis`, `claude plugin marketplace remove metis`, oppure `aggiorna.sh togli-terminale` dalla copia nuova).
- **Giri automatici.** I LaunchAgent eseguono gli script della copia a cui puntano, e il giro di Claude usa le skill della stessa copia (`metis-agent.sh` passa `--plugin-dir`): non dipendono da quale copia è installata o sincronizzata. Dopo il passaggio puntano alla copia dell'app (`aggiorna.sh esegui`).
- **Terminale dopo il passaggio.** Un plugin caricato sull'account arriva anche alle sessioni del Terminale come `metis@synced`, se il login è quello dell'account claude.ai [documentazione]; che lo zip caricato dall'app passi da lì non è stato provato.
- **La cartella della sessione.** Il tab Code chiede la cartella in cui lavorare: va scelta quella del vault. Se si sceglie una cartella che lo contiene, l'orientamento all'avvio lo dice in una riga e indica quella giusta; da altre cartelle tace.
- **Prova:** `tests/test-aggiorna.sh` costruisce un vault installato con la 0.3.2, con routine e Telegram, e lo aggiorna da una copia messa nella cartella dell'app: contenuto del cliente identico, nessun percorso vecchio, secondo giro senza cambiamenti.

## Metis su un server Linux

Dalla 0.5.0 lo stesso plugin funziona anche su Linux (provato su Ubuntu 24.04 con systemd 255), per chi vuole vault, documenti e giri automatici su un server sempre acceso, e ci entra via SSH.

- **Automatismi.** Al posto dei LaunchAgent, servizi e timer di systemd per l'utente, in `~/.config/systemd/user/` (`scripts/lib/servizi.sh` sceglie da sé; `systemd.sh` è la parte Linux). Un giro saltato per un riavvio parte appena il server torna su; l'ascoltatore di Telegram, se si ferma, viene rilanciato.
- **Linger, una volta sola, da amministratore:** `sudo loginctl enable-linger <utente>`. Senza, systemd ferma gli automatismi quando si chiude l'ultima sessione SSH. Il controllo d'installazione e il doctor lo controllano.
- **Login di Claude:** con l'account dell'abbonamento (`/login`), non con `ANTHROPIC_API_KEY` né con `claude setup-token`, che non carica i connettori di claude.ai. Il file del login (`~/.claude/.credentials.json`) è fra le letture vietate.
- **Fiducia nella cartella del vault:** una volta, `claude` aperto a mano nel vault e la fiducia accettata. Senza, Claude Code ignora le regole del vault (`Ignoring … permissions.allow entries … this workspace has not been trusted`); i giri automatici funzionano lo stesso, perché le loro regole arrivano da `permessi-routine.json`.
- **Connettori:** `google.sh connettori` legge `claude mcp list`. Su Linux senza schermo i connettori funzionano, ma non compaiono nell'evento di avvio della sessione [verificato il 6/11/2026, Claude Code 2.1.318: un giro dal timer ha letto calendario e posta].
- **Programmi:** `sudo apt install python3 jq git curl` più, per i moduli, `pandoc`, `ffmpeg`, `nodejs npm`; `uv` con il suo installatore (`curl -LsSf https://astral.sh/uv/install.sh | sh`). Il controllo d'installazione dà i comandi per ciò che manca.
- **Obsidian non gira sul server.** Claude scrive direttamente sui file e dice quando i collegamenti fra note non sono aggiornati; spostamenti e rinomine con l'aggiornamento dei collegamenti si fanno dal Mac.
- **Un posto solo per automatismi e bot.** Con il vault allineato fra Mac e server, un giro che parte sui due scrive due volte; Telegram ammette un solo ascoltatore per bot. Nel passaggio: sul Mac `routine.sh togli <lavoro>` per ogni giro e `servizi.sh scarica telegram`; si allinea il vault; sul server `installa routine` e, per il bot già esistente, la copia di `telegram` e `telegram-stato.json` (modulo Telegram, «Un solo ascoltatore per bot») e `telegram.sh ascoltatore`.
- **Prova:** `tests/test-linux.sh` (ovunque, con un systemctl finto) e `PROVA_VERA=1 bash tests/test-linux.sh` (su Linux, con il systemd vero: genera, carica, fa partire un giro e l'ascoltatore, poi toglie tutto).

## Che cosa c'è

- `skills/` — installa, onboarding, definizione-obiettivi, impegni, autorevisione, archiviazione, daily-digest, weekly-digest, inbox-processor.
- `hooks/` — orientamento all'avvio, guardia sulle azioni rischiose, controllo delle scritture, salvataggio prima della compattazione.
- `scripts/` — configurazione e ruoli delle cartelle (`lib/config.sh`, `configura.sh`), installazione (`installa-*.sh`, `verifica-dotazione.sh`), `doctor.sh`, `mappa.py`, `archivia.py`, giri automatici (`metis-agent.sh`), moduli (`moduli/`), Telegram e voce, `trascrizione.py`.
- `templates/memoria/` — i modelli copiati nel vault del cliente.
- `docs/guida-cliente.md` — la guida breve per il cliente.
- `tests/` — prove su vault temporanei: `test-passo3.sh` e `test-installa.sh` (con `templates/memoria`), `test-mappa.sh`, `test-telegram.sh`, `test-routine-google.sh`.
