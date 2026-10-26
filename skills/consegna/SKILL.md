---
name: consegna
description: Le regole per ciò che il cliente manda ad altri - mail, risposte, messaggi, documenti in allegato. Si preparano solo bozze; si invia solo con il suo via esplicito per quel messaggio e quel destinatario; gli allegati li carica Claude dal disco con lo script della posta e li verifica per hash; una bozza da correggere si rilegge com'è adesso e si parte dal testo del cliente, poi se ne crea una nuova e si cancella la vecchia. Le regole valgono sempre, anche senza invocare la skill. Trigger - "preparami la mail per", "rispondi a", "manda a", "allega", "correggi la bozza", "rifai la bozza", "ho modificato la bozza", "inviala".
---

# Consegna: bozze per altri

Vale per ogni testo che esce verso altri: mail, risposte, messaggi, il testo che accompagna un documento. Le regole di voce e registro sono quelle del profilo del cliente (`profilo-nucleo.md` e, prima di ogni testo per altri, la pagina completa).

## 1. Solo bozze

- Claude prepara la **bozza**; il cliente la rilegge e la manda. Si invia solo con un suo via esplicito, valido per **quel messaggio e quel destinatario**: un «manda pure» di ieri o per un altro destinatario non vale.
- Quando il cliente dà il via e chiede a Claude di inviare: **prima** si guarda la posta inviata del thread (gli ultimi giorni). Se c'è già un messaggio con lo stesso oggetto allo stesso destinatario, non si invia e lo si dice. «Nessuna bozza» non vuol dire «non partita».
- Ogni invio fatto si scrive nello stato del lavoro come fatto, con la data. Un invio non apre un'attesa (skill `impegni`).

## 2. Allegati: li carica Claude, dal disco

Con la posta dal server locale (modulo google), gli allegati si mettono nella bozza con lo script del plugin, che legge i file dal disco: il contenuto non passa da Claude.

```bash
node "<cartella del plugin>/scripts/gmail-bozza.mjs" --to … --subject … --body-file testo.txt --attach <file> [--thread-id <thread>]
```

- I file si prendono dalla `_OUT/` del lavoro.
- Lo script riscarica ogni allegato dalla bozza e lo confronta con l'originale (SHA-256). Al cliente si dice l'esito in una riga: «bozza pronta, 2 allegati verificati».
- Per una risposta, `--thread-id` del messaggio a cui si risponde: la bozza resta nella conversazione.
- Oltre 25 MB per messaggio: un link al file nel corpo, non l'allegato.
- Se l'uscita riporta un `draftId` anche in un errore, la bozza esiste già: non si rilancia, si guarda che cosa manca.
- Non si chiede al cliente di allegare a mano, se lo script c'è.

## 3. Correggere una bozza: si parte dal testo del cliente

Il cliente può aver già messo mano alla bozza in Gmail. Le sue modifiche si conservano.

1. **Rileggere la bozza com'è adesso**, non la propria copia:
   ```bash
   node "<cartella del plugin>/scripts/gmail-bozza.mjs" --leggi <draftId> --salva-in <cartella temporanea>
   ```
   Riporta destinatari, oggetto, testo, allegati e il `messageId`; salva `corpo.txt` e gli allegati della bozza.
2. **Partire da quel testo** e applicare solo le modifiche chieste.
3. **Dire al cliente** quali sue modifiche si sono trovate e tenute («ho trovato e tenuto: il saluto, il secondo paragrafo accorciato»). Se una sua modifica rende incoerente il resto (per esempio saluto al plurale e frasi al singolare), lo si segnala e si propone l'allineamento, senza riscrivere il suo testo di iniziativa.
4. **Creare una bozza nuova e cancellare la vecchia**, mai riscriverla: con Gmail aperto nel browser il cliente vedrebbe la copia vecchia, senza gli allegati nuovi.
   ```bash
   node "<cartella del plugin>/scripts/gmail-bozza.mjs" --to … --subject … --body-file <cartella>/corpo.txt \
        --attach … --sostituisce <draftId> --se-messaggio <messageId letto> (--thread-id <thread> | --senza-thread)
   ```
   Lo script si ferma se la bozza è cambiata dopo la lettura, e cancella la vecchia solo se la nuova è salvata e gli allegati tornano. Gli allegati che restano si ripassano tutti (quelli salvati al punto 1, o i file aggiornati).
   I destinatari si ripassano come li ha riportati il punto 1: Gmail li scrive «Nome <indirizzo>», lo script tiene l'indirizzo (gli elenchi nudi sono anche in `indirizzi`). Limite noto: nella bozza nuova il nome visualizzato del destinatario si perde.

La stessa regola vale per un testo in un file che il cliente ha corretto: si rilegge il file e si parte da lì.

## 4. Senza lo script

- **Posta non Gmail, o senza il server locale:** la bozza senza allegati con gli strumenti di posta collegati, e al cliente una riga con i file da allegare e dove stanno.
- **Connettore di posta dell'app:** se il vault usa il server locale, il connettore è bloccato dalla guardia e non si usa.
