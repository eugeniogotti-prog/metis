# Metis su un server, da zero

Guida per chi installa Metis «gestito» per un cliente. Il cliente non userà mai il terminale: lavora da Telegram, dall'app di Claude e dal telefono. Chi installa entra nel server con la propria chiave, come fornitore.

Ogni passo dice che cosa fare, che cosa si deve vedere e che cosa fare se non va. I passi che richiedono una persona sono segnati 👤. Tutto il resto lo fa `scripts/server/metis-server.sh`, lanciato dal Mac di chi installa.

Provato il 10/11/2026 su un server di prova (Hetzner, Ubuntu 24.04, 2 vCPU, 4 GB) con Claude Code 2.1.322. I punti segnati **[da collaudare]** non sono ancora stati provati su un server nuovo: si verificano nella prima installazione da zero.

La pagina da lasciare al cliente, senza nulla di tecnico, è `docs/server-guida-cliente.md`.

---

## 0. Prima di cominciare

**Che cosa serve:**
- un Mac con la copia di Metis, Comandi rapidi (per firmare la Scorciatoia) e una chiave SSH (`~/.ssh/id_ed25519.pub`);
- il cliente presente, di persona o al telefono, per i passi che toccano i suoi account.

**Chi fa che cosa.** I passaggi umani sono sei; il resto è automatico.

| # | Passo | Chi | Quanto |
|---|---|---|---|
| 1 | Creare il server (§ 1) | installatore, con l'account del cliente | 10 minuti |
| 2 | Login di Claude: aprire un link, autorizzare, incollare il codice (§ 5) | cliente, con il suo abbonamento | 2 minuti |
| 3 | Creare il bot con @BotFather; più tardi, mandargli il codice di abbinamento che lo script mostra (§ 7) | cliente, guidato | 5 minuti |
| 4 | Chiave di Groq (§ 12) | cliente, guidato | 3 minuti |
| 5 | Password di FileBrowser (§ 11) | chi la userà | 1 minuto |
| 6 | Aprire la Scorciatoia sull'iPhone (§ 13) | cliente | 1 minuto |

**Tempo complessivo:** circa un'ora con il cliente, più l'attesa dello script (10-15 minuti, stima non misurata da zero).

### Che cosa chiedere al cliente prima

Le risposte decidono che cosa si installa e che cosa serve dal cliente o dalla sua organizzazione. Si mandano qualche giorno prima, in un messaggio; il cliente può rispondere anche a voce.

