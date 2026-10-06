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
3. Il cliente corregge. I ruoli che non trovano una cartella si creano nuovi, con il nome che il cliente sceglie, alla radice del vault o dove dice lui: **mai dentro la cartella di Claude**, che è la memoria operativa e resta fuori dai controlli sulle note (emerso dalla prova del 29/9, dove risorse e persone erano finite in `_Claude/`).
4. Si scrive la mappatura: `bash scripts/configura.sh set METIS_RUOLO_<RUOLO> "<cartella relativa al vault>"`, una riga per ruolo.
5. `bash scripts/installa-struttura.sh crea`: crea solo ciò che manca (cartella di Claude, sottocartelle dell'Inbox, cartella fonti).

Se l'albero mostra un `CLAUDE.md` alla radice, è del cliente: al blocco 2 si conserva e il nucleo di Metis si aggiunge (vedi il blocco 2). Se il vault sta dentro un repository git, la memoria di Claude Code segue la radice del repository: la libreria lo gestisce da sola.

## Mappa delle cartelle e archivio

Servono alla mappa giornaliera (`scripts/mappa.py`, lanciata dal doctor) e alla skill `archiviazione`. Si chiedono qui, con una proposta già scritta, una domanda alla volta:
1. **Radici da tenere d'occhio.** Proposta: la cartella dei lavori, quella dell'archivio e la cartella fonti su disco. Se i documenti del cliente stanno anche altrove, si aggiungono: `configura.sh set METIS_MAPPA_RADICI "<lavori>|<archivio>|<percorso>"`. **Se il cliente ha cartelle per anno** (per esempio «2026 attività in corso» in Drive), al posto dell'anno si scrive il segnaposto `{anno}`: `~/Drive/{anno} attività in corso`. La mappa prende ogni volta la cartella dell'anno corrente, o la più recente se quella nuova non c'è ancora; al cambio d'anno segnala una radice nuova, senza dare per sparite le cartelle dell'anno prima. Scritto con l'anno fisso, dal gennaio successivo la mappa continuerebbe a guardare la cartella vecchia. Se va bene il default, non si scrive niente.
2. **Contenitori.** Se nella cartella fonti c'è una cartella i cui figli sono lavori distinti («Gare», «Clienti 2026»), la si dichiara: `configura.sh set METIS_MAPPA_CONTENITORI "Gare"`. Quelle con almeno dieci sottocartelle sono riconosciute da sole.
3. **Archivio per anno o piatto.** Proposta: una cartella per anno dentro l'archivio (`METIS_ARCHIVIO_PER_ANNO=sì`, default). Se il cliente archivia già in modo piatto: `configura.sh set METIS_ARCHIVIO_PER_ANNO no`.
4. **Cartelle su disco a fine lavoro.** Proposta: restano dove sono, e lo stato archiviato le ricorda (default, niente da scrivere). Se il cliente le sposta abitualmente in una cartella d'archivio: `configura.sh set METIS_FONTI_ARCHIVIO "<percorso>"`; la skill proporrà lo spostamento, lavoro per lavoro.

**Controllo:** dopo il doctor esistono `<cartella di Claude>/mappa-inventario.md` e `mappa-archivio.md`, e la sezione «Mappa delle cartelle» del doctor dice «prima fotografia delle cartelle». Il confronto parte dal giorno dopo, e solo nei giorni in cui il doctor gira: ogni mattina con il modulo `routine` e il Mac acceso, altrimenti quando lo si lancia a mano.

## Obsidian

Se il cliente usa Obsidian: plugin consigliati Templater, Periodic Notes, Dataview; la CLI si registra in Obsidian → Impostazioni → Generali. Prima di ogni comando `obsidian` si controlla che l'app sia aperta (`pgrep -f "Obsidian.app/Contents/MacOS/[Oo]bsidian"`): ad app chiusa il comando la avvia e non ritorna.

**Controllo:** `bash scripts/installa-struttura.sh controlla` esce con 0; con Obsidian aperto **sul vault del cliente** (la CLI agisce sul vault aperto nell'app), `obsidian daily:read` risponde.
