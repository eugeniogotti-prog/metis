# Metis nell'app di Claude: il passaggio dal Terminale al tab Code

**Perché serve il plugin nell'app.** Il tab Code dell'app di Claude lavora sulla stessa cartella del tuo vault, ma da solo non conosce Metis. Senza il plugin, Claude legge le tue note ma non ha le skill (briefing, impegni, archiviazione, revisione), non riceve all'avvio il tuo profilo e lo stato dei lavori, non ha la guardia che chiede conferma prima di un invio o di una cancellazione, e i giri automatici restano legati alla versione vecchia. Con il plugin caricato nell'app ritrovi tutto com'era, alla versione nuova. Profilo, lavori, correzioni e note restano come sono, e l'avvio non si rifà.

Ti servono un quarto d'ora, il Mac collegato a internet e il file `Metis-<versione>.zip` che ti abbiamo mandato. Lo zip non va aperto. I passi da 3 a 5 vanno fatti di seguito.

## 1. Apri il tab Code

Apri l'app Claude e scegli **Code** in alto. Se l'app chiede di aggiornarsi, aggiornala prima.

## 2. Scegli la cartella del vault

Accanto al campo in cui scrivi c'è il selettore della cartella. Scegli **la cartella del tuo vault**, cioè quella che Obsidian apre, e non una cartella che la contiene (per esempio Documenti). È lì che stanno le regole di Metis, ed è lì che Claude deve lavorare. Se non sei sicuro di quale sia, nel Terminale questo comando la scrive: `grep METIS_VAULT ~/.config/metis/config`.

Se l'app ti chiede se ti fidi della cartella, rispondi di sì: senza fiducia, le regole del vault non valgono.

## 3. Togli la versione installata dal Terminale

Due copie di Metis non devono convivere: l'app può rifiutare lo zip se ne trova un'altra con lo stesso nome, e con due copie una parte delle protezioni non girerebbe. Nella sessione appena aperta scrivi:

> Togli Metis installato da terminale: lancia `claude plugin uninstall metis@metis` e poi `claude plugin marketplace remove metis`.

Il vault non cambia. La cartella `Metis` nella tua cartella Inizio per ora resta dov'è.

## 4. Carica lo zip nell'app

**Impostazioni → Plugin**, poi l'aggiunta di un plugin da file: scegli `Metis-<versione>.zip`. Metis compare fra i plugin creati da te.

## 5. Apri una sessione nuova e aggiorna

Torna al tab Code e apri una **sessione nuova** sulla stessa cartella del vault. All'avvio Claude ti dice che c'è un aggiornamento dell'installazione da fare: rispondi di sì. Se non lo dice, scrivi «aggiorna Metis».

Claude fa una copia di sicurezza, rimette in ordine le regole e i giri automatici sulla versione nuova e ti riporta il semaforo del controllo. Il tuo profilo, i lavori e le note non si toccano.

## 6. Controlla

- Scrivi «che cosa dice il doctor?». Atteso: verde, oppure giallo con un motivo che Claude ti spiega.
- Scrivi `/`: compaiono i comandi che cominciano con `metis:`.
- Scrivi «controlla l'aggiornamento di Metis»: Claude ti conferma che i giri automatici usano la versione nuova e che non resta una copia installata dal Terminale.

Quando il doctor è verde da qualche giorno, la cartella `Metis` nella tua cartella Inizio non serve più e si può cancellare.

## Se qualcosa non va

| Che cosa vedi | Che cosa fare |
|---|---|
| All'avvio Claude non ti dà il profilo né l'orientamento | La sessione è in un'altra cartella: chiudila e riaprila sulla cartella del vault (passo 2) |
| L'app rifiuta lo zip | Il passo 3 non è andato a buon fine: ripetilo, poi riprova il passo 4 |
| Il doctor è rosso | Scrivi «che cosa dice il doctor?»: Claude legge il report e ti propone il rimedio |
| Vuoi tornare a com'era | Chiedilo a Claude: la copia di sicurezza fatta al passo 5 contiene un file `LEGGIMI.txt` che dice dove rimettere ogni file |
