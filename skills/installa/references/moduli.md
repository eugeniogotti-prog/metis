# Moduli

Ogni modulo è facoltativo e si rilancia da solo («installa <modulo>»). Prima di un modulo: le fondamenta passano (`installa-struttura.sh controlla`, doctor senza ❌), e la dotazione del modulo c'è (`verifica-dotazione.sh <modulo>`). Ogni modulo ha uno script `scripts/moduli/<modulo>.sh` con i comandi `installa` e `controlla`; il modulo è chiuso quando `controlla` esce con 0.

| Modulo | Che cosa dà | Riferimento |
|---|---|---|
| `markitdown` | Claude legge PDF, Word, Excel e PowerPoint della cartella fonti | qui sotto |
| `telegram` | riepiloghi sul telefono; ciò che il cliente manda al bot finisce nell'Inbox; conversazione con Claude dal telefono | `modulo-telegram.md` |
| `voce` | un vocale mandato al bot diventa una nota trascritta | `modulo-telegram.md`, «Voce» |
| `google` | posta, calendario e Drive; server locale per le routine automatiche | `modulo-google.md` |
| `routine` | doctor, digest del mattino e inbox-processor ad orari fissi | `modulo-routine.md` |

## MarkItDown

1. `bash scripts/moduli/markitdown.sh installa`: dichiara il server `markitdown` nel `.mcp.json` del vault (con il percorso assoluto di `uvx`, perché le routine non hanno Homebrew nel PATH), lo abilita e ne consente lo strumento nelle impostazioni del vault. I server già dichiarati dal cliente restano.
2. Il server parte alla prossima sessione di Claude Code nel vault.

**Controllo:** `bash scripts/moduli/markitdown.sh controlla` converte un documento Word creato al momento; poi, nella sessione nuova, si chiede a Claude di convertire un PDF della cartella fonti con lo strumento `convert_to_markdown`.

## Microsoft 365 (servizio, fuori dalla v1)

Nessun modulo: per posta e calendario Microsoft 365 non c'è un server provato. Nell'installazione si fa solo questo:
1. si consegnano al cliente le domande per il suo reparto IT (dal kit: `checklist-oauth-e-m365.md`): se consente la registrazione di un'app in Entra con le autorizzazioni di lettura di posta e calendario; se consente IMAP con una password per app; se il calendario si può pubblicare come ICS in sola lettura;
2. nel frattempo il ripiego: le mail utili si salvano a mano nella cartella fonti, e l'inbox-processor le lavora da lì;
3. si registra nello stato `installazione.md` un impegno `palla:loro` con la data di riesame e la decadenza, per la risposta dell'IT.
L'integrazione vera è una giornata di consulenza.

WhatsApp è fuori dalla v1.
