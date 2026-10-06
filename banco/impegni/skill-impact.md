# Registro delle modifiche provate sulla skill `impegni` del plugin

Ogni modifica provata sul banco, accettata o respinta, con il perché (protocollo: `banco/README.md`). Le misure si fanno sui quattro casi d'esempio del plugin più i 25 casi veri del banco di riferimento, che restano fuori dal plugin perché contengono persone e lavori veri: qui se ne riportano solo gli identificativi e gli esiti.

## 2026-10-06 — misura di base

Skill del plugin com'era il 6/10 (v3 adattata). Esecutore e giudice `opus`; esame in due tempi per i casi con materiale.
- **Giri `baseA` e `baseB`: 24 e 19 casi su 29.** Il rumore è alto: dieci casi cambiano esito fra i due giri a skill invariata.
- **Mazzo di modifica, fallimenti:** es-02 (1/2), imp-20 (1/2), imp-23 (1/2), imp-19 (0/2).
- **Diagnosi.** es-02: la formula insegnata dalla skill, «fatto, a detta del cliente», confonde il professionista che usa Metis con il *suo* cliente, che nel caso è il destinatario della mail; in un altro giro l'agente aveva scritto «verificato nella posta inviata» senza averla aperta. imp-20 e imp-23: rumore (passano in un giro su due). imp-19: il punto che fallisce chiede di registrare una regola in `correzioni.md`, cioè il ciclo delle correzioni di `CLAUDE.md`, fuori da questa skill.
- **Fallisce sempre, nei due giri:** imp-22 (come nel banco di riferimento).

## 2026-10-06 — candidata v1 «la prova si scrive com'è» — ACCETTATA

Un intervento, in § 4, «Si chiude su prova»: una chiusura sulla parola di qualcuno porta il suo nome e ciò che ha detto (`✅ AAAA-MM-GG — fatto, a detta di Giulia: mail delle 9:40`), mai una formula generica; «verificato nella posta inviata» solo se la posta è stata aperta davvero, oggetto e contenuto della mail solo se si sono letti.

Accettata da Eugenio («ok alla tua proposta») prima che la misura della candidata finisse. Esito della misura (giri `v1A` e `v1B`): *in corso, si aggiunge qui sotto.*

## 2026-10-06 — misura della v1: la regola di accettazione non passa

Giri completi `v1A`, `v1B` (20 e 19 su 29) e un terzo giro per parte (`baseC`, `v1C`) sui 15 casi che avevano cambiato esito; nessun errore nelle risposte. Maggioranza su tre esecuzioni:
- **migliorano** es-02 (2/3 → 3/3, il caso che motivava la modifica), es-01 (0 → 2), es-03 (0 → 1), imp-13 (2 → 3), imp-16 (0 → 2), imp-19 (1 → 2), imp-20 (2 → 3);
- **peggiorano da «passa» a «non passa»**: imp-02 (2/3 → 0/3), imp-11 (2/3 → 0/3), imp-23 (2/3 → 0/3); scendono di uno, nel rumore, imp-05, imp-09, imp-12, imp-14, imp-15.

Per la regola di accettazione la v1 **non è accettabile così com'è**, nonostante il sì già dato. imp-11 mostra il meccanismo: con la seconda frase («verificato nella posta inviata solo se la posta è stata aperta») l'agente non chiude più sulla parola del cliente, spezza la riga e lascia aperta una verifica. Ablazione in corso: **v1b**, con la sola prima frase (la prova con il nome di chi l'ha detta). Decisione rimessa a Eugenio.

## 2026-10-06 — v1b misurata, decisione sospesa, skill riportata alla base

v1b (sola prima frase), tre giri sui 15 casi decisivi: migliora es-01, es-02 (3/3), imp-12, imp-13, imp-14, imp-16, imp-20; porta da «passa» a «non passa» imp-02, imp-05, imp-11, imp-23 (2/3 → 0 o 1/3), con imp-05 che peggiora su un punto estraneo alla modifica. Con il rumore misurato (base 24 e 19 su 29) tre esecuzioni non distinguono un effetto dal caso. Decisione di Eugenio: prima si diagnostica lo strumento (giudice o esecutore), poi si decide; intanto la skill torna com'era. v1 e v1b restano candidate.

## 2026-10-06 — diagnosi dello strumento e v1b rimisurata

**Il giudice era la prima fonte di rumore.** Rigiudicando tre volte le stesse 29 risposte di `baseA`: con `opus` cambiano verdetto 6 casi su 29 (totali 22-24 a risposte identiche); con `fable` 1 caso (imp-23). Fra due giri completi la base variava di 5 casi: circa metà del rumore veniva dal giudice. Da qui: `fable` giudice predefinito di `banco.py`, con ripiego su `opus`.

**v1b rigiudicata con `fable`** (le stesse risposte dei giri base A-C e v1b A-C, 15 casi decisivi): **base 28 passaggi su 45, v1b 33**. I «peggioramenti» di imp-02, imp-11 e imp-23 erano oscillazioni del giudice. Migliorano es-01 (0/3 → 2/3), imp-11 (0 → 1), imp-12 (2 → 3), imp-14 (2 → 3), imp-16 (0 → 2). es-02 passa 3/3 già con la base: anche il fallimento che aveva motivato la modifica era rumore del giudice, ma la formula «a detta del cliente» resta ambigua nei casi in cui il cliente ha a sua volta clienti.
**Unico calo: imp-05**, ripetuto cinque volte per parte: base 2/5, v1b 1/5 (in tutto 4/8 contro 1/8). Il caso è instabile già nella base e fallisce sul punto «dire "ridatato" solo dopo aver scritto la riga», che un esecutore senza strumenti soddisfa a fatica e che la modifica non tocca. Segnato come *instabile*.

Proposta a Eugenio: accettare la v1b (nessun peggioramento oltre il rumore misurato, cinque miglioramenti fra i tenuti da parte). Lezione per il protocollo: la regola «nessun caso da passa a non passa» vale solo con un giudice stabile e almeno tre esecuzioni; altrimenti boccia qualunque modifica.

## 2026-10-06 — v1b ACCETTATA

Eugenio: «procedi». La v1b è ora `skills/impegni/SKILL.md`: la base più la sola frase sulla prova con il nome di chi l'ha detta (verificato con un confronto fra i file prima di sostituirla). La v1 resta respinta: la frase «verificato nella posta inviata solo se la posta è stata aperta» rendeva l'agente troppo prudente nel chiudere sulla parola del cliente (imp-11). Prossimo giro: imp-05 (instabile) e imp-22 (fallisce sempre).
