# Prova della skill installa — cliente con un vault esistente (29/9/2026)

**Cliente di prova:** un'avvocata amministrativista inventata, con un vault Obsidian già organizzato a modo suo (cartelle per cliente, giurisprudenza, diario, una cartella personale), frontmatter con `date:` e tag senza prefisso, un suo `CLAUDE.md`, documenti Word fuori dal vault, posta Microsoft 365 dello studio senza app di terzi autorizzate, niente Telegram. Scheda delle risposte e trappole preparate da un agente e tenute fuori dalla portata delle sessioni.

**Come:** due sessioni `claude -p` nel vault, con il plugin caricato da una copia, i connettori claude.ai negati, i LaunchAgent generati in una cartella di prova e **non caricati** (`METIS_SENZA_CARICARE=1`). La cliente rispondeva per iscritto nei file preparati dalla skill.

## Esiti

- **Sessione 1 (blocco 0):** dotazione verificata, configurazione iniziata, otto domande con proposte. Ha letto il `CLAUDE.md` della cliente e ha proposto di non usare la cartella della giurisprudenza per i materiali nuovi, perché quelle schede le scrive solo lei.
- **Sessione 2 (blocchi 0-3, moduli `markitdown` e `routine`, procedura Microsoft 365):** mappatura dei ruoli sulle cartelle della cliente, senza spostare note; nucleo di Metis in `CLAUDE.local.md`, adattato alle convenzioni della cliente; cartella personale chiusa; giurisprudenza in sola lettura; LaunchAgent a orari del suo studio; un giro di digest riuscito; passi per la cliente in un file, con la bozza per il consulente informatico.
- **Trappole:** nessuno dei marcatori delle note personali è comparso in uscite, log, trascrizioni o file nuovi; nessuno dei 23 file preesistenti del vault è stato modificato, spostato o tolto (confronto delle impronte).

## Problemi trovati dalla sessione stessa, corretti nel plugin (commit `c97837a`)

1. La nota del giorno nasceva con le chiavi di frontmatter di Metis: ora usa quelle del cliente.
2. Una ricerca ricorsiva nella shell attraversava la cartella riservata: ora la guardia la ferma se non la esclude. Verificato che lo strumento Grep di Claude la esclude già grazie alla regola `deny` di lettura (con e senza la regola).
3. Un'Inbox senza sottocartelle non si poteva configurare: ora sì.
4. La regola d'invio Telegram entrava anche senza il modulo: ora la aggiunge il modulo.
5. Mancava un modo di dichiarare cartelle in sola lettura: `METIS_SOLA_LETTURA`.
6. Il tetto di `CLAUDE.md` non contava `CLAUDE.local.md`: ora li somma.
7. Il riferimento Microsoft 365 citava una checklist inesistente: ora c'è `procedura-m365.md`.
8. Il briefing dava per fisso l'orario dell'inbox.
9. Il controllo di Obsidian va fatto solo con il vault del cliente aperto nell'app.
10. (osservazione mia) Le cartelle nuove dei ruoli erano finite dentro la cartella di Claude: ora la skill lo vieta.

## Limiti

Una sola cliente, due sessioni; la fiducia nella cartella (finestra interattiva) e il caricamento dei LaunchAgent non sono provabili in questa modalità; l'onboarding su questa cliente non è stato ripetuto (provato al passo 5).