| Domanda | Perché serve |
|---|---|
| Chi sei e che lavoro fai; per chi lavori | profilo di partenza (§ 4) e schede di conoscenza del settore |
| Quali caselle di posta usi davvero ogni giorno? Su quale servizio (Google personale, Google Workspace dell'organizzazione, Microsoft 365, altro)? Chi le gestisce? | decide la strada della posta (§ 10). Con una casella dell'organizzazione servono l'amministratore del dominio e il via dell'organizzazione e del suo DPO (§ 16); Microsoft 365 oggi non è supportato sul server |
| Dove tieni il calendario? | stessa scelta della posta (§ 10) |
| Usi WhatsApp per lavoro? Numero personale o Business? Se Business: su quale piattaforma e chi l'ha attivato? | Metis sul server non legge WhatsApp: si dice subito. Per scrivere all'assistente si usa Telegram |
| Hai Telegram? | è il canale principale (§ 7): se non c'è, il cliente lo installa |
| Dove stanno i documenti di lavoro (Drive, OneDrive o SharePoint, un server dell'organizzazione, il computer)? Quanto spazio? Cartelle da escludere? | sincronizzazione (§ 14) e dimensione del server |
| Che computer e che telefono usi (Mac o Windows, iPhone o Android)? | la Scorciatoia per le riunioni (§ 13) è solo per iPhone; con Android le riunioni si mandano da un'app di registrazione che sa condividere un file con un indirizzo web [da progettare] |
| Fai riunioni? In presenza o online, e su quale piattaforma? Ti servirebbe registrarle e ricevere sintesi e cose da fare? | ingresso delle riunioni (§ 12) e regole sulle registrazioni (§ 16) |
| Hai già un account Claude? Con quale piano? | login (§ 5) e costi (§ 17): per la sessione sempre accesa conviene un piano Max |
| A chi intestare server e abbonamento (persona o organizzazione)? Chi paga? | contratti e titolarità dei dati (§ 16) |
| Ci sono dati che non devono stare sul server? | esclusioni nella sincronizzazione e nella cartella riservata |
| Quali sono le tre cose che ti fanno perdere più tempo in una settimana? C'è un lavoro ricorrente che vorresti toglierti di dosso? | i primi giri automatici e la prima dimostrazione costruita sul suo lavoro |

---

## 1. Il server 👤

Su Hetzner Cloud (console.hetzner.com), con un account **intestato al cliente**: il cliente è titolare dei dati e del contratto (§ 16).

1. Progetto nuovo → **Server** → Aggiungi.
2. **Posizione:** UE (Helsinki, Falkenstein o Norimberga).
3. **Immagine:** Ubuntu 24.04.
4. **Tipo:** CPU condivisa, 2 vCPU e 4 GB di RAM (il server di prova era un CPX22). Basta per Claude Code, i giri, FileBrowser e la trascrizione, che si fa da Groq.
5. **Chiave SSH:** quella di chi installa (`cat ~/.ssh/id_ed25519.pub` sul Mac, incollata nella console).
6. **Backup:** attivi (§ 15).
7. Nome: per esempio `metis-<cliente>`.

**Risultato atteso:** un indirizzo IPv4. Dal Mac, `ssh root@<ip> true` esce senza errori.
**Se non va:** «Permission denied (publickey)» vuol dire che la chiave incollata nella console non è quella del Mac. Si ricrea il server con la chiave giusta; su un server nuovo è più rapido che correggere.

---

## 2. Un solo comando dal Mac

```
cd <copia di Metis>
bash scripts/server/metis-server.sh --ip <ip> --admin <tuo utente> --nome-cliente "<Nome Cognome>" --token-bot <file con il token del bot>
```

Lo script, in ordine:
1. prepara il server;
2. prova l'accesso dell'amministratore e chiude root;
3. installa Metis per il cliente;
4. fa partire il login di Claude 👤;
5. chiede quali connettori tenere 👤;
6. chiede la chiave di Groq 👤;
7. mette HTTPS, FileBrowser e l'ingresso delle riunioni, e chiede la password 👤;
8. prepara la Scorciatoia firmata;
9. registra la chat del bot 👤;
10. fa il collaudo.

Ogni passo controlla prima che cosa c'è già: lo script **si può rilanciare** quante volte si vuole, per esempio dopo che il cliente ha mandato al bot il codice di abbinamento.

**Opzioni utili:**
- `--senza-domande`: fa i passi automatici e alla fine elenca i passi umani che mancano;
- `--dominio <nome>`: un nome DNS del cliente al posto di `<ip-con-trattini>.sslip.io`;
- `--utente-web <nome>`: il nome dell'utente di FileBrowser.

**Risultato atteso:** in fondo «✅ Server pronto», oppure l'elenco di ciò che resta da fare.
**Se si interrompe:** si legge l'ultimo ❌, si corregge e si rilancia.

**[da collaudare]** Al 10/11/2026 lo script è stato provato solo a vuoto, su un server già pronto: i passi 1 e 3-10 sono girati senza cambiare niente. La prima esecuzione su un server nuovo, compreso il ramo che lavora come root, si fa nel collaudo da zero.

**Predefiniti:** utente del cliente `metis`; utente di FileBrowser `ospite`; Scorciatoia in `~/Desktop/metis-<nome-del-cliente>/`.

**Dove sono gli script sul server:** lo script li copia in `/tmp` e li cancella dopo l'uso. Restano quelli del plugin installato, in `/home/<cliente>/.claude/plugins/cache/metis/metis/<versione>/scripts/server/`. Qui sotto `<plugin>` sta per `/home/<cliente>/.claude/plugins/cache/metis/metis/<versione>`.

I paragrafi che seguono spiegano ogni passo: servono per capire, per i controlli e per quando qualcosa va storto.

---

## 3. Preparazione del server (`prepara-vps.sh`)

Lo lancia lo script, come root, finché l'amministratore non esiste; dopo, attraverso l'amministratore.

- **Che cosa fa:** pacchetti di sistema; italiano e fuso Europe/Rome; 2 GB di swap.
- **Utenti:**
  - l'amministratore (sudo, solo chiave, senza password);
  - l'utente del cliente, `metis`, senza password né SSH. I suoi servizi girano anche senza nessuno collegato (linger).
- **Sicurezza:** SSH solo con chiave; firewall ufw con la sola 22 in ingresso (80 e 443 si aprono al § 11); fail2ban; aggiornamenti di sicurezza automatici.
- **Programmi:** Node 22 (dal repository NodeSource), rclone; per il cliente Claude Code e uv.

**Controllo:** `sudo bash <plugin>/scripts/server/prepara-vps.sh --controlla` dà tutte righe ✅. L'unico ⚠️ ammesso prima della chiusura di root è «root entra ancora».

**Chiusura di root.** Si fa solo dopo che l'amministratore è entrato davvero: `sudo prepara-vps.sh --chiudi-root`, lanciato *come amministratore*. Che il comando arrivi fin lì dimostra che il suo accesso e il suo sudo funzionano.
**Se si resta chiusi fuori:** la console web del fornitore (Hetzner: «Console» nel pannello del server). Root non ha password: prima la si imposta dal pannello («Reimposta password di root») [da verificare: la console non è stata provata].

**Durante l'installazione** lo script dice a fail2ban di non bloccare l'indirizzo del Mac (`--ip-fidato`) e lo toglie alla fine [da collaudare].

---

## 4. Metis per il cliente (`installa-cliente.sh`)

Gira come utente del cliente. È l'installazione della skill «installa», con le scelte già fatte: vault nuovo in `~/Vault` con la struttura PARA, documenti accanto alle note, sessioni senza richieste di permesso, fiducia nella cartella già data.

**Moduli** (`--moduli`): `markitdown docx telegram routine sessione controllo riunioni`. Google si aggiunge con il cliente (§ 10).

**Risultato atteso:** doctor 🟢, oppure 🟡 con il solo «Avvio non fatto» finché il profilo non è compilato.
**Se non va:** si legge il rapporto del doctor in `~/Vault/_Claude/doctor.md`. Ogni ❌ dice il rimedio; poi si rilancia lo script.

**Profilo e conoscenza di partenza.** Il profilo del cliente (`_Claude/profilo-nucleo.md` e `profilo-completo.md`) si compila con lui, nei dieci minuti dell'onboarding, dall'app o da Telegram. Le schede di conoscenza del suo settore vanno in `_Claude/dominio/`, con le fonti e i flag di verifica, e senza niente che riguardi altri clienti.

---

## 5. Login di Claude 👤

**Due modi, con effetti diversi** (verificato il 10/11/2026):

| | Login completo | Token di un anno |
|---|---|---|
| Comando | `login-claude.sh completo` (`claude auth login`) | `login-claude.sh token` (`claude setup-token`) |
| Remote Control (l'app sul telefono) | sì | **no**: «Remote Control requires a full-scope login token» |
| Connettori di claude.ai (posta, calendario…) | sì | **no** |
| Durata | `loginExpiresAt` dichiara circa un mese. Se si rinnovi da solo con l'uso è [da verificare]: il controllo del § 9 registra ogni giorno la data | un anno secondo la documentazione, non misurato |
| A che cosa serve | la sessione principale e tutto il resto | riserva per giri e bot, se il login completo cade |

**Come si fa:** lo script mostra il link. Il cliente lo apre, entra con il suo account dell'abbonamento e autorizza. La pagina mostra un **codice**: il cliente lo legge e lo si incolla nel terminale. Il codice **non è il token** e vale una volta sola.
- **Se il cliente non è accanto:** gli si manda il link in un messaggio, copiato intero (è lungo, circa 370 caratteri), e lui rimanda il codice. Se passa troppo tempo o il codice non è accettato, si rilancia lo script e si usa il link nuovo.
- **Risultato atteso:** «✅ login completo fatto».
- **Se non va:** si rilancia; con il terminale stretto, si allarga la finestra prima di copiare il link.

**Il token di riserva** lo cattura lo script, che lo salva solo se è intero, e poi verifica che Claude risponda. Non si copia mai a mano dallo schermo: la riga va oltre il bordo e si tronca.

**Precedenza:** se nell'ambiente c'è `CLAUDE_CODE_OAUTH_TOKEN`, Claude usa quello e ignora il login completo, perdendo Remote Control. Metis passa il token solo quando il login completo manca.

**Controllo:** dopo il login lo script riavvia la sessione principale. Nell'app di Claude, sezione Code, compare «Metis di metis» (§ 8).

---

## 6. Connettori dell'account 👤

Con il login completo arrivano sul server **tutti** i connettori dell'account del cliente, anche quelli che il lavoro non prevede (un broker, la musica, i viaggi), e i plugin sincronizzati. La sessione principale lavora senza richieste di permesso e risponde a Telegram: si tengono accesi solo quelli decisi con il cliente.

- `connettori.sh elenca`: l'elenco, con acceso o spento.
- `connettori.sh tieni "Gmail,Google Calendar"`: tiene questi e spegne gli altri; `tieni ""` li spegne tutti.
- `connettori.sh plugin`: disattiva i plugin sincronizzati, tranne Metis.

Valgono dalla sessione successiva: lo script la riavvia. Provato sul server di prova il 10/11/2026: `elenca`, `tieni` con un nome sbagliato (rifiutato, uscita 1), `tieni ""` e `plugin`.
**Risultato atteso:** `elenca` mostra accesi solo quelli decisi.
**Se non va:** un nome rifiutato si copia da `elenca`. Se l'elenco è vuoto, manca il login completo (§ 5).
**Regola:** i connettori che possono muovere soldi o mandare messaggi a nome del cliente restano spenti, salvo una decisione esplicita del cliente.

---

## 7. Bot Telegram 👤

1. Il cliente, su Telegram, scrive a **@BotFather**: `/newbot`, un nome, un nome utente che finisce in `bot`. BotFather risponde con il **token**.
2. Il token va in un file sul Mac (600) e si passa allo script con `--token-bot <file>`. Non passa mai dalla chat né dalla riga di comando: sul server si copia leggendolo dallo standard input, e il file d'appoggio si cancella dopo l'uso.
3. Lo script mostra un **codice di sei cifre**: il cliente lo manda al suo bot dal telefono. Si rilancia lo script: si salva la sola chat che ha mandato il codice e l'ascoltatore si accende. Il codice è la prova che la chat è del cliente: senza, chi scrivesse per primo al bot ne diventerebbe il padrone. [da collaudare: introdotto il 15/11/2026, provato solo con il Telegram finto dei test]

**Risultato atteso:** `bash <plugin>/scripts/moduli/telegram.sh controlla` dà tutte righe ✅, e un messaggio del cliente riceve risposta.
**Se non va:** se la chat non viene trovata, il cliente rimanda il codice (`telegram.sh codice` lo mostra di nuovo) e si rilancia. Se più chat hanno mandato il codice, lo script non ne salva nessuna: qualcun altro conosce il bot, e conviene crearne uno nuovo. Se il token non è valido, BotFather `/token` lo mostra di nuovo.

**Come il cliente porta cose nel vault da Telegram:** inoltra al proprio bot messaggi, link, file, foto e vocali, oppure scrive un testo che comincia con «nota». Finiscono in `0 - Inbox/telegram` (i file in `0 - Inbox/files`) e il giro dell'Inbox li colloca. I «Messaggi salvati» dell'account personale non si usano: leggerli richiede le credenziali API dell'account del cliente, e inoltrare al bot fa la stessa cosa.

**Il bot ascolta e scrive solo alla chat del cliente.** Un solo ascoltatore per bot: lo stesso bot non può girare anche su un altro computer.

**Proprietà del bot:** se l'ha creato il cliente, è suo. Se l'ha creato chi installa, BotFather permette di trasferirlo [da verificare: la procedura di trasferimento di BotFather non è stata provata].

---

## 8. Sessione principale

Una sola sessione di Claude sempre accesa, in tmux (`metis-principale`), con Remote Control. Il cliente la apre dall'app di Claude (sezione Code, «Assistente di <nome del cliente>») e le scrive da Telegram: è la stessa conversazione. Un guardiano systemd la rilancia sulla stessa conversazione se si ferma (provato) o se il server si riavvia [da collaudare]. Nel messaggio d'avvio le è chiesto di affidare i lavori lunghi a sottoagenti e di restare disponibile.

**Controllo:** `sudo -iu <cliente> bash <plugin>/scripts/sessione-principale.sh stato` → ✅; dal telefono, un messaggio al bot riceve risposta.
**Se non va:** registro in `~/.local/state/metis/sessione.log`. Se lo schermo della sessione chiede il login, § 5.
**Per guardarla dal server:** `sudo -iu metis tmux attach -t metis-principale` (si esce con Ctrl-b d, senza chiuderla).

---

## 9. Controllo delle 7:15 e «/accesso»

Ogni mattina alle 7:15 il server controlla:
- il login completo e la sua scadenza;
- un giro vero di Claude;
- il token di riserva;
- la sessione principale e il bot;
- Google, se c'è;
- la sincronizzazione;
- lo spazio sul disco.

Prima ripara da solo quello che si può riparare senza decisioni: riavvia la sessione principale o il bot se sono fermi, rifà la sincronizzazione se è ferma da più di 26 ore. Poi scrive al cliente su Telegram un rendiconto: che cosa ha sistemato e, solo se serve, che cosa resta da fare a lui (per esempio rinnovare un accesso in scadenza entro 7 giorni). Se va tutto bene non scrive. Ogni giorno registra la scadenza del login (`scadenze.log`): così si vede se la data si sposta in avanti da sola.

**Se non va:** ogni ❌ di `controllo-giornaliero.sh --muto` dice il rimedio; il registro è in `~/.local/state/metis/controllo.log`.

**Rinnovo dal telefono:** il cliente scrive **/accesso** al bot e riceve il link di claude.ai. Autorizza e rimanda al bot il codice; il bot completa il login e riavvia la sessione. [Provato con un Claude finto; con il login vero da collaudare.]

---

## 10. Posta e calendario

- **Account Google personale (Gmail):** serve un progetto Google Cloud del cliente con la schermata di consenso **pubblicata «in produzione»**. In «test» l'autorizzazione scade ogni 7 giorni. Poi `google.sh posta`, `credenziali-posta`, `account-posta`: procedura in `skills/installa/references/modulo-google.md`, § 3. Sul server senza schermo `google.sh account-posta` aprirebbe il browser sul server stesso: la via per dare il consenso da un browser sul Mac (inoltro di porta con `ssh -L`, oppure consenso sul Mac e copia dei token) è [da progettare].
- **Google Workspace di un'organizzazione** (indirizzo `@organizzazione.it`): l'app OAuth deve essere di tipo **«Interno»** e creata, o permessa, dall'**amministratore del dominio** dell'organizzazione. Serve anche il via dell'organizzazione sul trattamento dei dati (§ 16).
- **In alternativa, senza Google Cloud:** i connettori di claude.ai (Gmail, Calendar, Drive) con il login completo, accesi al § 6. Non scaricano allegati.
- **Mail nel vault con un'etichetta:** `google.sh etichetta-installa` (Metis 0.6.0); serve la posta locale.
- **Microsoft 365: oggi non supportato sul server.** Esiste il connettore di claude.ai, ma su un server non è stato provato, e per un'organizzazione serve il consenso dell'IT (`skills/installa/references/procedura-m365.md`).

---

## 11. FileBrowser in sola lettura 👤

Il cliente sfoglia e scarica i file del suo vault dal browser, senza poterli modificare: `https://<nome>/`.

**Come è protetto:**
- gira come utente di sistema a parte (`filebrowser`). systemd gli monta il solo vault, in sola lettura, in `/srv/vault`, e gli nasconde `/home`: configurazione, token e chiavi del cliente restano fuori portata;
- l'utente web può solo leggere e scaricare;
- i percorsi nascosti (`.claude`, `.mcp.json`) sono vietati, non solo nascosti;
- certificato HTTPS automatico (Caddy). Se il cliente non ha un nome DNS, si usa `<ip-con-trattini>.sslip.io`.

**Password** 👤: `ssh -t <admin>@<ip>`, poi `sudo filebrowser-password <utente>` (utente predefinito `ospite`).

**Link ai file nelle risposte.** `web.sh` scrive l'indirizzo nella configurazione del cliente (`METIS_WEB_URL`). La sezione «Sul server» del `CLAUDE.md` del vault, scritta da `installa-cliente.sh`, chiede all'assistente di accompagnare ogni file citato con il suo link (`link.py`). I file nascosti non hanno link, perché FileBrowser non li mostra. [Provato in locale; dal telefono da collaudare.] La chiede due volte senza mostrarla, almeno 12 caratteri. Prima di quel momento la password è casuale e nessuno la conosce.

**Controllo:** `sudo bash <plugin>/scripts/server/web.sh --controlla --nome <nome>` dà 8 righe ✅.
**Se non va:** «HTTPS risponde» ❌ nei primi minuti: il certificato arriva al primo accesso, si riprova. FileBrowser fermo: `sudo systemctl reset-failed filebrowser && sudo systemctl start filebrowser`.

---

## 12. Riunioni registrate 👤

L'audio arriva con un POST HTTPS su `https://<nome>/riunione`, con un **segreto per cliente** nell'intestazione. Poi:
1. trascrizione con Groq, a pezzi di 20 minuti;
2. nota nell'Inbox;
3. **l'audio si cancella**;
4. la sessione principale fa la sintesi (partecipanti, decisioni tenute distinte dagli orientamenti, cose da fare, stato del lavoro) e manda il riassunto su Telegram.

Provato il 10/11/2026 con una riunione vera di 47 minuti, registrata con Memo vocali e mandata con Condividi: trascritta per intero. Il tempo fra l'invio e il riassunto non è stato misurato.

**Riunione che non corrisponde a nessun lavoro:** la sessione crea il lavoro adatto (cartella e stato), ci colloca sintesi e trascrizione e lo dice nel riassunto, senza chiedere. Regola aggiunta il 10/11/2026, dopo una riunione rimasta ferma nell'Inbox.

**Chiave di Groq del cliente** 👤:
1. il cliente crea un account su console.groq.com → API Keys → Create;
2. la si incolla con `voce.sh chiave` (lo script lo propone); non si vede a schermo;
3. finisce in `~/.config/metis/groq`, nel formato `KEY=…`.

**Controllo:** `voce.sh controlla` dà «trascrizione riuscita».

**Limiti e risposte del server:**
- 403: segreto sbagliato o mancante;
- 400: invio vuoto, sotto i 4 KB, o arrivato a metà;
- 413: oltre i 400 MB;
- gli invii senza dimensione dichiarata («a pezzi») sono accettati.

**Se il riassunto non arriva:**
1. Registro: `~/.local/state/metis/riunioni.log`. C'è una riga «ricevuta»? E una «lavorata» o «errore»?
2. Un audio rimasto in `~/.local/share/metis/riunioni/` si rilavora con `python3 <plugin>/scripts/server/riunioni.py lavora <file>`.
3. Se l'invio è stato rifiutato, sul server non c'è niente: la registrazione resta in Memo vocali, e si rimanda da lì.

---

## 13. Scorciatoia iPhone 👤

Lo script prepara **«Manda riunione.shortcut»**, già firmata, con indirizzo e segreto dentro (`scorciatoia.py`, `shortcuts sign --mode anyone`, solo su Mac). La lascia in `~/Desktop/metis-<nome-del-cliente>/`. La notifica sull'iPhone mostra la risposta del server: «Ricevuta…», oppure il motivo del rifiuto.

[da collaudare] Una Scorciatoia costruita allo stesso modo e firmata sul Mac ha funzionato il 10/11/2026 con la riunione di 47 minuti. Il file prodotto da `scorciatoia.py`, con la notifica nuova, non è ancora stato aperto su un iPhone.
1. Si manda al cliente con AirDrop, o con una mail a se stesso.
2. Il cliente la apre sull'iPhone e tocca «Aggiungi comando rapido».
3. **Per le riunioni:** si registra con **Memo vocali**, poi Condividi → **Manda riunione**. Quando la sintesi è pronta arriva il riassunto su Telegram. Se Memo vocali continui a registrare a schermo spento per tutta una riunione lunga è [da verificare].

**Risultato atteso:** la notifica «Ricevuta. La trascrivo e ti scrivo su Telegram.»
**Se non va:** la notifica dice il motivo (§ 12); senza notifica, la rete non ha retto: si rimanda da Memo vocali.

**Non registrare dentro la Scorciatoia** (azione «Registra audio»): a schermo spento la registrazione si ferma (verificato). Va bene solo per vocali brevi a schermo acceso.

Il file contiene il segreto: va solo al cliente. Se finisce in mani sbagliate, si cambia il segreto e si rifà la Scorciatoia (§ 18).
Istruzioni per costruirla a mano: `docs/scorciatoia-riunioni.md`.

---

## 14. File di lavoro

- **Cartelle in un cloud** (Google Drive, OneDrive, SharePoint):
  - `sync.sh` con rclone bisync, nei due versi, ogni 5 minuti;
  - versioni locali per 30 giorni, esclusioni dei file temporanei, conflitti risolti a favore del più recente (l'altro file resta accanto);
  - il remoto si crea con il cliente (`rclone config`, con il suo consenso). Il server non ha un browser: l'autorizzazione al cloud si fa su un computer con il browser (`rclone authorize "drive"` sul Mac) e si incolla il risultato in `rclone config` sul server;
  - poi `sync.sh aggiungi <remoto:percorso> <cartella>` e `sync.sh installa`.

  Prova automatica: `tests/test-sync.sh`, con rclone vero su cartelle locali. Con un cloud vero è [da collaudare].
- **Riferimenti del cliente:** `trova-file.py` traduce nel file sul server un percorso del computer del cliente (Mac o Windows) dentro una cartella allineata, un link di OneDrive o SharePoint che contiene il nome del file, un link del FileBrowser, o un nome. I link di Drive con il solo identificativo si risolvono con `rclone lsf` sulle coppie di Drive [da collaudare con un Drive vero]. Le coppie cloud ↔ server sono quelle di `sync.sh`.
  **Se non va:** `sync.sh controlla` e il registro `~/.local/state/metis/sync.log`.
- **Cartelle solo sul computer del cliente:** Syncthing fra il computer e il server [da progettare].
- **Variante «le cartelle del cliente restano dove sono»:** il vault non sposta i documenti del cliente; le note di Claude vanno in sottocartelle `note`, accanto ai documenti [da progettare].

---

## 15. Backup

- **Istantanee del fornitore:** Hetzner tiene 7 backup giornalieri del server intero (attivati al § 1). Servono a rimettere in piedi il server, non a recuperare un singolo file di ieri.
- **Copia dei dati altrove**, cifrata, intestata al cliente: vault e configurazione, per esempio con restic su uno spazio di archiviazione del cliente [da progettare con il primo cliente: oggi non c'è uno script].
- Il vault resta anche nel cloud del cliente, se è sincronizzato (§ 14).

---

## 16. Dati e regole

- **Intestazione:** server e abbonamento Claude sono intestati al cliente, che è titolare dei dati e dei contratti.
- **Chi installa** entra con la propria chiave, come fornitore. Va nominato **responsabile del trattamento** con un atto scritto (modello da preparare a parte).
- **Casella o dati di un'organizzazione** (non del cliente come persona): serve il via dell'organizzazione e del suo DPO, prima di collegarli.
- **Registrazioni delle riunioni:** si dice ai presenti che si registra per il verbale. L'audio si cancella dopo la trascrizione; la trascrizione e la sintesi restano nel vault del cliente.
- **Fornitori esterni da dichiarare al cliente:**

| Fornitore | Che cosa riceve | Dove |
|---|---|---|
| Anthropic | il contenuto delle conversazioni e dei giri | USA |
| Groq | l'audio da trascrivere | USA |
| Telegram | i messaggi del bot | — |
| Hetzner | il server, il disco, i backup | UE |

---

## 17. Costi per il cliente

| Voce | Costo | Note |
|---|---|---|
| Server (Hetzner, 2 vCPU, 4 GB, UE) | da verificare nella console al momento della creazione | le pagine pubbliche danno solo prezzi «a partire da» (5,49-5,99 €/mese IVA esclusa per le categorie più piccole), rilevato il 10/11/2026 |
| Backup Hetzner | da verificare nella console | in percentuale sul prezzo del server [da verificare] |
| Abbonamento Claude | Pro 20 $/mese (17 $ con pagamento annuale); Max 100 $/mese; 200 $/mese il piano più alto | claude.com/pricing, rilevato il 10/11/2026. Per una sessione sempre accesa con giri ogni giorno conviene un piano Max: con Pro i limiti d'uso si raggiungono prima [inferito, non misurato] |
| Groq (trascrizione) | whisper-large-v3: 0,111 $ per ora di audio nel piano a pagamento | console.groq.com/docs/speech-to-text, rilevato il 10/11/2026. Minimo fatturato 10 secondi per richiesta; file fino a 25 MB nel piano gratuito (lo script manda pezzi da circa 5 MB). I limiti del piano gratuito (ore di audio al giorno) sono [da verificare] |
| Nome DNS | 0 con sslip.io; un dominio del cliente costa a parte | — |

---

## 18. Uscita del cliente

- **Passare l'amministrazione e togliere l'accesso a chi installa.** SSH ammette solo gli utenti scritti nella riga `AllowUsers` di `/etc/ssh/sshd_config.d/10-metis.conf`: cancellare l'unico amministratore chiude fuori tutti. In ordine:
  1. il nuovo amministratore si aggiunge con `sudo bash <plugin>/scripts/server/prepara-vps.sh --admin <nuovo> --chiave <sua chiave .pub>`, che lo aggiunge anche ad `AllowUsers`;
  2. si verifica che entri e abbia sudo;
  3. si toglie il vecchio: `sudo deluser --remove-home <vecchio>`, `sudo rm /etc/sudoers.d/90-metis-<vecchio>`, il suo nome dalla riga `AllowUsers`, poi `sudo sshd -t && sudo systemctl reload ssh`.

  Il ripiego è la console del fornitore (§ 3) [da verificare].
- **Portarsi via tutto:** il vault è una cartella di file di testo. `~/Vault` si scarica intero (per esempio `tar czf vault.tgz Vault`), oppure è già nel cloud del cliente se sincronizzato. Si aggiunge `~/.config/metis` solo se servono le impostazioni.
- **Chiudere i servizi esterni:**
  - revocare il login di Claude (claude.ai → Impostazioni);
  - revocare la chiave di Groq (console.groq.com);
  - per il bot: @BotFather → `/revoke` o `/deletebot`;
  - cambiare il segreto delle riunioni: cancellare `~/.config/metis/riunioni-segreto`, poi `riunioni.py segreto`. Il ricevitore lo rilegge a ogni invio, senza riavvio. Poi si rifà e si rimanda la Scorciatoia (§ 13).
- **Spegnere il server:** dalla console del fornitore, prima con un'istantanea finale se serve, poi Elimina. La fatturazione si ferma con l'eliminazione, non con lo spegnimento [da verificare sulle condizioni del fornitore].

---

## 19. Collaudo finale dal telefono

- [ ] Telegram: «che cosa ho in scadenza questa settimana?» → risposta dal vault.
- [ ] Telegram: un link mandato al bot → «Salvato nell'Inbox».
- [ ] App di Claude, sezione Code: «Metis di metis» si apre e risponde.
- [ ] Riunione di prova di un minuto con Memo vocali → Condividi → Manda riunione → riassunto su Telegram.
- [ ] FileBrowser: login, si vede il vault, non si può modificare niente.
- [ ] Doctor 🟢 (`_Claude/doctor.md`).
- [ ] `controllo-giornaliero.sh --muto`: tutte righe ✅.
- [ ] Il mattino dopo: briefing nella nota del giorno, nessun avviso del controllo (o un avviso giusto).
- [ ] Riavvio del server (`sudo reboot`): dopo qualche minuto la sessione è di nuovo nell'app e il bot risponde.

---

## 20. Trappole note

Una per riga, con la soluzione. Tutte incontrate il 10/11/2026.

| Trappola | Soluzione |
|---|---|
| In `ssh … 'sudo -iu metis bash ~/x.sh'` la `~` diventa la home dell'amministratore | percorsi assoluti: `/home/<cliente>/…` |
| Un comando interattivo (login, password, chiavi) via ssh non mostra il prompt | `ssh -t` |
| Incollato il codice di autorizzazione al posto del token di `setup-token` (riga con un `#`) | il token comincia con `sk-ant-oat01-`: lo cattura `login-claude.sh token` |
| Token copiato a mano e troncato | mai a mano: `login-claude.sh token` lo salva solo se è intero |
| Con il token di `setup-token` Remote Control non parte | serve il login completo (`login-claude.sh completo`) |
| `CLAUDE_CODE_OAUTH_TOKEN` nell'ambiente scavalca il login completo | Metis lo passa solo se il login completo manca; per controllare: `/proc/<pid>/environ` del processo di Claude |
| Una sessione ripresa sembra ripetere un errore vecchio (per esempio «serve il login») | probabilmente è il ricordo della conversazione, non un controllo nuovo: si riprova da capo |
| Cancellato l'unico amministratore, nessuno entra più in SSH (riga `AllowUsers`) | prima il nuovo amministratore con `prepara-vps.sh --admin`, poi si toglie il vecchio (§ 18) |
| Una riunione senza un lavoro corrispondente restava ferma nell'Inbox | la sessione ora crea il lavoro adatto e lo dice nel riassunto (§ 12) |
| Il login completo porta sul server tutti i connettori e i plugin dell'account | `connettori.sh tieni …` e `connettori.sh plugin` |
| `voce.sh chiave` scrive nel file indicato da `METIS_GROQ_FILE`, non in `~/.config/metis/groq` | niente `METIS_GROQ_FILE` sui server: la chiave sta nel posto predefinito |
| File della chiave con `KEY=…` contro chiave nuda | Metis legge tutte e due le forme (dal 10/11/2026) |
| Prove di accesso come root dopo la chiusura → fail2ban blocca l'indirizzo per un'ora | lo script non prova root se l'amministratore entra; durante l'installazione `--ip-fidato` |
| Rinominare un server già configurato spegne l'indirizzo vecchio | `web.sh` lo rifiuta senza `--cambia-nome` |
| Un invio di audio senza `Content-Length` (a pezzi) veniva rifiutato con 413 | il ricevitore accetta gli invii a pezzi |
| Due invii nello stesso secondo avevano lo stesso nome di file | nomi con un suffisso casuale |
| Un invio quasi vuoto passava e generava un messaggio d'errore al cliente | soglia minima di 4 KB |
| FileBrowser fermo dopo molti riavvii ravvicinati (`start-limit-hit`) | `StartLimitIntervalSec=0` e `systemctl reset-failed` |
| `--hideDotfiles` di FileBrowser nasconde ma non vieta | regola che vieta i percorsi con un punto |
| Le ACL per far leggere il vault esponevano l'elenco della home | montaggio in sola lettura del solo vault (`BindReadOnlyPaths`, `ProtectHome=tmpfs`) |
| `script` senza `-f` non scrive il registro finché il comando non esce | `script -q -f` |
| Riavviando il servizio, systemd chiudeva anche tmux e la sessione | `KillMode=process` nei servizi sempre accesi |
| «Registra audio» nella Scorciatoia si ferma a schermo spento | Memo vocali + Condividi |
| Giorni della settimana sbagliati nei contenuti scritti a mano | si controllano con un calendario; la sessione se ne accorge e lo dice |
| Sul Mac, bash 3.2: un array vuoto con `set -u` dà errore; `case` dentro `$( )` non si chiude | `${A[@]+"${A[@]}"}`; `case … in (x) …` |
| Una variabile seguita da «»» in bash (`$NOME»`) | `${NOME}»` |
| Una prova con `curl -H 'Transfer-Encoding: chunked'` su HTTPS (HTTP/2) manda dati diversi | è un effetto di curl, non dell'iPhone; per provare gli invii a pezzi si usa HTTP/1.1 in locale |

---

## 21. Manutenzione

**Principio (decisione del 10/11/2026): il vault si ripara da solo e il cliente riceve un rendiconto, non una domanda.** Gli si chiede solo ciò che è davvero suo: scelte di merito, invii a terzi, spese, cancellazioni definitive.
- **Alle 6:45** il doctor trova ciò che è fuori posto.
- **Alle 6:55** il giro «manutenzione» (skill `manutenzione`) lo ripara: note ferme nell'Inbox, intestazioni incomplete, impegni malformati, attese decadute, trascrizioni senza un lavoro (crea il lavoro adatto), file sciolti, cartelle di lavoro incomplete. Scrive il rendiconto nella nota del giorno e, se ha sistemato qualcosa o c'è da decidere, su Telegram.
- **Alle 7:15** il controllo del server ripara servizi e sincronizzazione (§ 9).

[da collaudare] Il giro «manutenzione» è scritto il 10/11/2026 e non ha ancora girato su un vault vero.

- **Aggiornare Metis:**
  - come cliente: `claude plugin marketplace update metis` e `claude plugin update metis@metis`;
  - poi, come amministratore, rilanciare `metis-server.sh`, che rigenera servizi e timer sulla copia nuova;
  - infine riavviare la sessione principale.

  [Da collaudare con il primo aggiornamento.]
- **Rinnovi:**
  - login completo: dal telefono con /accesso, avvisato 7 giorni prima;
  - token di riserva: ogni anno;
  - chiave di Groq: senza scadenza, si revoca all'uscita;
  - certificato HTTPS: automatico.
- **Controlli dell'installatore:** il controllo delle 7:15 scrive al cliente. Chi assiste guarda di tanto in tanto `~/.local/state/metis/controllo.log` e `scadenze.log`.
