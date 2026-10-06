---
name: revisione-mensile
description: Revisione mensile delle tracce — legge le trascrizioni delle sessioni del mese chiuso per trovare gli errori che nessuno ha notato (errori ripetuti, promesse non mantenute, automatismi guasti in silenzio), li raggruppa per causa e propone rimedi con la loro prova. Da fare nei primi giorni del mese, prima che Claude Code cancelli le trascrizioni (circa 30 giorni). Trigger: "revisione mensile", "rivedi le tracce del mese", "che errori non abbiamo visto", "revisione delle sessioni di settembre".
---

# Revisione mensile delle tracce

Il sistema impara dalle correzioni che il cliente fa. Questa revisione cerca **gli errori che nessuno ha notato**: le stesse cose sbagliate più volte, le promesse fatte e mai mantenute, gli automatismi che si rompono senza farsi sentire. La lezione che la rende utile: **i rimedi fatti di frasi non reggono, quelli meccanici sì**. Una regola in più in un file si dimentica; un controllo del doctor, uno script o un caso del banco di prova restano.

Costa: una decina di sottoagenti che leggono un mese di sessioni, quindi una parte visibile della quota dell'abbonamento. Si fa una volta al mese, su richiesta del cliente.

## Il giro

### 1. Preparare le tracce, fuori dal vault
```bash
bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; shift; python3 "$0/scripts/revisione-tracce.py" "$@"' "${CLAUDE_PLUGIN_ROOT}" x prepara AAAA-MM
```
Lo script trova le trascrizioni di Claude Code delle sessioni aperte nel vault, ne scrive il testo con token e chiavi oscurati in `~/Library/Caches/metis/revisione-AAAA-MM/tracce/` e le divide in lotti (`lotti.json`). Le trascrizioni non entrano nel vault. Con meno di una decina di sessioni basta un lotto.

### 2. Prima passata: un sottoagente per lotto
Un sottoagente per lotto (strumento Agent, tipo `general-purpose`), lanciati in parallelo. Nel messaggio: le istruzioni di `references/passata1.md`, la cartella `tracce/`, l'elenco dei file del lotto, il numero del lotto e la cartella d'uscita `<cartella di Claude>/revisioni/AAAA-MM/`. Ognuno scrive `passata1-NN.md`.

### 3. Seconda passata: un sottoagente solo
Con le istruzioni di `references/passata2.md`, la cartella `tracce/`, la cartella `revisioni/AAAA-MM/` e il percorso del plugin. Raggruppa le osservazioni per causa, verifica le promesse, controlla se un errore era già noto e se il rimedio esistente ha funzionato, propone al massimo otto rimedi. Scrive `revisioni/AAAA-MM/AAAA-MM Revisione mensile delle tracce.md`.

### 4. Al cliente
In chat la sezione «In breve» e l'elenco delle proposte, una riga ciascuna. **Nessun rimedio si applica senza il suo sì**, uno alla volta:
- un rimedio a una skill passa dal banco di prova (`banco/README.md` del plugin): il caso suggerito dall'errore entra nel banco del cliente e la modifica si misura prima di entrare;
- un rimedio meccanico (un controllo del doctor, uno script) si prova nei due versi: tace sul caso sano, suona sul guasto finto;
- un rimedio che tocca il plugin stesso si segnala a chi lo mantiene.

### 5. Pulizia
Stesso comando del passo 1, con `pulisci AAAA-MM`: la cartella temporanea si cancella. Nel vault restano le osservazioni e il rapporto.

## Errori da evitare
- Scrivere un rimedio come frase in più in un file, quando esiste una forma meccanica.
- Dichiarare «non mantenuta» una promessa senza aver cercato dove sarebbe la prova.
- Copiare nel rapporto brani lunghi delle trascrizioni: bastano citazioni brevi, il tanto che serve a ritrovare il punto.
- Lasciare la cartella temporanea delle tracce sul disco.
