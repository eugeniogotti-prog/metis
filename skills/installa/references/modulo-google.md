# Modulo Google

**Che cosa dà:** Claude legge la posta, il calendario e i documenti di Drive del cliente; con il cliente prepara bozze di risposta (l'invio resta a lui); il briefing del mattino vede la giornata.

**Decisione del 30/9/2026:** la strada principale sono i connettori di claude.ai, per le sessioni con il cliente e per le routine automatiche. Il server Google locale resta facoltativo, da provare con l'account vero del cliente prima di usarlo: dei due pacchetti disponibili, quello in uso nel sistema di riferimento ha il repository archiviato, l'altro è mantenuto ma piccolo e mai provato con un account vero.

## 1. Connettori (per tutti)

1. Il cliente apre claude.ai → Impostazioni → Connettori e attiva Gmail, Google Calendar e Google Drive con il suo account. Con un account aziendale di Google Workspace può servire il via dell'amministratore.
2. `bash scripts/moduli/google.sh installa`: nelle regole delle routine ammette per nome gli strumenti di lettura dei tre connettori e nega quelli che scrivono (invii, risposte, inoltri, bozze, cestino, eventi, condivisioni). Nelle sessioni con il cliente le bozze restano possibili; gli invii chiedono conferma (guardia).
3. **Controllo:** `bash scripts/moduli/google.sh connettori` apre una sessione minima nel vault e legge quali connettori risultano collegati. Poi, con il cliente: «che cosa ho in calendario domani?» e «cerca l'ultima mail di X».

**Da dire al cliente.** Nelle routine i connettori funzionano finché il login di Claude Code con l'abbonamento resta valido. Se scade, i giri automatici non leggono più posta e calendario: il doctor lo vede ogni mattina (esegue il controllo dei connettori) e il rimedio è aprire Claude Code e rifare `/login`.

## 2. Server locale (facoltativo, da provare)

Serve solo se si vuole che le routine non dipendano dal login di claude.ai. Richiede un progetto Google Cloud del cliente: API di Gmail, Calendar e Drive abilitate; schermata di consenso «Esterno» con il cliente fra gli utenti di prova (o «Interna» con un account Workspace); credenziali «ID client OAuth» di tipo «App desktop».
1. `bash scripts/moduli/google.sh credenziali <file scaricato>` (copia in `~/.google-mcp/credentials.json`, 600);
2. `bash scripts/moduli/google.sh account` (consenso nel browser; «app non verificata» → Avanzate);
3. `bash scripts/moduli/google.sh server` (server in sola lettura, versione fissata, per le routine).
Con l'app in «Test» l'autorizzazione scade dopo sette giorni; pubblicare l'app, o farla «Interna» con un account Workspace, dovrebbe evitarlo (lo dicono le istruzioni dei pacchetti; da provare).

**Controllo:** `bash scripts/moduli/google.sh controlla` (connettori, e server locale se dichiarato).

## Microsoft 365

Vedi `procedura-m365.md`: testo per l'IT e ripiego, nessun modulo in v1.
