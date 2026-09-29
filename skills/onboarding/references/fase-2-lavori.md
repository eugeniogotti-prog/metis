# Fase 2 — lavori, domini, persone

**Precondizioni:** fase 1 fatta; connettori di posta e calendario collegati, se il cliente li ha scelti (blocco 5).

Esito: almeno uno stato in `stati/` con obiettivo e impegni a norma; una scheda in `dominio/`; le note delle persone del primo lavoro; i temi per i tag al posto del segnaposto `COMPILARE` in `CLAUDE.md`.

## 1. Scegliere il lavoro pilota

Si parte da **un solo lavoro vivo**: un incarico in corso, con documenti, scadenze e interlocutori. Meglio un lavoro di qualche settimana che un'intera area di attività.

- **Se posta e calendario sono collegati**: Claude chiede il permesso («posso leggere gli oggetti e i mittenti delle mail e le riunioni delle ultime tre settimane, per proporti i lavori da cui partire?»). Con il sì, propone i tre lavori più presenti, ciascuno in una riga con gli interlocutori, e il cliente sceglie. Il corpo dei messaggi si legge solo per il lavoro scelto.
- **Se non sono collegati**: si chiede al cliente di indicare il lavoro e di mettere in una cartella i documenti principali (fonti su disco). La cartella resta dov'è.

## 2. Lo stato del lavoro

Si crea `stati/<nome-del-lavoro>.md` dal modello di stato.

1. **Obiettivo e perché**, con il metodo bozza e reazione (skill `definizione-obiettivi`, se c'è; altrimenti come segue): Claude scrive la bozza della sezione ricavando dai documenti obiettivo, destinatario, vincoli e confine; marca come ipotesi «Perché conta» e «Successo osservabile», che solo il cliente può dire; chiede una cosa alla volta.
2. **Dove siamo**: tre-cinque righe dai documenti più recenti, lette per intero. Ogni fatto porta la sua fonte; ciò che è dedotto si dichiara.
3. **Impegni**: le cose da fare che emergono, nel formato scritto nel commento della sezione `## Impegni` del modello di stato. Un'attesa (`palla:loro`) solo se il cliente dice di aspettare una risposta, se serve un'approvazione per procedere o se c'è una scadenza esterna vera; ogni attesa con la sua data di decadenza.
4. **Attori e documenti prodotti**, con i link.

Il cliente rilegge lo stato. È anche il momento di mostrargli come lo userà: all'inizio di un lavoro Claude apre lo stato; alla fine della sessione lo aggiorna.

## 3. La prima scheda di dominio

Il dominio è la conoscenza di merito che serve al lavoro pilota: la norma o il regolamento su cui si lavora, le regole del settore, come funziona il sistema del cliente. Si crea `dominio/<materia>.md` con poche asserzioni, ciascuna con:
- la fonte primaria (documento, articolo, pagina);
- il grado di verifica: `[verificato]` se Claude ha letto il passo nella fonte, `[inferito]` se lo deduce, `[da verificare]` se viene da una fonte derivata o dalla memoria;
- la data.

Si chiede al cliente quali tre cose del suo campo un collaboratore nuovo sbaglia più spesso: diventano le prime asserzioni, verificate sulla fonte, oppure le prime «distinzioni da non confondere» della pagina completa del profilo (sezione 4), insieme a quelle annotate in fase 1.

Nella stessa occasione si completano le sezioni 3 e 4 della pagina completa: come si citano e si verificano le fonti del suo campo, gli errori che cerca quando rivede, le distinzioni da non confondere. Si cancellano i loro commenti `COMPILARE`.

## 4. Le persone

Per ogni interlocutore diretto del lavoro pilota, una nota nella cartella delle persone, dal modello di nota persona se c'è. Campi minimi, anche senza modello: frontmatter standard; ruolo e organizzazione; come il cliente si rivolge alla persona (nome, registro, canale); una tabella «Interazioni chiave» con data e contesto, con la prima riga. Niente note per chi è citato di sfuggita.

## 5. I temi per i tag

In `CLAUDE.md` il segnaposto `{{COMPILARE: i temi del lavoro}}` si sostituisce con i temi dei lavori emersi: tre-sei parole, in minuscolo salvo gli acronimi, che diventano i tag `argomento/`. Si propone l'elenco, il cliente corregge. Se il cliente usa già dei tag nel vault, si parte dai suoi.

## 6. Controlli di fine fase

- Lo stato del lavoro pilota esiste, `grep -c '{{'` su di esso dà zero, e ha una sola sezione `## Impegni` con righe a norma (il doctor le controlla, se è installato: sezione «Lavori» del report).
- `grep COMPILARE` su `CLAUDE.md` e su `profilo-completo.md`: nessun risultato.
- Ogni asserzione della scheda di dominio ha fonte, grado di verifica e data.
- Autorevisione, livello 1.
- Stato `onboarding.md`: tappa 2 `fatto · YYYY-MM-DD`; «Lavori attivi» e contatori di `_Claude.md` aggiornati.
