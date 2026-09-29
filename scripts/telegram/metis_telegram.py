#!/usr/bin/env python3
"""metis_telegram.py — il bot Telegram del cliente: uscita, messaggi nell'Inbox, conversazione con Claude, voce.

Comandi:
  invia [testo]         manda un messaggio alla chat del cliente (testo da argomento o da stdin); solo a quella chat
  trova-chat            legge gli ultimi messaggi arrivati al bot e stampa le chat private da cui vengono
  ascolta [--una-volta] ascolta il bot e smista ciò che arriva; --una-volta fa un solo giro (per le prove)

Che cosa fa l'ascoltatore con un messaggio della chat del cliente (gli altri si ignorano e si registrano nel log):
  - un file, una foto o un documento → salvato in <Inbox>/files, con una nota che lo descrive in <Inbox>/telegram;
  - un messaggio inoltrato, un messaggio fatto solo di un link, o un testo che comincia con «nota» → nota in <Inbox>/telegram;
  - un vocale → trascritto (modulo voce); se la trascrizione comincia con «nota» → nota in <Inbox>/voicenotes;
    altrimenti il testo trascritto entra nella conversazione;
  - ogni altro testo → conversazione: un giro `claude -p` nel vault, che riprende la conversazione precedente se è
    di meno di sei ore (con «/nuova» se ne comincia una nuova); la risposta torna nella stessa chat.

Configurazione: ~/.config/metis/config (METIS_VAULT, ruoli, METIS_LOG_DIR) e i segreti in file con permessi 600:
  ~/.config/metis/telegram   TOKEN=… e CHAT_ID=…
  ~/.config/metis/groq       KEY=…   (solo con il modulo voce)
Indirizzi dei servizi sostituibili per le prove: METIS_TELEGRAM_API (default https://api.telegram.org),
METIS_GROQ_API (default https://api.groq.com). Comando di Claude: METIS_CLAUDE (default «claude»).
Solo libreria standard di Python.
"""
import datetime, json, os, re, shutil, subprocess, sys, tempfile, time, urllib.parse, urllib.request, uuid

CFG_DIR = os.path.dirname(os.environ.get("METIS_CONFIG", os.path.expanduser("~/.config/metis/config")))
API = os.environ.get("METIS_TELEGRAM_API", "https://api.telegram.org").rstrip("/")
GROQ = os.environ.get("METIS_GROQ_API", "https://api.groq.com").rstrip("/")
CLAUDE = os.environ.get("METIS_CLAUDE", "")   # vuoto: dalla configurazione (METIS_CLAUDE), altrimenti «claude»
ORE_CONVERSAZIONE = 6
# Frasi che Whisper produce su audio vuoto o rumore: un vocale che si riduce a una di queste non si usa.
FRASI_WHISPER = re.compile(r"^\W*(grazie( a tutti| per (la visione|l'ascolto|aver guardato))?|sottotitoli .*|thank you( for watching)?\.?|you)\W*$", re.I)
MAX_MSG = 3900


# --- configurazione ---------------------------------------------------------------------------------------------
def leggi_kv(percorso):
    d = {}
    if os.path.exists(percorso):
        for riga in open(percorso, encoding="utf-8"):
            riga = riga.strip()
            if riga and not riga.startswith("#") and "=" in riga:
                k, v = riga.split("=", 1)
                d[k.strip()] = v.strip().strip('"').strip("'")
    return d


def config():
    c = leggi_kv(os.environ.get("METIS_CONFIG", os.path.join(CFG_DIR, "config")))
    c = {k: os.path.expanduser(v) for k, v in c.items()}
    vault = c.get("METIS_VAULT", "").rstrip("/")
    ruolo = lambda r, d: os.path.join(vault, c.get("METIS_RUOLO_" + r, d))
    global CLAUDE
    if not CLAUDE:
        CLAUDE = c.get("METIS_CLAUDE") or "claude"
    return {
        "vault": vault,
        "inbox": ruolo("INBOX", "0 - Inbox"),
        "log": os.path.join(c.get("METIS_LOG_DIR", os.path.expanduser("~/Library/Logs/metis")), "telegram.log"),
        "settings": os.path.join(CFG_DIR, "permessi-routine.json"),
        "stato": os.path.join(CFG_DIR, "telegram-stato.json"),
    }


def protetto(p):
    if os.path.exists(p) and (os.stat(p).st_mode & 0o077):
        raise SystemExit(f"{p}: permessi troppo larghi, servono 600 (chmod 600 {p})")
    return p


