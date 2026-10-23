# Pubblicare una versione di Metis

Il repository è pubblico: chiunque legge i file, le modifiche e i messaggi di commit, compresa la storia passata. Le regole valgono per chi mantiene il plugin e per le sessioni di Claude che ci lavorano.

## Che cosa non entra mai

- **Nomi di clienti, enti, piloti o terzi**: né nei file, né nei messaggi di commit, né negli esempi. Al loro posto si scrive «il cliente», «un pilota», «la cartella di prova». Gli esempi usano persone inventate (come Giulia Ferri nel banco o Paola Rinaldi nelle prove) e lo dicono.
- **Segreti**: token, chiavi, credenziali, anche scaduti.
- **Percorsi del Mac** di chi sviluppa (`/Users/<nome>/…`) e contenuti dei vault veri: i casi veri del banco restano fuori, ed entrano solo quelli d'esempio.

Un nome finito in un commit già pubblicato non si toglie correggendo il file: resta nella storia. Va riscritto il commit (con il via di chi mantiene il plugin), e le copie già scaricate restano.

## Prima di ogni push

1. Le prove passano: `bash tests/test-installa.sh templates/memoria`, `bash tests/test-passo3.sh templates/memoria` e le altre in `tests/`.
2. Il numero di versione è alzato in `.claude-plugin/plugin.json`.
3. Il controllo è pulito: `bash tests/controlla-pubblicabile.sh`. Cerca segreti, percorsi e nomi nei file versionati, nelle modifiche in attesa e in tutti i messaggi di commit. I nomi da cercare stanno in un file **fuori dal repository** (`~/.config/metis-dev/nomi-vietati.txt`, oppure quello indicato in `METIS_NOMI_VIETATI`), una voce per riga: pubblicare la lista sarebbe la stessa fuga che il controllo vuole evitare. Le parole comuni che sono anche cognomi si mettono solo come nome completo.
4. Il push lo fa solo chi mantiene il plugin, oppure una sessione di Claude che ha ricevuto da lui il via esplicito per quel push.

Chi ha installato da GitHub aggiorna con `claude plugin marketplace update metis` e `claude plugin update metis@metis`, poi riapre Claude Code.
