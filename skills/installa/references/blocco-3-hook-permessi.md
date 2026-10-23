# Blocco 3 — hook e permessi

**Esito:** alla sessione nuova Claude riceve l'orientamento e lavora senza richieste di permesso; la cartella riservata e le cartelle delle credenziali sono chiuse; le azioni irreversibili e gli invii chiedono conferma.

## Gli hook

Sono dichiarati dal plugin e si attivano con lui, solo dentro il vault configurato:
- **orientamento** all'avvio (profilo, stato attuale, segnali del doctor; dopo una compattazione, la traccia di che cosa si stava facendo);
- **guardia** prima di ogni strumento: blocca la cartella riservata, anche le ricerche nella shell che la attraverserebbero senza escluderla (gli strumenti Grep e Glob la escludono già grazie ai permessi); chiede conferma per cancellazioni ricorsive, cestino di Obsidian, push e reset di git, scaricamento delle automazioni; chiede conferma per ogni invio di posta o messaggi (le bozze passano); blocca `sudo`;
- **validazione** dopo ogni scrittura di una nota: avvisa Claude se mancano le chiavi del frontmatter o un prefisso dei tag;
- **traccia prima della compattazione**.

## I permessi

`bash scripts/installa-permessi.sh` scrive:
- in `<vault>/.claude/settings.json` le regole per le sessioni con il cliente: modalità `bypassPermissions`, cioè **nessuna richiesta di permesso** (la stessa di `--dangerously-skip-permissions`; con `METIS_PERMESSI=con-richieste` si torna ad `acceptEdits`), lettura dei riferimenti del plugin, lettura e scrittura della cartella fonti solo se sta fuori dal vault (`METIS_DOCUMENTI=separati`: è l'unica cartella aggiuntiva, `additionalDirectories`; con i documenti accanto alle note, il default, sta già nel vault e non serve nessuna regola), i comandi ammessi per nome, i divieti (`sudo`, cancellazioni della home, cartella riservata, cartelle delle credenziali del Mac come `~/.ssh` e i portachiavi, scrittura nelle cartelle in sola lettura di `METIS_SOLA_LETTURA`). I divieti valgono anche senza richieste di permesso. Le regole del cliente restano; la prima volta si salva una copia del file com'era;
- la copia per le routine automatiche, che la passano a Claude Code con `--settings`: lì la modalità resta `acceptEdits`, con gli strumenti ammessi per nome.

**Perché senza richieste** (decisione del 6/10/2026). Con le sole regole che ammettono i comandi per nome, una giornata tipo di otto richieste ha prodotto 12 richieste di permesso: comandi di shell composti, script del plugin, connettori, l'orientamento iniziale. Senza richieste la stessa giornata è passata con un solo blocco, voluto (una ricerca che attraversava la cartella riservata). Le protezioni non dipendono dalle richieste: i divieti tengono, e la guardia blocca la cartella riservata e `sudo` e chiede conferma per invii, cancellazioni ricorsive e push.

**Da dire al cliente**: in questa modalità Claude può leggere i file del Mac fuori dal vault, tranne le cartelle vietate. Se il cliente non lo vuole, `METIS_PERMESSI=con-richieste` e si rilancia `installa-permessi.sh`. **Da verificare alla prima installazione**: se Claude Code, all'apertura in questa modalità, mostra un avviso da accettare; con un abbonamento Team o Enterprise l'amministratore può aver disattivato la modalità.

## La fiducia nella cartella

Claude Code applica le regole di `.claude/settings.json` solo dopo che il cliente ha aperto Claude Code nel vault e ha accettato la finestra di fiducia. Si chiede al cliente di chiudere Claude Code, aprirlo di nuovo nel vault (`cd "<vault>" && claude`) e accettare. Le routine automatiche non ne dipendono, perché ricevono le regole con `--settings`.

**Controllo**, nella sessione nuova:
1. compare l'orientamento con il profilo (all'inizio con i punti da compilare);
2. se c'è una cartella riservata: si chiede a Claude di leggere un file al suo interno; l'esito atteso è il blocco;
2b. si chiede a Claude di elencare i file del vault: nessuna richiesta di permesso;
3. si chiede a Claude di scrivere una nota di prova senza frontmatter nell'Inbox; l'esito atteso è l'avviso, poi la nota si corregge o si toglie.