def segreti(nome):
    """Segreti del bot e della voce. Di default in ~/.config/metis/<nome>; la configurazione può indicare file
    esistenti da leggere a ogni uso, senza copiarli: METIS_TELEGRAM_TOKEN_FILE e METIS_TELEGRAM_CHAT_FILE (un valore
    per file), METIS_GROQ_FILE (righe CHIAVE=valore: si usa la prima chiave che contiene «GROQ»)."""
    c = {k: os.path.expanduser(v) for k, v in leggi_kv(os.environ.get("METIS_CONFIG", os.path.join(CFG_DIR, "config"))).items()}
    if nome == "telegram" and c.get("METIS_TELEGRAM_TOKEN_FILE"):
        leggi = lambda k: open(protetto(c[k]), encoding="utf-8").read().strip() if c.get(k) and os.path.exists(c[k]) else ""
        return {"TOKEN": leggi("METIS_TELEGRAM_TOKEN_FILE"), "CHAT_ID": leggi("METIS_TELEGRAM_CHAT_FILE")}
    if nome == "groq" and c.get("METIS_GROQ_FILE"):
        kv = leggi_kv(protetto(c["METIS_GROQ_FILE"]))
        return {"KEY": next((v for k, v in kv.items() if "GROQ" in k.upper()), "")}
    return leggi_kv(protetto(os.path.join(CFG_DIR, nome)))


def log(cfg, testo):
    os.makedirs(os.path.dirname(cfg["log"]), exist_ok=True)
    with open(cfg["log"], "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {testo}\n")


# --- Bot API ----------------------------------------------------------------------------------------------------
def tg(token, metodo, params=None, timeout=35):
    dati = urllib.parse.urlencode(params or {}).encode()
    req = urllib.request.Request(f"{API}/bot{token}/{metodo}", data=dati)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        risposta = json.load(r)
    if not risposta.get("ok"):
        raise RuntimeError(f"{metodo}: {risposta.get('description')}")
    return risposta["result"]


def scarica(token, file_id, destinazione):
    info = tg(token, "getFile", {"file_id": file_id})
    with urllib.request.urlopen(f"{API}/file/bot{token}/{info['file_path']}", timeout=60) as r, open(destinazione, "wb") as f:
        shutil.copyfileobj(r, f)
    return destinazione


def invia(token, chat, testo):
    testo = testo.strip() or "(risposta vuota)"
    for i in range(0, len(testo), MAX_MSG):
        tg(token, "sendMessage", {"chat_id": chat, "text": testo[i:i + MAX_MSG]})


# --- note nell'Inbox --------------------------------------------------------------------------------------------
def nome_file(testo, quando, prefisso):
    parole = re.sub(r"[^\wàèéìòù ]", " ", testo.lower()).split()[:6]
    base = f"{quando:%Y-%m-%d %H%M} {prefisso} " + (" ".join(parole) or "messaggio")
    return base[:90].strip() + ".md"


def scrivi_nota(cartella, testo, quando, prefisso, fonte, extra=""):
    os.makedirs(cartella, exist_ok=True)
    p = os.path.join(cartella, nome_file(testo, quando, prefisso))
    n = 2
    while os.path.exists(p):
        p = p[:-3] + f" ({n}).md"; n += 1
    with open(p, "w", encoding="utf-8") as f:
        f.write(f"---\ncreated_at: {quando:%Y-%m-%d}\ntags:\n- contenuto/{fonte}\nup:\n- '[[{os.path.basename(cartella)}]]'\n"
                f"fonte: {fonte}\nricevuto: '{quando:%Y-%m-%d %H:%M}'\n---\n\n{testo.strip()}\n{extra}")
    return p


