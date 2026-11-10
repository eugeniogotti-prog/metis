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
| 3 | Creare il bot con @BotFather e scrivergli «ciao» (§ 7) | cliente, guidato | 5 minuti |
| 4 | Chiave di Groq (§ 12) | cliente, guidato | 3 minuti |
| 5 | Password di FileBrowser (§ 11) | chi la userà | 1 minuto |
| 6 | Aprire la Scorciatoia sull'iPhone (§ 13) | cliente | 1 minuto |

**Tempo complessivo:** circa un'ora con il cliente, più l'attesa dello script (10-15 minuti, stima non misurata da zero).

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

Ogni passo controlla prima che cosa c'è già: lo script **si può rilanciare** quante volte si vuole, per esempio dopo il «ciao» del cliente al bot.

**Opzioni utili:**
- `--senza-domande`: fa i passi automatici e alla fine elenca i passi umani che mancano;
- `--dominio <nome>`: un nome DNS del cliente al posto di `<ip-con-trattini>.sslip.io`;
- `--utente-web <nome>`: il nome dell'utente di FileBrowser.

**Risultato atteso:** in fondo «✅ Server pronto», oppure l'elenco di ciò che resta da fare.
**Se si interrompe:** si legge l'ultimo ❌, si corregge e si rilancia.

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

**Controllo:** `sudo bash prepara-vps.sh --controlla` dà tutte righe ✅. L'unico ⚠️ ammesso prima del passo 4 è «root entra ancora».

**Chiusura di root.** Si fa solo dopo che l'amministratore è entrato davvero: `sudo prepara-vps.sh --chiudi-root`, lanciato *come amministratore*. Che il comando arrivi fin lì dimostra che il suo accesso e il suo sudo funzionano.
**Se root resta chiuso fuori per errore:** la console web del fornitore (Hetzner: «Console» nel pannello del server) entra sempre.

**Durante l'installazione** lo script dice a fail2ban di non bloccare l'indirizzo del Mac (`--ip-fidato`) e lo toglie alla fine [da collaudare].

---

## 4. Metis per il cliente (`installa-cliente.sh`)

Gira come utente del cliente. È l'installazione della skill «installa», con le scelte già fatte: vault nuovo in `~/Vault` con la struttura PARA, documenti accanto alle note, sessioni senza richieste di permesso, fiducia nella cartella già data.

**Moduli** (`--moduli`): `markitdown docx telegram routine sessione controllo riunioni`. Google si aggiunge con il cliente (§ 10).

**Risultato atteso:** doctor 🟢, oppure 🟡 con il solo «Avvio non fatto» finché il profilo non è compilato.

**Profilo e conoscenza di partenza.** Il profilo del cliente (`_Claude/profilo-nucleo.md` e `profilo-completo.md`) si compila con lui, nei dieci minuti dell'onboarding, dall'app o da Telegram. Le schede di conoscenza del suo settore vanno in `_Claude/dominio/`, con le fonti e i flag di verifica, e senza niente che riguardi altri clienti.

---

## 5. Login di Claude 👤

**Due modi, con effetti diversi** (verificato il 10/11/2026):

