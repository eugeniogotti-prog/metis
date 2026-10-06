# Revisione mensile delle tracce — prima passata (istruzioni per i subagenti)

Scrivi in italiano con accenti corretti. NON leggere né cercare nella cartella riservata del vault, se c'è.

## Contesto
Il cliente lavora con Claude Code su un vault Obsidian, con le regole di Metis (`CLAUDE.md` alla radice del vault). Il sistema impara dagli errori che il cliente nota e corregge. Questa revisione cerca **quelli che nessuno ha notato**, leggendo le trascrizioni delle sessioni del mese (metodo: estrarre i fallimenti dalle tracce, raggrupparli per causa, proporre rimedi).

Trascrizioni: la cartella `tracce/` indicata nel messaggio (testi già oscurati, fuori dal vault). Il tuo lotto è indicato nel messaggio. I file grandi leggili a pezzi (offset/limit) o con grep mirati, ma copri tutto il lotto: dichiara alla fine quali file hai letto per intero e quali solo per campioni.

## Cosa cercare (tre categorie, più una)
1. **errore-ripetuto** — lo stesso tipo di sbaglio di Claude che compare più volte (anche fra sessioni diverse del lotto): passi saltati, verifiche non fatte, file sbagliati, regole di `CLAUDE.md` o del profilo non applicate.
2. **promessa** — Claude dice al cliente che farà qualcosa in futuro o in modo ricorrente («ogni notte…», «domani ti dico…», «lo controllo e ti faccio sapere», «metto un promemoria», «da ora in poi…»). Registra la promessa con data e citazione; se nel lotto stesso vedi che è stata mantenuta o no, dillo; altrimenti scrivi «esito da verificare».
3. **automatismo-silenzioso** — uno script, un hook, un LaunchAgent, un job, un controllo del doctor che fallisce, non parte o dà risultati sbagliati senza che nessuno se ne accorga subito (si scopre dopo ore o giorni, o per caso).
4. **correzione** — il cliente corregge Claude. Registrala solo con la citazione: servono per sapere se un errore era già noto.

NON registrare: errori corretti nello stesso turno da Claude stesso senza conseguenze, guasti esterni (API giù) gestiti bene, opinioni di merito sui contenuti.

## Formato d'uscita
Scrivi il file `passata1-NN.md` nella cartella `revisioni/AAAA-MM/` indicata nel messaggio (NN = numero del lotto a due cifre). Un blocco per ogni osservazione:

```
### <id breve: L<lotto>-<n>>
- categoria: errore-ripetuto | promessa | automatismo-silenzioso | correzione
- data: YYYY-MM-DD (file: <nome file>, vicino a: «<10-15 parole verbatim per ritrovarlo>»)
- meccanismo: <una frase: che cosa è andato storto e perché, in termini generali (es. «la ricerca guarda solo la inbox, non le inviate»)>
- superficie: skill <nome> | hook | script <nome> | giro automatico | CLAUDE.md | profilo | memoria | doctor | altro
- evidenza: <citazione verbatim breve; niente parafrasi spacciate per citazioni>
- notato dal cliente: sì (citazione) | no | non so
- esito (solo promesse): mantenuta (prova) | non mantenuta (prova) | esito da verificare
```

In fondo: «## Copertura» (file letti per intero, file campionati) e «## Note» (dubbi, cose fuori categoria ma rilevanti, al massimo 5 righe).

Regole: non inventare; se un dato manca scrivi «non nella traccia». Meglio 10 osservazioni solide che 40 vaghe. Rispondi al chiamante solo con: numero di osservazioni per categoria e le 3 più gravi in una riga ciascuna.
