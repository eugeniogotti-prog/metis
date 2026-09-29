# Blocco 3 — hook e permessi

**Esito:** alla sessione nuova Claude riceve l'orientamento; la cartella riservata è chiusa; le azioni irreversibili e gli invii chiedono conferma; i permessi sono preconfigurati senza saltare i controlli.

## Gli hook

Sono dichiarati dal plugin e si attivano con lui, solo dentro il vault configurato:
- **orientamento** all'avvio (profilo, stato attuale, segnali del doctor; dopo una compattazione, la traccia di che cosa si stava facendo);
- **guardia** prima di ogni strumento: blocca la cartella riservata, anche le ricerche nella shell che la attraverserebbero senza escluderla (gli strumenti Grep e Glob la escludono già grazie ai permessi); chiede conferma per cancellazioni ricorsive, cestino di Obsidian, push e reset di git, scaricamento delle automazioni; chiede conferma per ogni invio di posta o messaggi (le bozze passano); blocca `sudo`;
- **validazione** dopo ogni scrittura di una nota: avvisa Claude se mancano le chiavi del frontmatter o un prefisso dei tag;
- **traccia prima della compattazione**.

## I permessi

`bash scripts/installa-permessi.sh` scrive:
- in `<vault>/.claude/settings.json` le regole per le sessioni con il cliente: modalità `acceptEdits` (modifiche ai file del vault senza chiedere), lettura dei riferimenti del plugin, lettura e scrittura della cartella fonti, i comandi ammessi per nome, i divieti (`sudo`, cancellazioni della home, cartella riservata, scrittura nelle cartelle in sola lettura di `METIS_SOLA_LETTURA`). Le regole del cliente restano; la prima volta si salva una copia del file com'era;
- la copia per le routine automatiche, che la passano a Claude Code con `--settings`.

Niente `--dangerously-skip-permissions`: le regole ammettono ciò che serve, la guardia ferma il resto.

## La fiducia nella cartella

Claude Code applica le regole di `.claude/settings.json` solo dopo che il cliente ha aperto Claude Code nel vault e ha accettato la finestra di fiducia. Si chiede al cliente di chiudere Claude Code, aprirlo di nuovo nel vault (`cd "<vault>" && claude`) e accettare. Le routine automatiche non ne dipendono, perché ricevono le regole con `--settings`.

**Controllo**, nella sessione nuova:
1. compare l'orientamento con il profilo (all'inizio con i punti da compilare);
2. se c'è una cartella riservata: si chiede a Claude di leggere un file al suo interno; l'esito atteso è il blocco;
3. si chiede a Claude di scrivere una nota di prova senza frontmatter nell'Inbox; l'esito atteso è l'avviso, poi la nota si corregge o si toglie.
