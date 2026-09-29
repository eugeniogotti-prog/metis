# Lo stato dell'onboarding

Si crea all'inizio della prima sessione di onboarding come `stati/onboarding.md`, con questo testo. `{{Nome}}` è il nome del cliente (dalla prima riga di `profilo-nucleo.md`, o dall'installazione); `{{data}}` è la data del giorno; `{{istanza}}` è `cli`.

```markdown
---
thread: onboarding
name: Onboarding
status: attivo
ultima-mossa: '{{data}}'
prossima-azione: 'Fase 1: profilo'
scadenza: nessuna
persone: []
created_at: '{{data}}'
updated_at: '{{data}}'
tags:
- tipo/appunti
up:
- '[[_Claude]]'
---

# Stato — Onboarding

## Obiettivo e perché
**Obiettivo (finale):** Claude conosce {{Nome}} (profilo), i suoi lavori in corso (stati, dominio, persone) e il modo in cui {{Nome}} lo corregge.
**Perché conta:** da qui in avanti il sistema migliora con le correzioni di {{Nome}}; senza profilo e senza gesto di correzione ogni sessione riparte da zero.
**Successo osservabile:** il profilo è compilato e {{Nome}} lo riconosce come suo; almeno un lavoro ha il suo stato; un primo caso di correzione è registrato con il gesto.
**Cosa NON è:** riorganizzare il vault o spostare note; installare automazioni (lo fa l'installazione).

**Tappe** (una tappa chiusa si scrive `fatto · YYYY-MM-DD`):
1. Profilo (fase 1) · {{Nome}} conferma il nucleo e la pagina completa · da fare
2. Lavori, domini, persone (fase 2) · {{Nome}} rilegge lo stato del lavoro pilota · da fare
3. Patto e gesto di correzione (fase 3) · un caso in correzioni.md fatto con il gesto · da fare

## Dove siamo
- Onboarding da cominciare.

## Impegni

## Log
<!-- Consenso alla lettura dei documenti, osservazioni sui documenti letti (senza passi copiati), sezioni del profilo cancellate con il motivo, domande rimaste per la sessione successiva. -->

<!-- aggiornato da {{istanza}} {{data}} -->
```

Il tag `argomento/` si aggiunge a fine fase 2, quando i temi esistono.
