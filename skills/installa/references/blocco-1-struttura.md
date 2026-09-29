# Blocco 1 — struttura del vault

**Esito:** ogni ruolo punta a una cartella esistente; nessuna nota del cliente spostata.

## Vault nuovo

La struttura proposta è PARA. Si accetta così, o il cliente cambia i nomi:

| Ruolo | Cartella |
|---|---|
| INBOX | `0 - Inbox` |
| PROGETTI | `1 - Progetti` |
| AREE | `2 - Aree` |
| RISORSE | `3 - Risorse` |
| PERSONE | `3 - Risorse/Persone` |
| ARCHIVIO | `4 - Archivio` |
| JOURNAL | `Journal` |
| TEMPLATE | `_Extras/_Templates` |
| CLAUDE | `_Claude` |

Poi `bash scripts/installa-struttura.sh crea`.

## Vault esistente

1. `bash scripts/installa-struttura.sh albero "<vault>"`: l'albero fino a tre livelli con il numero di note. Non scrive niente.
2. Claude propone la mappatura ruolo → cartella che esiste, con il metodo bozza e reazione: una tabella come quella sopra, con le cartelle del cliente. Esempi: una cartella «Clienti» fa da PROGETTI; una cartella di appunti in arrivo fa da INBOX; se non c'è un journal, si propone di crearlo.
3. Il cliente corregge. I ruoli che non trovano una cartella si creano nuovi, con il nome che il cliente sceglie.
4. Si scrive la mappatura: `bash scripts/configura.sh set METIS_RUOLO_<RUOLO> "<cartella relativa al vault>"`, una riga per ruolo.
5. `bash scripts/installa-struttura.sh crea`: crea solo ciò che manca (cartella di Claude, sottocartelle dell'Inbox, cartella fonti).

Se l'albero mostra un `CLAUDE.md` alla radice, è del cliente: al blocco 2 si conserva e il nucleo di Metis si aggiunge (vedi il blocco 2). Se il vault sta dentro un repository git, la memoria di Claude Code segue la radice del repository: la libreria lo gestisce da sola.

## Obsidian

Se il cliente usa Obsidian: plugin consigliati Templater, Periodic Notes, Dataview; la CLI si registra in Obsidian → Impostazioni → Generali. Prima di ogni comando `obsidian` si controlla che l'app sia aperta (`pgrep -f "Obsidian.app/Contents/MacOS/[Oo]bsidian"`): ad app chiusa il comando la avvia e non ritorna.

**Controllo:** `bash scripts/installa-struttura.sh controlla` esce con 0; con Obsidian aperto, `obsidian daily:read` risponde.
