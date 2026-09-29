# Modulo routine

**Che cosa dà:** il lavoro che procede senza il cliente davanti. Ogni mattina il doctor controlla il sistema e il digest prepara la giornata; tre volte al giorno l'inbox-processor colloca ciò che è arrivato; la sera la sintesi della giornata; il lunedì il weekly.

| Lavoro | Orario di default | Che cosa lo esegue |
|---|---|---|
| `doctor` | 06:45 | lo script `doctor.sh`, senza Claude |
| `daily-digest` | 07:00 | un giro di Claude (`metis-agent.sh`) |
| `inbox-processor` | 09:00, 13:00, 17:00 | un giro di Claude; non parte se l'Inbox è vuota |
| `daily-sera` | 21:00 | un giro di Claude |
| `weekly-digest` | lunedì 07:30 | un giro di Claude |

Gli orari si cambiano con `METIS_ORARI_<LAVORO>` nella configurazione (per esempio `METIS_ORARI_INBOX_PROCESSOR=08:30 18:00`); i lavori scelti stanno in `METIS_JOBS`.

## Come gira un giro di Claude

`metis-agent.sh <lavoro>` lancia `claude -p` nel vault con:
- le regole delle routine (`--settings`, la copia scritta da `installa-permessi.sh`), in modalità `acceptEdits`, senza saltare i controlli;
- i server MCP delle routine (`--mcp-config`: il server Google in sola lettura, MarkItDown) e i loro strumenti ammessi per nome (`METIS_ROUTINE_STRUMENTI`);
- una regola in testa: nessuno è davanti allo schermo, niente attese, niente invii, un resoconto di tre righe.
L'esito va in una riga sotto «# Memo» nella nota del giorno: 🤖 se riuscito, «⚠️ metis-agent» se fallito. Il doctor del mattino dopo diventa rosso se trova un giro fallito. Il resoconto va anche nel log di sessione del giorno.

## Passi

1. Scegliere i lavori: `bash scripts/configura.sh set METIS_JOBS "daily-digest inbox-processor"` (più `daily-sera` e `weekly-digest` se voluti).
2. `bash scripts/moduli/routine.sh installa`: genera e carica i LaunchAgent (etichetta `METIS_LABEL`, log in `METIS_LOG_DIR`).
3. **Controllo:** `bash scripts/moduli/routine.sh prova daily-digest` esegue subito un giro e scrive la riga nella nota del giorno; `bash scripts/moduli/routine.sh controlla` dice che tutti i LaunchAgent sono caricati.

## Da dire al cliente

- **Mac acceso e sveglio agli orari.** Se a quell'ora il Mac dorme, macOS esegue il giro al risveglio; se è spento, il giro salta.
- **Quota.** Ogni giro di Claude consuma la quota dell'abbonamento: un digest del mattino sul vault di prova ha richiesto circa 25 secondi.
- **Login.** I connettori di claude.ai nei giri automatici funzionano finché il login di Claude Code resta valido; se scade, i giri falliscono e il doctor lo segnala. Il rimedio è aprire Claude Code e rifare `/login`. Per questo le routine usano il server Google locale.

## Dipendenze

I giri usano le skill `daily-digest`, `weekly-digest` e `inbox-processor` del plugin. Finché una skill non c'è, il giro non parte e lo scrive nella nota del giorno.
