# Metis (nome provvisorio)

Plugin di Claude Code (solo Mac) che porta su un vault Obsidian il metodo di lavoro con Claude: memoria a tre livelli, profilo del cliente con onboarding, ciclo correzioni → regole, lavori con obiettivo e impegni, mappa delle cartelle e archivio, giri automatici facoltativi.
Stato: in costruzione, pilota dal 9/10/2026. Il nome del prodotto è una variabile (`METIS_PRODOTTO` in `config/config.example`).

## Installazione

1. Copiare la cartella del plugin sul Mac, in un posto dove resterà (per esempio `~/Metis`): con un catalogo locale, tolta la cartella d'origine `claude plugin list` dà il plugin «failed to load» (provato il 3/10/2026; il comportamento in una sessione vera non è ancora provato).
2. `claude plugin marketplace add ~/Metis` e `claude plugin install metis@metis-locale`.
3. Aprire Claude Code nella cartella del vault e scrivere «installa Metis»: la skill `installa` conduce blocco per blocco.

Aggiornamento: copiare la versione nuova sopra la vecchia, poi `claude plugin marketplace update metis-locale` e `claude plugin update metis@metis-locale`.

## Che cosa c'è

- `skills/` — installa, onboarding, definizione-obiettivi, impegni, autorevisione, archiviazione, daily-digest, weekly-digest, inbox-processor.
- `hooks/` — orientamento all'avvio, guardia sulle azioni rischiose, controllo delle scritture, salvataggio prima della compattazione.
- `scripts/` — configurazione e ruoli delle cartelle (`lib/config.sh`, `configura.sh`), installazione (`installa-*.sh`, `verifica-dotazione.sh`), `doctor.sh`, `mappa.py`, `archivia.py`, giri automatici (`metis-agent.sh`), moduli (`moduli/`), Telegram e voce, `trascrizione.py`.
- `templates/memoria/` — i modelli copiati nel vault del cliente.
- `docs/guida-cliente.md` — la guida breve per il cliente.
- `tests/` — prove su vault temporanei: `test-passo3.sh` e `test-installa.sh` (con `templates/memoria`), `test-mappa.sh`, `test-telegram.sh`, `test-routine-google.sh`.
