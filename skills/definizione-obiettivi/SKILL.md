---
name: definizione-obiettivi
description: Avvia un lavoro nuovo e ne fissa l'obiettivo e il «perché». Cerca prima i precedenti nell'archivio (mappa-archivio.md, note delle persone), poi propone al cliente una bozza della sezione «## Obiettivo e perché» in cima allo stato del lavoro (`<cartella di Claude>/stati/<lavoro>.md`), dove la skill `autorevisione` la legge come metro per «centra l'obiettivo?». Metodo bozza e reazione, una domanda alla volta. Da invocare all'avvio di un lavoro sostanziale nuovo, prima di immergersi, oppure su richiamo per un lavoro esistente. Trigger: «definizione-obiettivi», «iniziamo un lavoro nuovo», «nuovo incarico», «definisci gli obiettivi», «qual è il perché di», «obiettivo del lavoro», «rivediamo l'obiettivo», «carta del perché».
---

# Definizione degli obiettivi

Questa skill dà a Claude l'orizzonte di un lavoro: **perché** il cliente lo vuole, **come si vede il successo** e **dove sta il confine**. Il «che cosa fare» è già nella richiesta. La sezione che ne esce è il metro con cui la skill `autorevisione` controlla «centra l'obiettivo?»: senza, quel controllo non ha contro che cosa misurarsi.

## I due principi

1. **Il perché è del cliente.** Dai documenti Claude può ricavare obiettivo, destinatario, vincoli e confine; il perché profondo vive nella testa del cliente. Estrarlo dai documenti produce una frase plausibile e vuota, cioè un'inferenza presentata come fatto. Per questo il perché si chiede, in dialogo.
2. **Dal basso.** Si parte dal perché di un lavoro concreto. Ciò che resta costante fra un lavoro e l'altro (la «Carta del perché», sotto) si accumula dai perché dei singoli lavori.

## Dove vive l'obiettivo

Nella sezione `## Obiettivo e perché`, la prima dello stato del lavoro: `<cartella di Claude>/stati/<lavoro>.md`. La cartella di Claude è quella del ruolo CLAUDE della configurazione (di default `_Claude`); il valore si legge con `bash "${CLAUDE_PLUGIN_ROOT}/scripts/configura.sh" get METIS_RUOLO_CLAUDE`.

- Per un lavoro **nuovo**, è la sezione che fa nascere lo stato.
- Per un lavoro **esistente**, la si ritocca lasciando intatto il resto dello stato.
- Obiettivo e perché si cambiano solo con questa skill, mai negli aggiornamenti ordinari dello stato. Le **tappe** sono la sola parte che si aggiorna man mano.

## Il modello della sezione

Il modello di stato (`stati/_template-stato.md`) contiene i quattro campi di base. Gli altri si aggiungono quando servono; un campo che non si applica si omette.

```
## Obiettivo e perché
<!-- Obiettivo e perché: stabili, si cambiano con la skill definizione-obiettivi. Tappe: si aggiornano man mano. -->
**Obiettivo (finale):** che cosa deve essere vero alla fine, in una frase.

**Perché conta:** che cosa cambia se riesce, perché il cliente ci tiene, dove si inserisce nella sua attività.

**Successo osservabile:** 1-3 segni concreti che dicono «centrato».

**Criteri di verifica:** condizioni controllabili una per una, proprie di questo lavoro (es. «tratta la clausola di recesso», «usa i dati di bilancio dell'ultimo esercizio approvato», «risponde all'obiezione del collegio sindacale sul punto 3»).

**Destinatario:** chi riceve e giudica il risultato.

**Vincoli:** i paletti non negoziabili.

**Cosa NON è:** il confine, ciò che resta fuori anche se sembra vicino.

**Tappe e verifiche intermedie:** i punti in cui il cliente controlla l'avanzamento, distinti dai prossimi passi operativi di «Dove siamo». Per ogni tappa: che cosa consegna · che cosa il cliente verifica · stato (da fare / in corso / fatta).
```

