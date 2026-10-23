---
name: daily-digest
description: Il digest della giornata nella nota del giorno. Al mattino il briefing (calendario, posta da gestire, impegni in scadenza, lavori, documenti mossi, Inbox, domani con mini-briefing); la sera «La giornata» (che cosa è entrato e perché conta, che cosa si è mosso, il filo del giorno, tre domande per il diario). Gira da solo alle 7 e alle 21 (modulo routine) o su richiesta. Trigger: "daily digest", "briefing", "com'è la giornata", "riepilogo del giorno", "la giornata".
---

# Daily digest

Due momenti con due scopi. Il mattino serve a decidere che cosa attaccare; la sera serve ad assimilare ciò che è passato.

## Modalità

- **Mattino** (prima delle 14, o «modalità mattino» nella richiesta): questo file.
- **Sera** (dalle 14, o «modalità sera»): `references/sera.md`. Le regole su ricerca, posta programmata e copertura qui sotto valgono anche la sera.

## Dove sono le cose

Cartelle dalla tabella dei ruoli in `CLAUDE.md`; stati dei lavori in `stati/` nella cartella di Claude (esclusa `stati/archivio/`); nota del giorno nella cartella delle note giornaliere, `YYYY-MM-DD.md` (se manca: dal modello di nota giornaliera, o con il solo frontmatter e `# Memo`).

**Come si cerca nel vault.** Con `grep` e Read sui file. Niente `obsidian search`: può restituire zero risultati con uscita 0 anche per un termine presente in molti file, e un «non trovato» diventa indistinguibile da un guasto.

## Mattino: le fonti

| Fonte | Come | Se non risponde |
|---|---|---|
| calendario oggi e domani | strumenti del calendario (connettore o server locale in sola lettura) | «calendario non letto: motivo» |
| posta ricevuta nelle ultime 24 ore | strumenti della posta; leggere il corpo delle mail ambigue | «posta non letta: motivo» |
| impegni | righe `- [ ]` nella sezione `## Impegni` di ogni stato | — |
| lavori | stati con `scadenza:` entro 7 giorni | — |
| documenti | file modificati da ieri nelle cartelle di lavoro (sotto) | «documenti: motivo» |
| Inbox | note in attesa per sottocartella | — |

Una fonte che non risponde si dichiara. Niente riunioni, mail o eventi dedotti per riempire un vuoto.

**Posta.** Da gestire: persone reali con una richiesta. Newsletter notevoli: solo il titolo. Promozioni e notifiche: fuori. Prima di mettere una mail fra quelle da gestire, controllare nel thread se il cliente ha già risposto.

**Mail programmate.** Una mail fra le inviate con la data nel futuro è un invio programmato: si scrive «programmata per il …» e la richiesta resta da gestire finché la data non è passata. Contarla come inviata fa sparire dal briefing una cosa che il destinatario non ha ancora ricevuto.

**Documenti.** Si guarda solo nelle cartelle di lavoro del cliente, lette dalla configurazione caricata (`bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; echo "$METIS_DOCUMENTI|$METIS_FONTI"' "${CLAUDE_PLUGIN_ROOT}"`), perché i default li calcola `config.sh` e `configura.sh get` non li conosce:
- con i documenti accanto alle note (`METIS_DOCUMENTI=accanto`, il default): le cartelle dei progetti e delle aree del vault (ruoli PROGETTI e AREE) e quella delle risorse; si cercano i file che non sono note (`-not -name '*.md'`), perché le note le coprono già le altre fonti del digest;
- con `METIS_DOCUMENTI=separati`: `METIS_FONTI`, la cartella fonti fuori dal vault;
- in entrambi i casi `METIS_MAPPA_RADICI`, se c'è: voci separate da «|»; si prendono quelle assolute fuori dal vault, saltando le cartelle d'archivio.