| | Login completo | Token di un anno |
|---|---|---|
| Comando | `login-claude.sh completo` (`claude auth login`) | `login-claude.sh token` (`claude setup-token`) |
| Remote Control (l'app sul telefono) | sì | **no**: «Remote Control requires a full-scope login token» |
| Connettori di claude.ai (posta, calendario…) | sì | **no** |
| Durata | `loginExpiresAt` a circa un mese; Claude Code lo rinnova da solo con l'uso [da verificare: lo registra ogni giorno il controllo del § 9] | un anno |
| A che cosa serve | la sessione principale e tutto il resto | riserva per giri e bot, se il login completo cade |

**Come si fa:** lo script mostra il link. Il cliente lo apre, entra con il suo account dell'abbonamento e autorizza. La pagina mostra un **codice**: il cliente lo legge e lo si incolla nel terminale. Il codice **non è il token** e vale una volta sola.

**Il token di riserva** lo cattura lo script, che lo salva solo se è intero, e poi verifica che Claude risponda. Non si copia mai a mano dallo schermo: la riga va oltre il bordo e si tronca.

**Precedenza:** se nell'ambiente c'è `CLAUDE_CODE_OAUTH_TOKEN`, Claude usa quello e ignora il login completo, perdendo Remote Control. Metis passa il token solo quando il login completo manca.

**Controllo:** dopo il login lo script riavvia la sessione principale. Nell'app di Claude, sezione Code, compare «Metis di metis» (§ 8).

---

## 6. Connettori dell'account 👤

Con il login completo arrivano sul server **tutti** i connettori dell'account del cliente, anche quelli che il lavoro non prevede (un broker, la musica, i viaggi), e i plugin sincronizzati. La sessione principale lavora senza richieste di permesso e risponde a Telegram: si tengono accesi solo quelli decisi con il cliente.

- `connettori.sh elenca`: l'elenco, con acceso o spento.
- `connettori.sh tieni "Gmail,Google Calendar"`: tiene questi e spegne gli altri; `tieni ""` li spegne tutti.
- `connettori.sh plugin`: disattiva i plugin sincronizzati, tranne Metis.

Valgono dalla sessione successiva: lo script la riavvia.
**Regola:** i connettori che possono muovere soldi o mandare messaggi a nome del cliente restano spenti, salvo una decisione esplicita del cliente.

---

## 7. Bot Telegram 👤

1. Il cliente, su Telegram, scrive a **@BotFather**: `/newbot`, un nome, un nome utente che finisce in `bot`. BotFather risponde con il **token**.
2. Il token va in un file sul Mac (600) e si passa allo script con `--token-bot <file>`. Non passa mai dalla chat né dalla riga di comando: sul server si copia leggendolo dallo standard input, e il file d'appoggio si cancella dopo l'uso.
3. Il cliente scrive **«ciao»** al suo bot. Si rilancia lo script: la chat viene salvata e l'ascoltatore si accende.

**Il bot ascolta e scrive solo alla chat del cliente.** Un solo ascoltatore per bot: lo stesso bot non può girare anche su un altro computer.

**Proprietà del bot:** se l'ha creato il cliente, è suo. Se l'ha creato chi installa, BotFather permette di trasferirlo [da verificare: la procedura di trasferimento di BotFather non è stata provata].

---

## 8. Sessione principale

Una sola sessione di Claude sempre accesa, in tmux (`metis-principale`), con Remote Control. Il cliente la apre dall'app di Claude (sezione Code, «Metis di metis») e le scrive da Telegram: è la stessa conversazione. Un guardiano systemd la rilancia sulla stessa conversazione se si ferma o se il server si riavvia. I lavori lunghi li affida a sottoagenti e intanto resta disponibile.

**Controllo:** `sessione-principale.sh stato` → ✅; dal telefono, un messaggio al bot riceve risposta.
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

Se qualcosa non va, o un accesso scade entro 7 giorni, scrive al cliente su Telegram con il rimedio. Se va tutto bene non scrive. Ogni giorno registra la scadenza del login (`scadenze.log`): così si vede se la data si sposta in avanti da sola.

**Rinnovo dal telefono:** il cliente scrive **/accesso** al bot e riceve il link di claude.ai. Autorizza e rimanda al bot il codice; il bot completa il login e riavvia la sessione. [Provato con un Claude finto; con il login vero da collaudare.]

---

## 10. Posta e calendario

- **Account Google personale (Gmail):** serve un progetto Google Cloud del cliente con la schermata di consenso **pubblicata «in produzione»**. In «test» l'autorizzazione scade ogni 7 giorni. Poi `google.sh posta`, `credenziali-posta`, `account-posta`: procedura in `skills/installa/references/modulo-google.md`, § 3. Sul server il consenso si dà da un browser sul Mac [da collaudare sul server].
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

**Password** 👤: `ssh -t <admin>@<ip>`, poi `sudo filebrowser-password <utente>`. La chiede due volte senza mostrarla, almeno 12 caratteri. Prima di quel momento la password è casuale e nessuno la conosce.

**Controllo:** `sudo bash web.sh --controlla --nome <nome>` dà 8 righe ✅.

---

## 12. Riunioni registrate 👤

L'audio arriva con un POST HTTPS su `https://<nome>/riunione`, con un **segreto per cliente** nell'intestazione. Poi:
1. trascrizione con Groq, a pezzi di 20 minuti;
2. nota nell'Inbox;
3. **l'audio si cancella**;
4. la sessione principale fa la sintesi (partecipanti, decisioni tenute distinte dagli orientamenti, cose da fare, stato del lavoro) e manda il riassunto su Telegram.

Provato il 10/11/2026 con una riunione di 47 minuti.

**Chiave di Groq del cliente** 👤:
1. il cliente crea un account su console.groq.com → API Keys → Create;
2. la si incolla con `voce.sh chiave` (lo script lo propone); non si vede a schermo;
3. finisce in `~/.config/metis/groq`, nel formato `KEY=…`.

**Controllo:** `voce.sh controlla` dà «trascrizione riuscita».

**Limiti:**
- sotto i 4 KB l'invio è rifiutato, perché non è una registrazione;
- sopra i 400 MB è rifiutato;
- gli invii senza dimensione dichiarata («a pezzi») sono accettati.

---

## 13. Scorciatoia iPhone 👤

Lo script prepara **«Manda riunione.shortcut»**, già firmata, con indirizzo e segreto dentro (`scorciatoia.py`, `shortcuts sign --mode anyone`, solo su Mac). La lascia in `~/Desktop/metis-<cliente>/`.
1. Si manda al cliente con AirDrop, o con una mail a se stesso.
2. Il cliente la apre sull'iPhone e tocca «Aggiungi comando rapido».
3. **Per le riunioni:** si registra con **Memo vocali**, poi Condividi → **Manda riunione**. Entro qualche minuto arriva il riassunto su Telegram.

**Non registrare dentro la Scorciatoia** (azione «Registra audio»): a schermo spento la registrazione si ferma (verificato). Va bene solo per vocali brevi a schermo acceso.

Il file contiene il segreto: va solo al cliente. Se si perde o va rifatto, si cambia il segreto (§ 18).
Istruzioni per costruirla a mano: `docs/scorciatoia-riunioni.md`.

---

## 14. File di lavoro

- **Cartelle in un cloud** (Google Drive, OneDrive, SharePoint):
  - `sync.sh` con rclone bisync, nei due versi, ogni 5 minuti;
  - versioni locali per 30 giorni, esclusioni dei file temporanei, conflitti risolti a favore del più recente (l'altro file resta accanto);
  - il remoto si crea con il cliente (`rclone config`, con il suo consenso), poi `sync.sh aggiungi <remoto:percorso> <cartella>` e `sync.sh installa`.

  Prova automatica: `tests/test-sync.sh`.
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
| Groq (trascrizione) | whisper-large-v3: 0,111 $ per ora di audio | console.groq.com/docs/speech-to-text, rilevato il 10/11/2026. Minimo fatturato 10 secondi per richiesta; file fino a 25 MB nel piano gratuito, che basta perché lo script manda pezzi da circa 5 MB |
| Nome DNS | 0 con sslip.io; un dominio del cliente costa a parte | — |

---

## 18. Uscita del cliente

- **Togliere l'accesso a chi installa:** il cliente, o un altro tecnico, toglie la chiave dell'amministratore (`/home/<admin>/.ssh/authorized_keys`) e il suo utente (`sudo deluser --remove-home <admin>`), dopo aver dato l'accesso a qualcun altro. Dalla console del fornitore si entra sempre.
- **Portarsi via tutto:** il vault è una cartella di file di testo. `~/Vault` si scarica intero (per esempio `tar czf vault.tgz Vault`), oppure è già nel cloud del cliente se sincronizzato. Si aggiunge `~/.config/metis` solo se servono le impostazioni.
- **Chiudere i servizi esterni:**
  - revocare il login di Claude (claude.ai → Impostazioni);
  - revocare la chiave di Groq (console.groq.com);
  - per il bot: @BotFather → `/revoke` o `/deletebot`;
  - cambiare il segreto delle riunioni: cancellare `~/.config/metis/riunioni-segreto`, poi `riunioni.py segreto` e riavviare il servizio.
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
| Una sessione ripresa ripete un errore vecchio (per esempio «serve il login») | è il ricordo della conversazione: si riprova da capo |
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
