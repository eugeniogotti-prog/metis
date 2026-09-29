# Modalità sera: «La giornata»

Serve ad assimilare. Il cliente legge la sera che cosa è passato e, se tiene un diario, scrive reagendo a quello che trova qui invece di partire da un foglio bianco.

## Dove si scrive

Nella nota di oggi, in una sezione `# La giornata`, subito sopra `# Diario` se c'è, altrimenti in fondo. Se la sezione esiste già (un giro precedente), si sostituisce. Il resto della nota non si tocca.

## Da dove si raccoglie (solo oggi)

- le righe del Memo di oggi: inbox-processor, briefing, note arrivate dal bot;
- il log di sessione di oggi nella cartella di Claude (`sessioni/YYYY-MM-DD.md`);
- le note create o modificate oggi nelle cartelle dei progetti, delle aree e delle risorse (la data del file va incrociata con `created_at`/`updated_at`);
- gli impegni chiusi, aperti o spostati oggi negli stati.

**Valorizzare i contenuti, oltre a registrarli.** Per ogni contenuto salvato (clipping, note dal bot, vocali, file), la voce dice tre cose: l'idea centrale in una frase, come la direbbe l'autore; perché conta per il cliente (a quale lavoro o interesse si aggancia, oppure curiosità pura); dove sta adesso, con il wikilink. «Archiviato in una cartella» non basta.

## Struttura

```markdown
# La giornata

### Che cosa è entrato oggi
- [[Nota]] — idea centrale · perché conta · lavoro: [[stato]]

### Che cosa si è mosso
- ✅ chiuso: … · 🆕 aperto: … · ⏩ spostato: …

### Il filo del giorno
Una o due frasi sul lavoro che ha concentrato più attività, oppure «Nessun filo dominante oggi».

### Tre domande per il diario
1. …
2. …
3. …
```

## Regole

- Un elenco ragionato, da 5 a 12 voci: si raggruppano gli elementi dello stesso lavoro e si tolgono i movimenti di servizio.
- Le domande nominano cose precise di oggi, con i wikilink. Una domanda che andrebbe bene in qualunque giorno si scarta. Forme possibili: «Hai letto X: cambia qualcosa su [[lavoro]]?»; «L'impegno Y è fermo da N giorni: è ancora vivo?»; «Oggi due fonti dicevano cose diverse su Z: quale ti convince?». Almeno una tocca un contenuto salvato, quando ce n'è uno.
- In una giornata vuota bastano due righe, senza domande forzate.
- Niente raccomandazioni operative: servono al briefing del mattino.
- Registro del profilo del cliente.

## Messaggio sul telefono (solo con il modulo Telegram)

Dopo aver scritto e riletto la sezione: due righe su che cosa è entrato oggi, una sola delle tre domande (la più viva), una riga che dice che le altre sono nella nota del giorno. Con lo script del plugin: `python3 <cartella del plugin>/scripts/telegram/metis_telegram.py invia "testo"` (la cartella del plugin è scritta in testa al prompt del giro). In una giornata vuota non si manda.

## Chiusura

Una riga nel Memo: `- 🤖 HH:MM daily-sera: N voci, filo del giorno, messaggio mandato sì/no`.
