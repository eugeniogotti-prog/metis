# Modulo Google

**Che cosa dà:** Claude legge la posta, il calendario e i documenti di Drive del cliente; prepara bozze di risposta (l'invio resta al cliente); il digest del mattino vede la giornata.

Due strade, che si completano:

| | Connettori di claude.ai | Server locale `google-workspace-mcp` |
|---|---|---|
| Per che cosa | le sessioni con il cliente | le routine automatiche (digest, inbox) |
| Installazione | nessuna sul Mac: si attivano su claude.ai | un progetto Google Cloud del cliente, con credenziali OAuth |
| Può mandare mail | prepara bozze; l'invio chiede conferma (guardia) | no: gira in sola lettura (`--read-only`) |
| Dipende da | il login di Claude Code con l'abbonamento | il token OAuth del cliente |

## 1. Connettori (per tutti)

1. Il cliente apre claude.ai → Impostazioni → Connettori, e attiva Gmail, Google Calendar e Google Drive con il suo account.
2. **Controllo:** `bash scripts/moduli/google.sh connettori`: apre una sessione minima nel vault e legge quali connettori risultano collegati. Poi, in una sessione con il cliente: «che cosa ho in calendario domani?» e «cerca l'ultima mail di X» ricevono risposte corrette.

## 2. Server locale per le routine (solo con il modulo `routine`)

Serve perché le routine non dipendano dal login di claude.ai, e perché non possano mandare niente.

1. **Progetto Google Cloud** (il cliente, guidato passo per passo; circa 15 minuti, da misurare con i piloti): console.cloud.google.com → nuovo progetto → «API e servizi»: abilitare Gmail API, Google Calendar API, Google Drive API → schermata di consenso OAuth di tipo «Esterno», con il cliente fra gli utenti di prova → credenziali «ID client OAuth», tipo «App desktop» → scaricare il file JSON.
2. `bash scripts/moduli/google.sh credenziali <file scaricato>`: lo copia in `~/.google-mcp/credentials.json` con permessi 600.
3. `bash scripts/moduli/google.sh account`: si apre il browser; il cliente accede e consente. Google mostra l'avviso di app non verificata, perché l'app è sua e non pubblicata: si prosegue da «Avanzate».
4. `bash scripts/moduli/google.sh routine`: dichiara il server, in sola lettura e con la versione fissata, nella configurazione MCP delle routine.

**Da dire al cliente — da verificare con il primo pilota:** un'app OAuth in stato «Test» riceve da Google token che scadono dopo sette giorni. Nell'uso reale del sistema si è vista come un errore «invalid_grant» una volta alla settimana. Pubblicare l'app «in produzione» dovrebbe togliere la scadenza, ma per un'app non verificata non l'ho provato: finché non è provato, il doctor segnala il server non pronto e il rimedio è ripetere il passo 3.

**Controllo:** `bash scripts/moduli/google.sh controlla` (credenziali protette, server pronto, account autorizzato, server dichiarato per le routine).

## Microsoft 365

Vedi `moduli.md`: procedura e domande per l'IT, nessun modulo in v1.
