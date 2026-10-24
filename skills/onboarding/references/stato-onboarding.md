# Lo stato dell'onboarding

Si crea all'inizio dell'avvio come `stati/onboarding.md`, con questo testo. `{{Nome}}` è il nome del cliente (dalla prima riga di `profilo-nucleo.md`, o dall'installazione); `{{data}}` è la data del giorno; `{{istanza}}` è `cli`.

```markdown
---
thread: onboarding
name: Onboarding
status: attivo
ultima-mossa: '{{data}}'
prossima-azione: 'Avvio in dieci minuti'
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
**Obiettivo (finale):** Claude lavora con {{Nome}} dal primo giorno e impara il resto dalle sue correzioni.
**Perché conta:** l'avvio costa dieci minuti; senza profilo minimo, senza un lavoro e senza il gesto di correzione ogni sessione riparte da zero.
**Successo osservabile:** nel profilo non restano sezioni AVVIO; esiste lo stato di un lavoro vivo; {{Nome}} conosce il gesto «questo non va perché…, d'ora in poi…».
**Cosa NON è:** compilare tutto il profilo, leggere i documenti d'esempio, riorganizzare le cartelle.

**Tappe** (una tappa chiusa si scrive `fatto · YYYY-MM-DD`):
1. Avvio · nessuna sezione AVVIO nel profilo e uno stato di lavoro · da fare
2. Revisione delle regole di partenza · alla prima sessione del mese, nessun `[di partenza]` rimasto · da fare

## Dove siamo
- Avvio da cominciare.

## Da completare nell'uso
<!-- Voci rimandate: si fanno solo quando servono (skill onboarding, «Nell'uso, solo se necessario»). Non sono impegni: niente data, palla o promemoria. Una voce fatta si spunta con la data. -->
- [ ] Sezioni vuote del profilo · alla prima occasione in cui un compito ne ha bisogno
- [ ] Stile dai documenti d'esempio · solo se {{Nome}} lo chiede o se le correzioni di stile si ripetono
- [ ] Prima scheda di dominio · alla prima norma o fonte del campo usata in un lavoro
- [ ] Temi per i tag · quando i lavori ne mostrano tre o più ricorrenti

## Impegni

## Log
<!-- Dove stanno i file del cliente, esito della prova di posta e calendario, sezioni del profilo cancellate con il motivo, consenso alla lettura dei documenti se un giorno servirà. -->

<!-- aggiornato da {{istanza}} {{data}} -->
```

Il tag `argomento/` si aggiunge quando i temi esistono.
