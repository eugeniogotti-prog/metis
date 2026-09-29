# Modulo Telegram (e voce)

**Che cosa dà al cliente**, a livelli, e lui sceglie fin dove arrivare:
1. **uscita**: il digest del mattino e gli avvisi arrivano sul telefono;
2. **Inbox dal telefono**: ciò che manda al bot (un link, un testo che comincia con «nota», un messaggio inoltrato, un file, una foto) diventa una nota nell'Inbox, che l'inbox-processor colloca al giro successivo. Sostituisce i Messaggi Salvati, senza il login di Telethon;
3. **conversazione**: un messaggio normale al bot riceve la risposta di Claude, che lavora nel vault con il profilo e gli stati. Ogni messaggio è un giro `claude -p`; la conversazione si riprende se l'ultimo messaggio è di meno di sei ore; «/nuova» ne comincia un'altra;
4. **voce** (modulo `voce`): un vocale diventa testo. Se comincia con «nota» finisce in `voicenotes/` come nota; altrimenti è un messaggio di conversazione, e la risposta comincia con «Ho capito: …».

Il bot scrive soltanto alla chat del cliente e ascolta soltanto lei: i messaggi di altri si ignorano e si registrano nel log.

## Passi

1. **Il bot.** Il cliente apre Telegram, cerca @BotFather, scrive `/newbot`, sceglie un nome e un nome utente (deve finire in «bot»), e riceve un token. Claude non vede lo schermo del telefono: lo guida a parole.
2. **Il token.** `bash scripts/moduli/telegram.sh token`: il cliente incolla il token, che non compare a schermo e va in `~/.config/metis/telegram` con permessi 600. Lo script verifica con Telegram che il token sia valido.
3. **La chat.** Il cliente scrive «ciao» al suo bot dal telefono; poi `bash scripts/moduli/telegram.sh chat`.
4. **Uscita e prova.** `bash scripts/moduli/telegram.sh installa`: manda un messaggio di prova. Il cliente conferma di averlo ricevuto.
5. **Inbox e conversazione** (se li vuole). `bash scripts/moduli/telegram.sh ascoltatore`: genera e carica il LaunchAgent sempre acceso che ascolta il bot. Si prova dal telefono: un link (atteso: «Salvato nell'Inbox» e la nota in `<Inbox>/telegram`), poi una domanda sui suoi lavori (attesa: la risposta di Claude).
6. **Voce** (se la vuole). Il cliente crea un account su console.groq.com e una chiave API; `bash scripts/moduli/voce.sh chiave`; `bash scripts/moduli/voce.sh controlla`. Dal telefono: un vocale che comincia con «nota…».

## Da dire al cliente

- **Mac acceso.** L'Inbox dal telefono e la conversazione funzionano solo mentre il Mac è acceso e sveglio; i messaggi mandati a Mac spento si lavorano alla riaccensione, nell'ordine in cui sono arrivati.
- **Tempi.** Misurati il 29/9/2026 su un vault di prova: una domanda nuova circa 13 secondi, una domanda che riprende la conversazione circa 6 secondi, più il tempo di Telegram.
- **Quota.** Ogni messaggio di conversazione è una sessione di Claude Code: consuma la quota dell'abbonamento del cliente. Sul vault di prova Claude Code ha dichiarato circa 0,31-0,35 dollari per scambio a tariffa API: con l'abbonamento non si paga a parte, ma una conversazione lunga dal telefono pesa sulla quota quanto una al Mac.
- **Dove passano i dati.** I messaggi passano dai server di Telegram; l'audio dei vocali da Telegram e da Groq. Chi ha obblighi di riservatezza sceglie che cosa mandare.
- **Che cosa Claude può fare dal telefono.** Le stesse cose che fa al Mac nei giri automatici, con le stesse regole: legge e scrive nel vault; non manda mail né messaggi a terzi (la guardia li ferma, e in un giro automatico una richiesta di conferma vale come un no).

**Controllo:** `bash scripts/moduli/telegram.sh controlla` esce con 0; con il modulo voce, anche `bash scripts/moduli/voce.sh controlla`.