Una scansione su tutto il disco va in tempo scaduto e la sezione resta vuota. Ogni ricerca ha un tempo massimo (su macOS `timeout` non esiste):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/con-timeout.sh" 90 find -L "<cartella>" -maxdepth 5 -type f -mtime -2 -not -name '.*' -not -name '~$*'
```

Uscita 142 = tempo scaduto: nella copertura «documenti: scansione interrotta dopo 90 s», senza scrivere che non si è mosso niente. I file trovati si raggruppano per lavoro (`fonte-primaria:` dello stato, cioè la cartella del lavoro). Un file nuovo sciolto nella radice della cartella dei progetti o nell'Inbox si segnala a parte, con la destinazione proposta.

## Mattino: impegni e lavori (la sezione che vale di più)

1. `palla:me` con data passata o entro 7 giorni → «🎯 Fare adesso», per data. Se non c'è niente: «nessun impegno in scadenza».
2. `palla:loro` con `decade:` superata → «attese decadute da chiudere» (le chiude Claude alla prima sessione, skill `impegni`).
3. **Domani, prima dagli stati.** Cercare negli stati la data di domani in tutte le forme (`grep -nE "AAAA-MM-GG|\bG/M\b|\bGG/MM\b"` sui file di `stati/`, esclusa `archivio/`) e leggere le righe trovate. Incontri, telefonate e scadenze concordati e scritti negli stati ma assenti dal calendario vanno nella riga «Domani» con *(dagli stati, assente dal calendario)*: il calendario da solo li perde.
4. Per ogni evento di domani: cercare lo stato del lavoro collegato e le note con `grep -rli "parola chiave"` sulle cartelle del vault; se c'è materiale, un mini-briefing di 3-5 punti con i wikilink.

Urgenza: 🔴 oggi o domani · 🟡 entro 5 giorni · 🟢 il resto.

## Mattino: formato

Sotto `# Memo`, in coda a ciò che c'è già:

```markdown
### Briefing del mattino
**Oggi** · 09:30 Riunione X — [[nota]] · 15:00 Call Y
**Posta da gestire** · Nome — richiesta (in una riga) · Nome — risposta programmata per il 9/10
**🎯 Fare adesso** · 🔴 **cosa** — [[stato]] | data
**Lavori con scadenza vicina** · [[stato]] — scadenza
**Documenti mossi** · [[stato]] — 3 file nella cartella del lavoro
**Inbox** · 3 note — le lavora il prossimo giro dell'inbox (orari in `METIS_ORARI_INBOX_PROCESSOR`, default 9, 13, 17)
**Domani** · 10:00 Incontro Z — mini-briefing: … · telefonata con W (dagli stati, assente dal calendario)
Copertura: calendario ✓ · posta ✓ · stati ✓ · documenti ✗ (scansione interrotta dopo 90 s) · inbox ✓
```

Telegrafico: una riga per voce; il dettaglio sta nelle note linkate.

## Copertura delle fonti

In fondo a ogni digest, mattino e sera, una riga sola con l'esito di ogni fonte letta (✓) o saltata (✗, con il motivo vero se si conosce). Una fonte saltata si dichiara sempre: il silenzio non distingue «non è successo niente» da «non ho guardato».

Nello stesso giro, per ogni fonte saltata, una riga appesa a `<cartella di Claude>/cache/digest-copertura.log` (creare `cache/` se manca; solo in coda):

```bash
printf '%s|%s|%s\n' "$(date +%F)" documenti "scansione interrotta dopo 90 s" >> "<cartella di Claude>/cache/digest-copertura.log"
```

Formato esatto `AAAA-MM-GG|fonte|motivo`, una riga per fonte, con nomi fissi (`calendario`, `posta`, `stati`, `documenti`, `inbox`, `note`) e un motivo su una riga senza «|». Il doctor legge il file e avvisa se la stessa fonte salta 3 giorni su 7: una dichiarazione che nessuno raccoglie resta senza seguito.

## Messaggio sul telefono (solo con il modulo Telegram)

Dopo aver scritto il briefing, un messaggio breve alla chat del cliente, con lo script del plugin: `python3 <cartella del plugin>/scripts/telegram/metis_telegram.py invia "testo"` (la cartella del plugin è scritta in testa al prompt del giro). Contenuto: la prima riunione, il primo impegno da fare adesso, quante mail da gestire. Se non c'è niente di rilevante, non si manda.

## Regole

- Il digest legge e segnala: non chiude impegni e non modifica stati.
- Si scrive nel registro del profilo del cliente (`profilo-nucleo.md`).
- Nel giro automatico il resoconto finale è di tre righe.
