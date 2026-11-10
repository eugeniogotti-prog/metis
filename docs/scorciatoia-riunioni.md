# Riunioni registrate dal telefono: la Scorciatoia per iPhone

Il cliente registra una riunione con l'iPhone e, con un tocco, la manda al suo server. Dopo qualche minuto riceve su Telegram il riassunto, con decisioni e cose da fare, e trova la nota nel vault. L'audio viene cancellato dal server dopo la trascrizione.

Sul server servono `web.sh` (HTTPS) e il modulo `riunioni` di `installa-cliente.sh` (`scripts/server/riunioni.py`).

## Che cosa serve sapere prima

- **Indirizzo:** `https://<nome del server>/riunione`.
- **Segreto:** lo stampa `python3 <plugin>/scripts/server/riunioni.py segreto`, eseguito come utente del cliente. Si incolla solo nella Scorciatoia: chi lo conosce può mandare audio al server, ma non leggere niente.

## Due modi, e quale scegliere

1. **Memo vocali, poi Condividi** (consigliato per le riunioni lunghe). Si registra con l'app Memo vocali, che continua anche a schermo bloccato. Alla fine si tocca Condividi e si sceglie «Manda riunione». La registrazione resta anche sul telefono.
2. **Tutto nella Scorciatoia** (per le riunioni brevi). Un tocco sul tasto Azione o sul widget della schermata di blocco avvia la registrazione; un secondo tocco la ferma e la manda. Non è verificato che la registrazione continui a schermo bloccato: per una riunione lunga è meglio il primo modo.

## Creare la Scorciatoia «Manda riunione» (modo 1)

App **Comandi rapidi** → **+** → nome **Manda riunione**.
1. Tocca **ⓘ** (dettagli) e attiva **Mostra nel foglio di condivisione**. Come tipo accettato lascia solo **File multimediali**, oppure **Audio** se compare.
2. Aggiungi l'azione **Ottieni contenuto dell'URL**:
   - URL: `https://<nome del server>/riunione`
   - Metodo: **POST**
   - Intestazioni: `X-Metis-Segreto` = *il segreto*; facoltativa `X-Titolo` = *un titolo breve* (oppure la variabile «Chiedi ogni volta»)
   - Corpo della richiesta: **File** → *Input della scorciatoia*
3. Aggiungi **Mostra notifica** con il *Contenuto dell'URL*: comparirà «Ricevuta. La trascrivo e ti scrivo su Telegram.»

Prova: registra dieci secondi con Memo vocali, Condividi → **Manda riunione**. Entro un paio di minuti arriva il messaggio su Telegram.

## Creare la Scorciatoia «Registra riunione» (modo 2)

App **Comandi rapidi** → **+** → nome **Registra riunione**.
1. **Registra audio**: Qualità *Normale*; Avvio *Immediatamente*; Fine *Al tocco*.
2. **Ottieni contenuto dell'URL**, come sopra, con il corpo **File** → *Audio registrato*.
3. **Mostra notifica** con il *Contenuto dell'URL*.

Poi: Impostazioni → **Tasto Azione** → Comando rapido → *Registra riunione* (iPhone 15 Pro e successivi). Su altri modelli: un widget Comandi rapidi nella schermata di blocco, oppure **Indietro tocco** (Impostazioni → Accessibilità → Tocco).

## Che cosa succede sul server

- Il segreto viene controllato. Il limite è 400 MB, cioè molte ore di registrazione.
- L'audio è convertito e trascritto con Groq, a pezzi di 20 minuti.
- La trascrizione diventa una nota nell'Inbox e l'audio si cancella.
- La sessione principale la lavora come una riunione: partecipanti, decisioni tenute distinte dagli orientamenti, cose da fare, stato del lavoro aggiornato. Poi manda il riassunto su Telegram.
- Se qualcosa va storto, il cliente riceve una riga su Telegram e l'audio resta sul server per il recupero: `riunioni.py lavora <file>`.

## Da verificare alla prima prova vera

- Quanto tempo concede iOS a «Ottieni contenuto dell'URL» per un file grande su rete cellulare. Per un'ora di riunione, in AAC qualità normale, il file è attorno ai 30-60 MB.
- Con la registrazione nella Scorciatoia (modo 2), se continua a schermo bloccato.
