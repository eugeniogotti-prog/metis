# Metis: la guida breve

Metis fa lavorare Claude Code dentro il tuo vault con un metodo: Claude sa chi sei e come scrivi, tiene il filo dei tuoi lavori, ricorda gli impegni e impara dalle tue correzioni. Questa pagina dice che cosa fare ogni giorno e che cosa fare quando qualcosa non va.

## I quattro gesti

1. **Aprire.** Apri il Terminale, entra nella cartella del vault (`cd` seguito dal percorso) e scrivi `claude`. All'apertura Claude legge il tuo profilo, lo stato dei lavori e i segnali del controllo del mattino: puoi cominciare direttamente con la richiesta.
2. **Correggere.** Quando un risultato non va, dillo così: **«questo non va perché…, d'ora in poi…»**. Claude registra il caso e, se è una regola di stile che confermi, la aggiunge subito al tuo profilo. È il gesto che fa migliorare il sistema: più correzioni dai nelle prime settimane, prima Claude scrive come te.
3. **Chiudere.** Prima di uscire, scrivi **«chiudi sessione»**, poi `/exit`. Claude scrive il diario della sessione, aggiorna lo stato dei lavori toccati, le note delle persone e ciò che ha imparato sul merito. Se esci senza chiudere, il giorno dopo Claude se ne accorge e ti propone di ricostruire il diario.
4. **Decidere.** Claude prepara, tu decidi. Mail e messaggi verso altri restano bozze finché non dici di inviarli, uno per uno. Archiviare un lavoro, cancellare un file, spostare una cartella: Claude chiede prima.

## Dove stanno le cose

- **I tuoi lavori**: ognuno ha uno «stato» nella cartella di Claude (`_Claude/stati/`, salvo nomi diversi scelti all'installazione), con l'obiettivo, a che punto siamo e gli impegni. Per avviare un lavoro nuovo basta dirlo: Claude cerca se hai già fatto qualcosa di simile e ti propone l'obiettivo da correggere.
- **Gli impegni**: dentro lo stato di ciascun lavoro, con una data e con chi deve muoversi («palla»: tu, Claude o altri). Il briefing del mattino ti mostra quelli in scadenza.
- **Ciò che Claude sa di te**: `profilo-nucleo.md` (le regole sempre valide) e `profilo-completo.md` (registri ed esempi), nella cartella di Claude. Puoi leggerli e correggerli quando vuoi.
- **La mappa**: `mappa-inventario.md` dice dove stanno i lavori in corso e quali cartelle sono cambiate dal giorno prima; `mappa-archivio.md` elenca i lavori chiusi.
- **La salute del sistema**: `doctor.md`, aggiornato ogni mattina. Verde: tutto in ordine. Giallo: qualcosa da guardare, con la spiegazione. Rosso: qualcosa si è rotto.
- **La cartella riservata**, se l'hai indicata all'installazione: Claude non la legge mai.

## Connettori, abbonamento e login

- **Posta e calendario** passano dai connettori che attivi su claude.ai (Impostazioni → Connettori). Valgono anche per Claude Code, finché il login con il tuo abbonamento resta valido.
- **Se il login scade**, i giri automatici non leggono più posta e calendario e il controllo del mattino lo segnala. Rimedio: apri Claude Code e scrivi `/login`.
- **La quota dell'abbonamento** è una sola per claude.ai e Claude Code: le conversazioni nell'app, il lavoro nel terminale e i giri automatici la consumano insieme. `/usage` in Claude Code mostra quanto ne resta.
- Nei giri automatici Claude può **leggere** posta e calendario ma non inviare, rispondere o creare eventi.

## I giri automatici (se li hai attivati)

Al mattino il controllo del sistema e il briefing della giornata; durante il giorno la sistemazione di ciò che arriva nell'Inbox; la sera la sintesi della giornata; il lunedì il riepilogo della settimana. Girano **solo con il Mac acceso** agli orari scelti: se il Mac dorme, partono al risveglio; se è spento, quel giro salta. L'esito di ogni giro è una riga sotto «Memo» nella nota del giorno.

## Una volta al mese

Alla prima sessione del mese Claude ti propone tre elenchi brevi, a cui rispondi in una riga:
- gli impegni superati dai fatti, da chiudere;
- i lavori fermi da tempo, da archiviare o da tenere;
- le correzioni del mese, già trasformate in regole.

## Quando qualcosa non va

| Che cosa vedi | Che cosa fare |
|---|---|
| Il controllo del mattino è giallo o rosso | Chiedi a Claude «che cosa dice il doctor?»: legge il report e ti propone il rimedio |
| Claude non vede più posta o calendario | `/login` in Claude Code; se non basta, controlla su claude.ai che i connettori siano attivi |
| Un giro automatico è fallito | Il controllo del mattino dopo è rosso e rimanda al registro: chiedi a Claude di leggerlo |
| Manca la riga 🤖 di un giro nella nota del giorno | Il Mac era spento a quell'ora e il giro è saltato senza lasciare traccia: si può lanciare a mano chiedendolo a Claude («fai il briefing») |
| Claude scrive in un modo che non ti piace | Il gesto di correzione: «questo non va perché…, d'ora in poi…» |
| Claude ti chiede conferma troppo spesso, o troppo poco | Dillo: è una regola del profilo, nella sezione «Come lavoro con te» |
| Hai spostato o rinominato una cartella | Niente: la mappa se ne accorge il giorno dopo e, se un lavoro ha perso la sua cartella, propone il percorso nuovo |
