# Riunioni registrate dal telefono: la Scorciatoia per iPhone

Il cliente registra una riunione con l'iPhone e, con un tocco, la manda al suo server. Dopo qualche minuto riceve su Telegram il riassunto, con decisioni e cose da fare, e trova la nota nel vault. L'audio viene cancellato dal server dopo la trascrizione.

Sul server servono `web.sh` (HTTPS) e il modulo `riunioni` di `installa-cliente.sh` (`scripts/server/riunioni.py`).

## Che cosa serve sapere prima

- **Indirizzo:** `https://<nome del server>/riunione`.
- **Segreto:** lo stampa `python3 <plugin>/scripts/server/riunioni.py segreto`, eseguito come utente del cliente. Si incolla solo nella Scorciatoia: chi lo conosce può mandare audio al server, ma non leggere niente.

## Due modi, e quale scegliere

1. **Memo vocali, poi Condividi: è il modo per le riunioni, sempre.** Si registra con l'app Memo vocali, che continua anche a schermo spento. Alla fine si tocca Condividi e si sceglie «Manda riunione». La registrazione resta anche sul telefono.
2. **Tutto nella Scorciatoia: solo per vocali brevi, a schermo acceso.** Un tocco sul tasto Azione o sul widget della schermata di blocco avvia la registrazione; un secondo tocco la ferma e la manda. **A schermo spento la registrazione si ferma** (verificato il 10/11/2026 su iPhone): per una riunione non va usato.

## Creare la Scorciatoia «Manda riunione» (modo 1)

**Il modo più semplice: farla già pronta dal Mac.** Chi assiste il cliente lancia, sul suo Mac:
`python3 <plugin>/scripts/server/scorciatoia.py --url https://<nome del server>/riunione --segreto <file con il segreto>`
Lo script crea la Scorciatoia con indirizzo e segreto già dentro, la firma con `shortcuts sign --mode anyone` e la lascia sulla Scrivania. Si manda al cliente via AirDrop o con una mail a se stesso: un tocco sull'iPhone e la Scorciatoia è installata. Il file contiene il segreto: va mandato solo al cliente. Provato il 10/11/2026 con una riunione vera di 47 minuti.

Altrimenti, a mano:

App **Comandi rapidi** → **+** → nome **Manda riunione**.
1. Tocca **ⓘ** (dettagli) e attiva **Mostra nel foglio di condivisione**. Come tipo accettato lascia solo **File multimediali**, oppure **Audio** se compare.
2. Aggiungi l'azione **Ottieni contenuto dell'URL**:
   - URL: `https://<nome del server>/riunione`
   - Metodo: **POST**
   - Intestazioni: `X-Metis-Segreto` = *il segreto*; facoltativa `X-Titolo` = *un titolo breve* (oppure la variabile «Chiedi ogni volta»)
   - Corpo della richiesta: **File** → *Input della scorciatoia*
3. Aggiungi **Mostra notifica** con il *Contenuto dell'URL*: comparirà «Ricevuta. La trascrivo e ti scrivo su Telegram.»

Prova: registra dieci secondi con Memo vocali, Condividi → **Manda riunione**. Entro un paio di minuti arriva il messaggio su Telegram.

## Creare la Scorciatoia «Registra vocale» (modo 2, solo vocali brevi a schermo acceso)

App **Comandi rapidi** → **+** → nome **Registra vocale**.
1. **Registra audio**: Qualità *Normale*; Avvio *Immediatamente*; Fine *Al tocco*.
2. **Ottieni contenuto dell'URL**, come sopra, con il corpo **File** → *Audio registrato*.
3. **Mostra notifica** con il *Contenuto dell'URL*.

Poi: Impostazioni → **Tasto Azione** → Comando rapido → *Registra vocale* (iPhone 15 Pro e successivi). Su altri modelli: un widget Comandi rapidi nella schermata di blocco, oppure **Indietro tocco** (Impostazioni → Accessibilità → Tocco).

## Che cosa succede sul server

- Il segreto viene controllato. Il limite è 400 MB, cioè molte ore di registrazione.
- L'audio è convertito e trascritto con Groq, a pezzi di 20 minuti.
- La trascrizione diventa una nota nell'Inbox e l'audio si cancella.
- La sessione principale la lavora come una riunione: partecipanti, decisioni tenute distinte dagli orientamenti, cose da fare, stato del lavoro aggiornato. Poi manda il riassunto su Telegram.
- Se qualcosa va storto, il cliente riceve una riga su Telegram e l'audio resta sul server per il recupero: `riunioni.py lavora <file>`.

## Da verificare alla prima prova vera

- Quanto tempo concede iOS a «Ottieni contenuto dell'URL» per un file grande su rete cellulare. Per un'ora di riunione, in AAC qualità normale, il file è attorno ai 30-60 MB.
- Il modo 1 con una riunione vera e lunga (Memo vocali a schermo spento, poi Condividi).

Già verificato il 10/11/2026 su iPhone: il modo 2 funziona da capo a fondo a schermo acceso (riassunto arrivato su Telegram) e si ferma a schermo spento.
