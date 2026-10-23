# Microsoft 365: il connettore di claude.ai e il consenso dell'IT

Per un cliente con posta e calendario Microsoft 365 aziendali la strada è la stessa di Google: il **connettore Microsoft 365 di claude.ai** (Outlook posta e calendario, OneDrive, SharePoint, Teams). Fonti: Claude Help Center, «Set up the Microsoft 365 connector» e «Microsoft 365 connector security guide» (lette il 30/9/2026).

**Che cosa dice la documentazione di Anthropic:**
- disponibile su tutti i piani Claude (Free, Pro, Max, Team, Enterprise);
- serve un account Microsoft 365 aziendale (tenant Microsoft Entra con un piano Business); gli account personali @outlook.com o @hotmail.com non si collegano;
- permessi delegati: il connettore vede solo ciò che il cliente già vede; di default **legge soltanto**; la scrittura (invio, calendario, file, Teams) richiede un secondo consenso e un'abilitazione a parte;
- serve una volta il consenso di un amministratore «Global» di Microsoft Entra per l'organizzazione; sui piani Team ed Enterprise anche l'abilitazione da parte dell'amministratore Claude.
**Che cosa non dice:** se il connettore è disponibile anche in Claude Code (per i connettori Google lo è); lo si verifica con il controllo del modulo.

## 1. Il testo per l'IT

Una bozza che il cliente manda al reparto IT o al consulente esterno (Claude non la invia):

> Oggetto: consenso per il connettore Microsoft 365 di Claude, in sola lettura
>
> Vorrei collegare il mio account di lavoro a Claude (Anthropic) con il loro connettore Microsoft 365, per leggere la mia posta, il mio calendario e i miei documenti. Il connettore usa permessi delegati (vede solo ciò che vedo io) e di default legge soltanto: non invia mail e non modifica il calendario.
> Per attivarlo serve una sola volta il consenso di un amministratore Global di Microsoft Entra per il nostro tenant; la procedura è descritta da Anthropic qui: https://support.claude.com/en/articles/12542951-set-up-the-microsoft-365-connector, e le informazioni di sicurezza qui: https://support.claude.com/en/articles/12684923-microsoft-365-connector-security-guide.
> Vi chiedo se è possibile, e quali sono le regole dello studio sui dati dei clienti trattati da servizi esterni.

## 2. Dopo il consenso

1. Il cliente apre claude.ai → Impostazioni → Connettori e collega Microsoft 365 con il suo account di lavoro.
2. `bash scripts/moduli/microsoft.sh controlla`: il connettore risulta collegato in una sessione di Claude Code nel vault.
3. `bash scripts/moduli/microsoft.sh installa`: legge dalla sessione i nomi degli strumenti del connettore; nelle regole delle routine ammette quelli di lettura e nega quelli che scrivono. La classificazione è per nome: si rilegge con il cliente l'elenco che lo script stampa.
4. Con il cliente: «che cosa ho in calendario domani?» e «cerca l'ultima mail di X».

## 3. Finché l'IT non risponde

- le mail utili si salvano come file nella `_IN/` della cartella del loro lavoro (o, se il lavoro non è chiaro, nella sottocartella `files/` dell'Inbox); l'inbox-processor le lavora da lì;
- il briefing del mattino dice «posta e calendario non letti»;
- nello stato `installazione.md`: un impegno `palla:loro` «consenso dell'IT per il connettore Microsoft 365», con data di riesame e `decade:` a 21 giorni, e un `◇` in «Se arriva»: «consenso dell'IT → collegare il connettore e lanciare microsoft.sh installa».