Corto: la sezione è un metro e va letta in un minuto.

## Il flusso

### 1. Cercare i precedenti (lavoro nuovo: obbligatorio)

Prima di scrivere una riga dell'obiettivo si cerca se il cliente ha già fatto un lavoro simile. Un precedente porta documenti, persone, errori già fatti e scelte già prese; ignorarlo significa rifare da capo.

- **Dove:** `<cartella di Claude>/mappa-archivio.md`, generata da `scripts/mappa.py` (la lancia il doctor). Contiene gli stati archiviati con oggetto, data di chiusura, persone e cartella su disco; i lavori nell'archivio del vault; le cartelle su disco dei lavori chiusi e degli anni passati. Se manca o è vecchia di giorni, la si rigenera:
  ```
  bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; python3 "$0/scripts/mappa.py"' "${CLAUDE_PLUGIN_ROOT}"
  ```
- **Che cosa cercare:** per cliente o committente, per tema, per persone coinvolte. Si cerca con più parole (nome dell'ente, sigla, materia, cognomi), perché lo stesso lavoro può essere stato chiamato in modi diversi.
- **Se serve, le note delle persone** (cartella del ruolo PERSONE, `configura.sh get METIS_RUOLO_PERSONE`): la tabella «Interazioni chiave» di un interlocutore del lavoro nuovo può citare lavori passati che la mappa non lega a quel nome.
- **Se c'è un precedente:** si apre il suo stato archiviato (obiettivo, ultime voci del log, lezioni); lo si scrive nel frontmatter dello stato nuovo in `precedenti: ['[[nome-stato-archiviato]]']`; lo si cita nella bozza dell'obiettivo («riprende…», «si distingue da… perché…»).
- **Se non c'è:** lo si dice al cliente nominando dove si è cercato e con quali parole («nessun precedente in mappa-archivio.md per "fusione", "Rossi Srl", "Bianchi"; note persone di Bianchi senza lavori passati»). Un «nessun precedente» senza i luoghi della ricerca non vale come verifica.

### 2. Raccogliere il contesto

Lo stato del lavoro se esiste, i documenti pertinenti, la richiesta del cliente, la cartella su disco del lavoro se c'è.

### 3. Scrivere la bozza

Claude bozza l'intera sezione, ricavando ciò che può: obiettivo, destinatario, vincoli, confine, criteri di verifica. **«Perché conta» e «Successo osservabile» si marcano come ipotesi** (per esempio `[ipotesi, da confermare]` in coda alla riga) finché il cliente non li conferma: sono le due cose che solo lui può dire.

### 4. Bozza e reazione

Si presenta la bozza e si raccoglie la reazione. Il cliente corregge, Claude recepisce. Sui buchi **una domanda alla volta**, concreta, mai un elenco di domande: reagire a una proposta costa meno che scrivere da zero, e una raffica di domande si risolve in risposte affrettate.

### 5. Scrivere lo stato

Al via del cliente:
- **lavoro nuovo:** si crea `stati/<lavoro>.md` copiando il modello `stati/_template-stato.md`. Si compilano il frontmatter (`thread`, `name`, `status`, `ultima-mossa`, `prossima-azione`, `created_at`, `updated_at`) e in più:
  - `fonte-primaria:` la cartella su disco del lavoro, se c'è (vuota altrimenti);
  - `persone:` i wikilink alle note delle persone coinvolte; se una persona entra nel lavoro e la nota manca, la si crea (regola «Persone» di `CLAUDE.md`);
  - `precedenti:` quanto trovato al passo 1.
  Poi la sezione `## Obiettivo e perché` confermata, «Dove siamo» e gli impegni nel formato del commento di `## Impegni` del modello, e la riga del marcatore in fondo.
- **lavoro esistente:** si sostituisce solo la sezione `## Obiettivo e perché` e si aggiorna `updated_at`.

Le ipotesi confermate perdono il marcatore; quelle che il cliente lascia aperte lo tengono, e l'autorevisione le tratta come metro provvisorio.

## Quando si usa

- **Lavoro nuovo sostanziale:** all'avvio, prima di immergersi. Bastano pochi minuti. Non per i compiti banali.
- **Richiamo su un lavoro esistente:** «rivediamo l'obiettivo», «qual è il perché di X».
- **Buco segnalato dall'autorevisione:** se la lente «centra l'obiettivo?» non trova la sezione per il lavoro in corso, lo dice e propone questa skill.

## Composizione con `autorevisione`

La skill `autorevisione`, prima di ogni consegna sostanziale, legge la sezione `## Obiettivo e perché` del lavoro e misura il risultato a tre livelli:
1. contro i **criteri di verifica**, uno per uno, se ci sono (controllo analitico);
2. contro il **successo osservabile** della tappa che il risultato serve (giudizio d'insieme);
3. contro l'**obiettivo finale** (la tappa lo fa avanzare?), più il confine «Cosa NON è».

Questa skill fissa il metro, quella lo usa.

### Guardia contro la surrogazione

I criteri di verifica rendono ripetibile il controllo, con un rischio: la lista diventa il bersaglio al posto dello scopo. Perciò:
- i criteri affiancano il giudizio d'insieme sul successo osservabile, che resta il metro principale;
- l'autorevisione riporta **due verdetti separati**: quali criteri sono soddisfatti o mancanti, e se il lavoro risponde allo scopo, anche quando tutti i criteri risultano soddisfatti;
- «tutti i criteri soddisfatti, ma il lavoro non risponde allo scopo» è un rilievo grave, da trattare come tale;
- registro, tono, che cosa tacere a quel destinatario restano fuori da ogni lista: lì decide il giudizio, e la chiusura resta del cliente.

## Alla chiusura del lavoro

Il giro di chiusura è nella skill `archiviazione`. Al suo passo «Distillare», oltre al merito e alle regole di metodo, si chiede anche: *il perché di questo lavoro e ciò che ha insegnato dicono qualcosa che vale anche per i lavori futuri?* Se sì, va nella Carta del perché (sotto) o in una scheda di `dominio/`. Lo stato, con la sua sezione d'obiettivo, va poi in `stati/archivio/` con il resto, ed entra in `mappa-archivio.md`, dove il passo 1 di questa skill lo ritroverà.

## La Carta del perché

`<cartella di Claude>/carta-del-perche.md` raccoglie l'**approccio costante del cliente** da un lavoro all'altro: metodo, criteri, il modo in cui guarda un problema. Gli obiettivi cambiano con ogni lavoro e vivono negli stati; la Carta tiene ciò che resta. In buona parte coincide con le domande di revisione del profilo completo (sezione 4 di `profilo-completo.md`) e con lo stile di lavoro del cliente.

- **Si crea al primo distillato trasversale**, a una chiusura di lavoro: un file vuoto inviterebbe a riempirlo per astrazione, cioè a inventare.
- **Cresce dal basso**, notando che cosa ricorre fra i perché dei lavori e le lezioni delle chiusure.
- **Cresce sotto gli occhi del cliente:** ogni modifica gli si sottopone per reazione, e quando cambia in modo sostanziale lo si avvisa.

## Errori da evitare

- Partire con l'obiettivo senza aver cercato i precedenti, o dire «nessun precedente» senza dire dove si è guardato.
- Scrivere il «Perché conta» come un fatto: finché il cliente non lo conferma è un'ipotesi e lo si marca.
- Interrogare a foglio bianco o con un elenco di domande: si propone una bozza e si chiede una cosa alla volta.
- Ritoccare obiettivo e perché durante un aggiornamento ordinario dello stato.
- Gonfiare la sezione con campi che non si applicano.
