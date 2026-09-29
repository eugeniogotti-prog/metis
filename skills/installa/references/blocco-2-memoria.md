# Blocco 2 — memoria

**Esito:** i file della memoria a tre livelli sono nel vault e nella memoria di Claude Code, sotto i loro tetti.

1. `bash scripts/installa-modelli.sh templates/memoria "<Nome del cliente>"` (percorsi relativi alla cartella del plugin). Copia i modelli (profilo, stato attuale, regole di metodo, correzioni, `CLAUDE.md`, indice delle memorie), sostituisce i segnaposto dalla configurazione e lascia quelli `COMPILARE` all'onboarding. Un file che esiste già non si sovrascrive: lo script lo dice.
2. **`CLAUDE.md` già presente** (vault esistente): lo script lo lascia com'è e installa il nucleo di Metis come `CLAUDE.local.md`, che Claude Code carica insieme al primo (verificato con la versione 2.1.284). Si dice al cliente che i due file valgono insieme e che, dove si contraddicono, si decide con lui quale regola resta.
3. Una cartella che contiene il vault, se ha un suo `CLAUDE.md`, viene caricata anche lei da Claude Code: lo si controlla (`ls "<vault>/.."/CLAUDE.md`) e lo si dice al cliente.
4. Si crea lo stato `stati/installazione.md` (vedi `SKILL.md`) dal modello di stato, che lo script ha copiato in `stati/_template-stato.md`. `decisioni.md`, `routine-fine-sessione.md` e `protocollo-propagazione.md` entrano nei modelli del plugin quando saranno allineati alla memoria a tre livelli (vedi il README dei modelli).

**Controllo:** lanciare il doctor; la sezione «Tetti del contesto» ha sei righe ✅. L'avviso «Onboarding non finito» è atteso: lo chiude il blocco 4.
