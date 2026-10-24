# Blocco 0 — dotazione e scelte

**Esito:** la configurazione esiste con vault, cartella fonti e moduli scelti; i requisiti delle fondamenta e dei moduli scelti ci sono.

## 1. Il questionario

Una domanda alla volta, ciascuna con una proposta. Le risposte decidono i moduli. Se a installare è un professionista per conto del cliente, a queste domande risponde lui, con i default: il cliente serve solo per login, consensi e permessi, e il suo tempo è quello dell'avvio (skill `onboarding`, dieci minuti).
1. Il vault: ne ha già uno (dove) o se ne crea uno nuovo (dove)? Usa Obsidian?
2. I documenti di lavoro (PDF, Word, fogli). **Default (decisione del 23/10/2026): documenti e note insieme**, una cartella per lavoro dentro la struttura PARA del vault (`METIS_DOCUMENTI=accanto`, cartella fonti = cartella dei progetti): non c'è niente da chiedere. Solo se il cliente usa Obsidian e vuole un vault di sole note: `METIS_DOCUMENTI=separati` e una cartella fonti fuori dal vault (in quale cartella del disco stanno i documenti, o dove vuole tenerli?). In entrambi i casi l'installazione crea solo le cartelle dei ruoli (e, con `separati`, la cartella fonti): quelle dei lavori, con `_IN/`, `_fonti/` e `_OUT/`, nascono al primo lavoro (`CLAUDE.md`, «una cartella per lavoro»), e le cartelle che il cliente ha già non si riordinano. Se il cliente ha già i documenti in una cartella fuori dal vault e vuole passare ad «accanto», lo spostamento si fa lavoro per lavoro, con il suo sì, mai in blocco all'installazione.
3. Posta e calendario: Google (Gmail o Google Workspace), Microsoft 365, altro? Se l'account è aziendale, l'amministratore consente le app di terzi?
4. Telefono: usa Telegram? Vuole ricevere il riepilogo del mattino sul telefono, mandare cose al vault dal telefono, parlare con Claude dal telefono?
5. Voce: vuole dettare note vocali che diventano note nel vault?
6. Il Mac resta acceso di giorno? (Le routine automatiche girano solo a Mac acceso.)
7. Ha una cartella che Claude non deve mai leggere? E cartelle che Claude può leggere ma non deve modificare (per esempio schede scritte solo da lui)?

Proposta dei moduli dalle risposte:

| Risposta | Modulo |
|---|---|
| documenti PDF o Word | `markitdown` |
| Google | `google` |
| Microsoft 365 aziendale | `microsoft` (connettore di claude.ai, con il consenso una tantum dell'IT: `procedura-m365.md`) |
| Telegram | `telegram` (uscita; con i messaggi al bot in Inbox e la conversazione se li vuole) |
| note vocali | `voce` (richiede `telegram`) |
| Mac acceso di giorno | `routine` (doctor, digest del mattino, inbox) |

## 2. La configurazione

```bash
bash scripts/configura.sh set METIS_VAULT "<vault>"
# solo con METIS_DOCUMENTI=separati (vault di sole note, per chi usa Obsidian):
# bash scripts/configura.sh set METIS_DOCUMENTI separati
# bash scripts/configura.sh set METIS_FONTI "<cartella fonti fuori dal vault>"
bash scripts/configura.sh set METIS_RUOLO_RISERVATA "<cartella riservata, relativa al vault, o vuoto>"
bash scripts/configura.sh set METIS_SOLA_LETTURA "<cartelle in sola lettura, relative al vault, separate da |, o vuoto>"
bash scripts/configura.sh set METIS_INBOX_FONTI "<sottocartelle dell'Inbox, separate da spazi; vuoto = nessuna>"
bash scripts/configura.sh aggiungi METIS_MODULI <modulo>     # una volta per modulo scelto
```

## 3. La dotazione

`bash scripts/verifica-dotazione.sh fondamenta <moduli scelti>`. Per ogni ❌ si dà al cliente il comando d'installazione indicato nella riga, e lo si lascia eseguire a lui (Homebrew chiede la sua password). Poi si rilancia la verifica.
- ⚠️ «chiave API esportata»: la variabile `ANTHROPIC_API_KEY` farebbe fatturare Claude Code sulla Console invece che sull'abbonamento. Il cliente la toglie dal suo profilo di shell; si riapre il terminale.
- ⚠️ Obsidian o la sua CLI mancanti: Metis funziona su una cartella di markdown, ma gli spostamenti non aggiornano i link. Lo si dice e si registra la scelta.

**Controllo:** `verifica-dotazione.sh fondamenta <moduli scelti>` esce con 0 (le righe ⚠️ accettate dal cliente restano scritte nello stato).
