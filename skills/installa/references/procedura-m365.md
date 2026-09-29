# Microsoft 365: domande per l'IT e ripiego

Nella v1 non c'è un modulo per posta e calendario Microsoft 365: nessun server è stato provato. L'integrazione vera è un servizio a giornata. Nell'installazione si fa questo.

## 1. Il testo per l'IT

Si prepara una bozza che il cliente manda al suo reparto IT o al consulente esterno (Claude non la invia):

> Oggetto: autorizzazione per un assistente AI in sola lettura su posta e calendario
>
> Vorrei usare Claude Code sul mio Mac per leggere la mia posta e il mio calendario dello studio, in sola lettura. Vi chiedo:
> 1. se è possibile registrare un'applicazione in Microsoft Entra ID con i permessi delegati di sola lettura `Mail.Read` e `Calendars.Read` (Microsoft Graph), per il mio solo account;
> 2. se, in alternativa, posso pubblicare il mio calendario come link ICS in sola lettura (Outlook → Impostazioni → Calendario → Calendari condivisi → Pubblica un calendario);
> 3. quali sono le regole dello studio sui dati dei clienti trattati da servizi esterni (i contenuti letti passano dal servizio Claude con il mio abbonamento).

Per la posta via IMAP con una password per app: Microsoft ha disattivato l'autenticazione di base per Exchange Online nel 2022 (dato da conoscenza generale, non riverificato nell'installazione); la via IMAP oggi richiede OAuth, cioè la stessa registrazione dell'app della domanda 1.

## 2. Il ripiego, da subito

- **Posta:** le mail utili si salvano come file nella cartella fonti, o si inoltrano a sé stessi e si salvano; l'inbox-processor le lavora da lì.
- **Calendario:** se l'IT consente il link ICS, Claude lo legge in sola lettura; altrimenti il briefing del mattino dice «calendario non letto».

## 3. L'attesa

Nello stato `installazione.md`: un impegno `palla:loro` «risposta dell'IT su Microsoft 365», con data di riesame e `decade:` a 21 giorni, e un `◇` in «Se arriva»: «risposta dell'IT → se sì alla domanda 1, proporre la giornata di integrazione; se sì alla 2, configurare il link ICS».
