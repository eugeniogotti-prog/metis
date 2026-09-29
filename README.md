# Metis (nome provvisorio)

Plugin di Claude Code che installa su un vault Obsidian la memoria a tre livelli, l'onboarding e il ciclo correzioni → regole.
Stato: in costruzione, uso interno. Il nome del prodotto è una variabile (`METIS_PRODOTTO` in `config/config.example`).

- `hooks/session-orient.sh` — hook di avvio: inietta profilo e stato attuale; muto fuori dal vault configurato.
- `scripts/doctor.sh` — controllo giornaliero: tetti del contesto, onboarding, inizio mese, convenzioni, stati, Inbox, automazioni.
- `scripts/lib/config.sh` — lettura della configurazione e ruoli delle cartelle.
- `tests/test-passo3.sh <cartella dei modelli>` — prova su vault temporanei.