# --- voce -------------------------------------------------------------------------------------------------------
def trascrivi(cfg, percorso):
    chiave = segreti("groq").get("KEY")
    if not chiave:
        raise RuntimeError("chiave Groq mancante (~/.config/metis/groq): modulo voce non installato")
    audio = percorso
    ffmpeg = shutil.which("ffmpeg") or next((p for p in ("/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg") if os.path.exists(p)), None)
    if ffmpeg:  # 16 kHz mono: file piccoli e trascrizione più stabile; se la conversione fallisce si manda l'originale
        mp3 = percorso + ".mp3"
        if subprocess.run([ffmpeg, "-i", percorso, "-ar", "16000", "-ac", "1", "-y", mp3], capture_output=True, timeout=120).returncode == 0:
            audio = mp3
    confine = uuid.uuid4().hex
    corpo = b""
    for k, v in (("model", "whisper-large-v3"), ("language", "it"), ("response_format", "text")):
        corpo += f"--{confine}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    corpo += (f"--{confine}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{os.path.basename(audio)}\"\r\n"
              f"Content-Type: application/octet-stream\r\n\r\n").encode() + open(audio, "rb").read() + f"\r\n--{confine}--\r\n".encode()
    req = urllib.request.Request(f"{GROQ}/openai/v1/audio/transcriptions", data=corpo,
                                 headers={"Authorization": f"Bearer {chiave}", "Content-Type": f"multipart/form-data; boundary={confine}",
                                          # con l'intestazione predefinita di urllib Groq risponde 403 (verificato il 29/9/2026)
                                          "User-Agent": "metis/0.1"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read().decode("utf-8").strip()


# --- conversazione ----------------------------------------------------------------------------------------------
def conversa(cfg, stato, testo):
    ora = time.time()
    nuova = testo.strip().lower().startswith("/nuova") or ora - stato.get("ultimo", 0) > ORE_CONVERSAZIONE * 3600
    if testo.strip().lower().startswith("/nuova"):
        testo = testo.strip()[6:].strip() or "Cominciamo una conversazione nuova."
    prompt = ("[Messaggio del cliente dal bot Telegram. Rispondi in testo semplice, breve, adatto al telefono. "
              "Se scrivi o modifichi file del vault, dillo in una riga.]\n\n" + testo)
    cmd = [CLAUDE, "-p", "--output-format", "json", "--permission-mode", "acceptEdits"]
    if os.path.exists(cfg["settings"]):
        cmd += ["--settings", cfg["settings"]]
    if not nuova and stato.get("sessione"):
        cmd += ["--resume", stato["sessione"]]
    r = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=cfg["vault"], timeout=900)
    try:
        d = json.loads(r.stdout)
        risposta, sessione = d.get("result", ""), d.get("session_id")
    except (json.JSONDecodeError, ValueError):
        risposta, sessione = (r.stdout.strip() or r.stderr.strip() or "Errore: Claude non ha risposto."), None
    if sessione:
        stato["sessione"] = sessione
    stato["ultimo"] = ora
    if isinstance(locals().get("d"), dict):   # misure del giro, per conoscere latenza e costo della conversazione
        log(cfg, f"conversazione: {'nuova' if nuova else 'ripresa'}, {d.get('duration_ms', 0) / 1000:.1f} s, "
                 f"costo dichiarato {d.get('total_cost_usd', 0):.4f} USD, turni {d.get('num_turns', '?')}")
    return risposta


# --- smistamento ------------------------------------------------------------------------------------------------
def smista(cfg, token, chat, stato, msg):
    quando = datetime.datetime.fromtimestamp(msg.get("date", time.time()))
    testo = msg.get("text") or msg.get("caption") or ""
    inbox_tg = os.path.join(cfg["inbox"], "telegram")
    doc = msg.get("document") or (msg.get("photo") or [None])[-1] or msg.get("video") or msg.get("audio")
    if msg.get("voice"):
        # Un vocale di meno di due secondi è quasi sempre partito per sbaglio, e Whisper sul silenzio inventa frasi
        # («Grazie a tutti.», verificato il 29/9/2026): non si trascrive.
        if msg["voice"].get("duration", 0) < 2:
            return "Il vocale è troppo corto: se volevi dire qualcosa, ripetilo."
        tmp = tempfile.mkdtemp(prefix="metis-vocale-")
        try:
            trascritto = trascrivi(cfg, scarica(token, msg["voice"]["file_id"], os.path.join(tmp, "vocale.oga")))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        if not trascritto or FRASI_WHISPER.match(trascritto):
            return "Non ho capito il vocale: ripetilo, o scrivimi."
        if re.match(r"^\W*nota\b", trascritto, re.I):
            p = scrivi_nota(os.path.join(cfg["inbox"], "voicenotes"), trascritto, quando, "Vocale", "vocale")
            return f"Nota vocale salvata nell'Inbox: {os.path.basename(p)}"
        return f"Ho capito: «{trascritto}»\n\n" + conversa(cfg, stato, trascritto)
    if doc:
        nome = doc.get("file_name") or f"{quando:%Y-%m-%d %H%M%S} foto.jpg"
        os.makedirs(os.path.join(cfg["inbox"], "files"), exist_ok=True)
        dest = os.path.join(cfg["inbox"], "files", os.path.basename(nome))
        scarica(token, doc["file_id"], dest)
        p = scrivi_nota(inbox_tg, testo or nome, quando, "File", "telegram", f"\nFile: `{dest}`\n")
        return f"File salvato nell'Inbox: {os.path.basename(dest)}"
    if not testo:
        return "Messaggio non riconosciuto: mando al vault testi, link, file e vocali."
    solo_link = re.fullmatch(r"\s*https?://\S+\s*", testo) is not None
    inoltrato = any(msg.get(k) for k in ("forward_origin", "forward_date", "forward_from", "forward_from_chat", "forward_sender_name"))
    if inoltrato or solo_link or re.match(r"^\W*nota\b", testo, re.I):
        testo_nota = re.sub(r"^\W*nota\W*", "", testo, flags=re.I) if not solo_link else testo
        p = scrivi_nota(inbox_tg, testo_nota, quando, "Telegram", "telegram")
        return f"Salvato nell'Inbox: {os.path.basename(p)}"
    return conversa(cfg, stato, testo)


def ascolta(una_volta=False):
    cfg = config()
    s = segreti("telegram")
    token, chat = s.get("TOKEN"), s.get("CHAT_ID")
    if not token or not chat:
        raise SystemExit("token o chat mancanti in ~/.config/metis/telegram")
    stato = json.load(open(cfg["stato"])) if os.path.exists(cfg["stato"]) else {}
    log(cfg, "ascoltatore avviato")
    while True:
        try:
            aggiornamenti = tg(token, "getUpdates", {"offset": stato.get("offset", 0), "timeout": 0 if una_volta else 50}, timeout=65)
        except Exception as e:  # rete assente o Mac appena sveglio: si riprova
            log(cfg, f"getUpdates non riuscito: {e}")
            if una_volta: return 1
            time.sleep(15); continue
        for u in aggiornamenti:
            stato["offset"] = u["update_id"] + 1
            msg = u.get("message") or {}
            da = str((msg.get("chat") or {}).get("id", ""))
            if da != str(chat):
                log(cfg, f"ignorato un messaggio dalla chat {da}: non è la chat del cliente"); continue
            # forma del messaggio (solo i nomi dei campi, mai il contenuto): serve a capire uno smistamento sbagliato
            log(cfg, f"update {u['update_id']}: campi {','.join(sorted(k for k in msg if k not in ('chat', 'from', 'message_id', 'date')))}")
            try:
                tg(token, "sendChatAction", {"chat_id": chat, "action": "typing"})
                risposta = smista(cfg, token, chat, stato, msg)
            except Exception as e:
                risposta = f"Non ci sono riuscito: {e}"
                log(cfg, f"errore su update {u['update_id']}: {e}")
            invia(token, chat, risposta)
            log(cfg, f"update {u['update_id']} gestito")
        with open(cfg["stato"] + ".tmp", "w") as f:
            json.dump(stato, f)
        os.replace(cfg["stato"] + ".tmp", cfg["stato"])
        if una_volta:
            return 0


def main(a):
    if not a:
        print(__doc__); return 2
    if a[0] == "invia":
        s = segreti("telegram")
        testo = " ".join(a[1:]) if len(a) > 1 else sys.stdin.read()
        invia(s["TOKEN"], s["CHAT_ID"], testo); return 0
    if a[0] == "verifica":   # token valido e chat presente, senza mostrare nessuno dei due
        s = segreti("telegram")
        if not s.get("TOKEN"):
            print("token assente"); return 1
        try:
            me = tg(s["TOKEN"], "getMe", timeout=20)
        except Exception as e:
            print(f"token non valido: {e}"); return 1
        print(f"token valido (bot @{me.get('username')})")
        if not s.get("CHAT_ID"):
            print("chat del cliente non salvata"); return 2
        print("chat del cliente salvata"); return 0
    if a[0] == "trova-chat":
        s = segreti("telegram")
        viste = {}
        for u in tg(s["TOKEN"], "getUpdates", {"timeout": 0}):
            c = (u.get("message") or {}).get("chat") or {}
            if c.get("type") == "private":
                viste[c["id"]] = c.get("first_name", "") + " " + c.get("last_name", "")
        for i, n in viste.items():
            print(f"{i}\t{n.strip()}")
        return 0 if viste else 1
    if a[0] == "prova-trascrizione":   # controllo del modulo voce: un secondo di silenzio generato al momento
        ffmpeg = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
        tmp = tempfile.mkdtemp(prefix="metis-voce-")
        try:
            f = os.path.join(tmp, "silenzio.wav")
            subprocess.run([ffmpeg, "-f", "lavfi", "-i", "anullsrc=r=16000:cl=mono", "-t", "1", "-y", f], capture_output=True, timeout=60, check=True)
            print("trascrizione riuscita: «" + trascrivi(config(), f) + "»")
            return 0
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    if a[0] == "ascolta":
        return ascolta("--una-volta" in a)
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
