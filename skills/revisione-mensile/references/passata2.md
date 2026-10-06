# Revisione mensile delle tracce — seconda passata (raggruppamento e proposte)

Scrivi in italiano con accenti corretti. NON leggere né cercare nella cartella riservata del vault, se c'è.

## Input
- Le osservazioni della prima passata: `passata1-*.md` nella cartella `revisioni/AAAA-MM/` indicata nel messaggio.
- Per verificare: le tracce oscurate nella cartella `tracce/` indicata nel messaggio; il vault; nella cartella di Claude i log di sessione (`sessioni/`, anche del mese in corso), `correzioni.md` e il suo archivio (`archivio/correzioni-*.md`), `regole-di-metodo.md`, `decisioni.md`, gli stati; le skill e gli script del plugin (percorso indicato nel messaggio).

## Compito
1. **Raggruppa per firma.** Due osservazioni hanno la stessa firma se condividono il **meccanismo** (la causa in termini generali) e la **superficie** da toccare, anche se il dominio è diverso. Unisci le formulazioni diverse dello stesso meccanismo. Tieni i gruppi con **almeno due casi**; i casi singoli vanno in coda in un elenco breve, salvo che siano gravi (dati persi, mail sbagliate, impegni con terzi mancati).
2. **Verifica le promesse.** Per ogni promessa «esito da verificare», cerca nelle trascrizioni successive e nel vault se è stata mantenuta (file creato, job attivo, voce scritta, messaggio inviato). Esito: mantenuta, non mantenuta o parziale, con prova (percorso, riga, citazione). Se non riesci a stabilirlo, scrivi «non verificabile» e perché. Mai «non mantenuta» senza aver cercato dove sarebbe la prova.
3. **Controlla se è già noto e già rimediato.** Per ogni gruppo cerca in `correzioni.md` e nel suo archivio, in `regole-di-metodo.md`, nel profilo, nelle skill e negli script se esiste già una regola o un rimedio. Distingui: (a) nuovo; (b) noto ma senza rimedio; (c) rimedio esistente che **non ha funzionato** (l'errore si ripete dopo la data del rimedio): è il caso più prezioso; (d) rimediato e non più ripetuto.
4. **Proponi le correzioni** solo per i gruppi (a), (b) e (c), al massimo 8, in ordine di gravità. Per ciascuna:
   - superficie e modifica minima (testo della regola, controllo del doctor, modifica di uno script o di un hook);
   - **prova di non regressione**: per una skill, il caso o i casi da aggiungere al banco di prova del cliente (`banco-skill/<skill>/casi/` nella cartella di Claude, formato in `banco/README.md` del plugin); per uno script, un hook o il doctor, che cosa deve segnalare nel caso del guasto e su che cosa NON deve dare falsi allarmi;
   - costo e rischio in una riga.
   Non modificare nulla: proponi soltanto.

## Uscita
Scrivi `AAAA-MM Revisione mensile delle tracce.md` nella cartella `revisioni/AAAA-MM/` con frontmatter:

```
---
created_at: AAAA-MM-GG
tags:
- tipo/analisi
- argomento/PKM
- argomento/AI
up:
- '[[_Claude]]'
updated_at: null
---
```

Sezioni:
1. **In breve**, 5-8 righe per il cliente, in italiano piano.
2. **Gruppi di errori**, in una tabella con firma, numero di casi, date, classe (a/b/c/d) e superficie; poi un paragrafo per gruppo con i casi e le citazioni.
3. **Promesse**, in una tabella con data, promessa, esito e prova.
4. **Automatismi silenziosi**: che cosa si è rotto, per quanto tempo, chi se n'è accorto.
5. **Proposte**, numerate.
6. **Casi singoli** in coda.
7. **Copertura e limiti**: lotti e file campionati, che cosa la revisione non può vedere.

Rispondi al chiamante con la sezione «In breve» e l'elenco delle proposte, una riga ciascuna.
