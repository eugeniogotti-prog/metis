# Moduli

Ogni modulo è facoltativo e si rilancia da solo («installa <modulo>»). Prima di un modulo: le fondamenta passano (`installa-struttura.sh controlla`, doctor senza ❌), e la dotazione del modulo c'è (`verifica-dotazione.sh <modulo>`). Ogni modulo ha uno script `scripts/moduli/<modulo>.sh` con i comandi `installa` e `controlla`; il modulo è chiuso quando `controlla` esce con 0.

| Modulo | Che cosa dà | Riferimento |
|---|---|---|
| `markitdown` | Claude legge PDF, Word, Excel e PowerPoint della cartella fonti | qui sotto |
| `telegram` | riepiloghi sul telefono; ciò che il cliente manda al bot finisce nell'Inbox; conversazione con Claude dal telefono | `modulo-telegram.md` |
| `voce` | un vocale mandato al bot diventa una nota trascritta | `modulo-telegram.md`, «Voce» |
| `docx` | Claude consegna le note come documenti Word, con il modello del cliente se c'è, e non riscrive mai un documento aperto in Word o modificato a mano | qui sotto |
| `google` | posta, calendario e Drive con i connettori di claude.ai, anche nelle routine in sola lettura; server locale facoltativo | `modulo-google.md` |
| `microsoft` | posta e calendario Outlook, OneDrive, SharePoint, Teams con il connettore Microsoft 365 di claude.ai, in sola lettura nelle routine | `procedura-m365.md` |
| `routine` | doctor, digest del mattino e inbox-processor ad orari fissi | `modulo-routine.md` |

## MarkItDown

1. `bash scripts/moduli/markitdown.sh installa`: dichiara il server `markitdown` nel `.mcp.json` del vault (con il percorso assoluto di `uvx`, perché le routine non hanno Homebrew nel PATH), lo abilita e ne consente lo strumento nelle impostazioni del vault. I server già dichiarati dal cliente restano.
2. Il server parte alla prossima sessione di Claude Code nel vault.

**Controllo:** `bash scripts/moduli/markitdown.sh controlla` converte un documento Word creato al momento; poi, nella sessione nuova, si chiede a Claude di convertire un PDF della cartella fonti con lo strumento `convert_to_markdown`.

## Documenti Word (docx)

1. `bash scripts/verifica-dotazione.sh docx`: se manca pandoc, il cliente lancia `brew install pandoc`.
2. `bash scripts/moduli/docx.sh installa`: crea l'ambiente Python del modulo con python-docx (serve la rete).
3. Facoltativo: il modello Word del cliente, con i suoi stili e, se vuole la data nel piè di pagina, il segnaposto `§DATA§`: `bash scripts/configura.sh set METIS_DOCX_MODELLO "<percorso del .docx>"`.

**Uso**: `bash scripts/docx/esporta-docx.sh <nota.md> [-o file.docx] [--toc] [--borders]`. Senza `-o` il documento va nella radice della cartella fonti, dove il doctor lo segnala come file sciolto: per un documento da consegnare si passa `-o "<cartella del lavoro>/_OUT/YYYY-MM-DD <nome>.docx"`. Se il documento è aperto in Word, o è stato salvato da qualcuno dopo l'ultima esportazione, lo script si ferma (codice 3) per non cancellare quelle modifiche: si chiude Word o si scrive su un altro file; `--forza` solo su indicazione del cliente. Versioni finali in Word solo quando il cliente le chiede.

**Controllo:** `bash scripts/moduli/docx.sh controlla`.

## Microsoft 365

Modulo `microsoft`, sul modello di Google: il connettore Microsoft 365 di claude.ai (Outlook posta e calendario, OneDrive, SharePoint, Teams), disponibile su tutti i piani Claude con un account Microsoft 365 aziendale. Serve l'IT una volta, per il consenso: testo e passi in `procedura-m365.md`.

WhatsApp è fuori dalla v1.
