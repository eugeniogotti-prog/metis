# Banco di prova delle skill

**Il problema che risolve.** Una skill corretta dopo un errore sembra migliorata, ma nessuno controlla due cose: che risolva davvero il caso, e che non peggiori quelli vecchi. Il banco lo misura: ogni skill arriva con i suoi casi, e una modifica entra solo se il banco dice che migliora senza rompere niente.

## Dove stanno le cose

```
<plugin>/banco/<skill>/              casi d'esempio, inventati: mostrano come si scrive un caso
<cartella di Claude>/banco-skill/<skill>/
  INDICE.md                          elenco dei casi del cliente, con il mazzo di appartenenza
  casi/<id>.md                       un caso per file: situazione, compito, errore di allora, criterio
  esiti/<etichetta>/                 risposte, verdetti e RIEPILOGO.md di ogni giro
  skill-impact.md                    registro delle modifiche provate: accettate e respinte, con il perché
```

I casi del cliente nascono dalle sue correzioni: quando un output sbagliato riguarda una skill, il caso si scrive con la situazione di allora, l'errore e il criterio con cui si riconosce la risposta giusta.

## Le regole

1. **Due mazzi.** *Modifica*: i casi che si guardano mentre si scrive una modifica alla skill. *Tenuto da parte*: i casi che chi modifica non guarda. Si sorteggiano una volta, circa uno su tre nel primo; il mazzo si segna in `INDICE.md`. Un caso nuovo, nato da una correzione, entra nel mazzo di modifica.
2. **Chi viene esaminato non tocca l'esaminatore.** Chi modifica la skill non cambia i casi, i criteri né le istruzioni del giudice. Un caso si corregge solo in un giro a parte, dichiarato, con il motivo scritto in `skill-impact.md`.
3. **L'esecutore vede solo la skill e il caso.** Riceve la skill, la «Situazione» e il «Compito per l'agente»; non vede l'errore di allora, il criterio, il vault né gli altri casi. Se il caso ha un «Materiale per l'esaminatore» (il risultato di una ricerca: una mail inviata, un file), l'esame è in due tempi: un modello separato controlla se la prima risposta dichiara la verifica che lo troverebbe, e solo allora l'esecutore riceve il materiale e scrive la risposta definitiva.
4. **Il giudice ha un criterio scritto.** Un revisore separato riceve il caso intero e la risposta, e per ogni punto del criterio dà *passa* o *non passa* citando la frase che lo giustifica. Un punto non scritto nel criterio non conta.
5. **Regola di accettazione.** Una modifica è candidata se risolve il caso che l'ha motivata, non fa passare a *non passa* nessun caso che prima passava (in nessuno dei due mazzi), ed è piccola: da uno a quattro interventi puntuali.
6. **Il cliente è il cancello finale.** Il banco gli dà un dato invece di un'impressione; la modifica entra solo con il suo sì.
7. **Ogni modifica provata va nel registro**, anche quelle respinte: data, caso, testo della modifica, esito prima e dopo, decisione e perché. Serve a non riproporre una modifica già scartata.

## Come si fa un giro

Con la configurazione caricata (come per gli altri script del plugin):
```bash
M="${CLAUDE_PLUGIN_ROOT}"
bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; shift; python3 "$0/scripts/banco.py" "$@"' "$M" x esegui impegni base
bash -c 'source "$0/scripts/lib/config.sh"; metis_carica_config; shift; python3 "$0/scripts/banco.py" "$@"' "$M" x giudica impegni base
```
1. **Misura di base**: tutto il banco con la skill attuale (`esegui` e `giudica`, etichetta per esempio `base`).
2. **Modifica**: si guardano solo i fallimenti del mazzo di modifica e si scrive la modifica più piccola che li risolve, in una copia della skill.
3. **Nuova misura**: tutto il banco con la copia (`--skill-file`), poi `confronta base candidata`.
4. **Proposta al cliente** con il confronto; con il suo sì la modifica entra nella skill. In ogni caso si scrive la riga in `skill-impact.md`.

Con `--esempi` si usano i casi d'esempio del plugin: servono a vedere il banco funzionare prima di avere casi propri.

**Il rumore conta**: l'esecutore è un modello, e lo stesso caso può passare una volta e fallire quella dopo. Un caso che cambia esito a skill invariata è *instabile*; se è decisivo, si esegue tre volte e si prende la maggioranza.

## Limiti

- Con poche decine di casi il banco dà indicazioni, non misure.
- Funziona sugli errori verificabili (formato, regole saltate, chiusure senza prova); poco sul gusto e sullo stile.
- L'esecutore lavora su un caso ricostruito: misura se la skill *insegna* la regola, non se una sessione vera la applica sotto carico.
- Ogni giro consuma la quota dell'abbonamento: circa due chiamate per caso, tre per i casi in due tempi.
