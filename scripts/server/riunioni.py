#!/usr/bin/env python3
"""riunioni.py — l'ingresso delle riunioni registrate: dal telefono del cliente (Scorciatoia iPhone) al vault.

La Scorciatoia registra e manda l'audio con un POST HTTPS a https://<nome del server>/riunione (Caddy, web.sh), con il
segreto del cliente nell'intestazione «X-Metis-Segreto» e, se vuole, un titolo in «X-Titolo». Il ricevitore:
  1. controlla il segreto e la dimensione, salva l'audio (600) e risponde subito «ricevuta»;
  2. lo converte (mono, 16 kHz) e lo trascrive con Groq, a pezzi di 20 minuti se è lungo;
  3. scrive la trascrizione come nota in <Inbox>/voicenotes e CANCELLA l'audio (METIS_RIUNIONI_TIENI_AUDIO=1 per tenerlo);
  4. passa la nota alla sessione principale, che fa la sintesi (decisioni, cose da fare, impegni negli stati) e risponde
     al cliente su Telegram; se la sessione non c'è, avvisa su Telegram e la nota aspetta il giro dell'Inbox.
Gli errori arrivano al cliente su Telegram, in una riga.

Uso: riunioni.py ascolta            il servizio (127.0.0.1:METIS_RIUNIONI_PORTA, default 8765; lo avvia servizi.sh)
     riunioni.py segreto            crea il segreto se manca e lo stampa (va incollato nella Scorciatoia)
     riunioni.py lavora <file>      trascrive e consegna un audio già sul server (prove, recuperi)
Solo libreria standard di Python, più ffmpeg. Chiave di Groq e bot: quelli del modulo voce e del modulo Telegram.
"""
import datetime, hmac, http.server, os, secrets, shutil, subprocess, sys, tempfile, threading, time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "telegram"))
import metis_telegram as mt   # noqa: E402  configurazione, trascrizione con Groq, invio su Telegram, consegna alla sessione

CFG_DIR = mt.CFG_DIR
SEGRETO = os.path.join(CFG_DIR, "riunioni-segreto")
ARRIVI = os.path.expanduser("~/.local/share/metis/riunioni")
PORTA = int(os.environ.get("METIS_RIUNIONI_PORTA", "8765"))
MAX_BYTE = 400 * 1024 * 1024
MIN_BYTE = 4096   # sotto non è una registrazione: si rifiuta subito, senza lavoro né messaggi
PEZZO_SEC = 1200
ESTENSIONI = {"audio/x-m4a": ".m4a", "audio/m4a": ".m4a", "audio/mp4": ".m4a", "audio/mpeg": ".mp3", "audio/wav": ".wav",
              "audio/x-wav": ".wav", "audio/aac": ".aac", "audio/ogg": ".ogg", "audio/webm": ".webm"}


def segreto(crea=False):
    if not os.path.exists(SEGRETO):
        if not crea:
            return ""
        os.makedirs(CFG_DIR, exist_ok=True)
        fd = os.open(SEGRETO, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.write(fd, (secrets.token_urlsafe(32) + "\n").encode()); os.close(fd)
    return open(mt.protetto(SEGRETO), encoding="utf-8").read().strip()


def telegram(testo):
    try:
        s = mt.segreti("telegram")
        if s.get("TOKEN") and s.get("CHAT_ID"):
            mt.invia(s["TOKEN"], s["CHAT_ID"], testo)
    except Exception as e:   # l'avviso non deve fermare il lavoro
        print(f"telegram non riuscito: {e}", file=sys.stderr)


def durata(ffmpeg, f):
    r = subprocess.run([ffmpeg, "-i", f], capture_output=True, text=True)
    for riga in r.stderr.splitlines():
        if "Duration:" in riga:
            h, m, s = riga.split("Duration:")[1].split(",")[0].strip().split(":")
            return int(h) * 3600 + int(m) * 60 + float(s)
    return 0.0


def lavora(audio, titolo=""):
    cfg = mt.config()
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("manca ffmpeg sul server")
    quando = datetime.datetime.fromtimestamp(os.path.getmtime(audio))
    tmp = tempfile.mkdtemp(prefix="metis-riunione-")
    try:
        sec = durata(ffmpeg, audio)
        # Pezzi di 20 minuti in mono 16 kHz a 32 kbit/s: circa 5 MB l'uno, sotto il limite di Groq.
        subprocess.run([ffmpeg, "-i", audio, "-ac", "1", "-ar", "16000", "-b:a", "32k", "-f", "segment",
                        "-segment_time", str(PEZZO_SEC), "-y", os.path.join(tmp, "pezzo-%03d.mp3")],
                       capture_output=True, timeout=1800, check=True)
        pezzi = sorted(f for f in os.listdir(tmp) if f.startswith("pezzo-"))
        if not pezzi:
            raise RuntimeError("audio vuoto o non leggibile")
        testi = [mt.trascrivi(cfg, os.path.join(tmp, p)) for p in pezzi]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    testo = "\n\n".join(t for t in testi if t).strip()
    if not testo or mt.FRASI_WHISPER.match(testo):
        raise RuntimeError("nella registrazione non si sente parlare")
    nome = f"{quando:%Y-%m-%d %H%M} Riunione registrata{(' — ' + titolo) if titolo else ''}"
    nome = "".join(c for c in nome if c not in '/\\:*?"<>|#^[]')[:120]
    cartella = os.path.join(cfg["inbox"], "voicenotes"); os.makedirs(cartella, exist_ok=True)
    nota = os.path.join(cartella, nome + ".md")
    with open(nota, "w", encoding="utf-8") as f:
        f.write(f"---\ncreated_at: {quando:%Y-%m-%d}\ntags:\n- contenuto/riunione\nsource: riunione registrata\n"
                f"registrata: {quando:%Y-%m-%d %H:%M}\ndurata_minuti: {round(sec / 60)}\n---\n\n# {nome}\n\n"
                f"Trascrizione automatica (Groq, whisper), {round(sec / 60)} minuti. I nomi propri possono essere storpiati.\n\n"
                f"---\n\n{testo}\n")
    if os.environ.get("METIS_RIUNIONI_TIENI_AUDIO") != "1":
        os.remove(audio)
    istruzione = (f"[Riunione] È arrivata una riunione registrata dal telefono, {round(sec / 60)} minuti, trascritta in "
                  f"«{nota}». Lavorala come riunione secondo la skill inbox-processor: sintesi con partecipanti, decisioni "
                  f"(tenendo distinti orientamenti e decisioni), cose da fare con chi e quando, nota nel lavoro giusto, "
                  f"impegni e stato aggiornati; la trascrizione va in trascrizioni/ accanto alla sintesi. Se nessun lavoro "
                  f"corrisponde, non chiedere e non lasciarla nell'Inbox: crea il lavoro adatto (cartella e stato) e collocala lì, "
                  f"poi dillo nel riassunto. Poi manda al cliente su Telegram un riassunto di 4-6 righe con il link alla nota, con:\n"
                  f"python3 {os.path.abspath(mt.__file__)} invia <<'FINE'\n<riassunto>\nFINE")
    if not mt.alla_sessione(dict(cfg, conversazione="sessione"), istruzione, grezzo=True):
        telegram(f"Riunione trascritta ({round(sec / 60)} minuti): la trovi nell'Inbox, «{nome}». La sintesi arriva con il prossimo giro dell'Inbox.")
    return nota


class Gestore(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *a):
        print(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {self.address_string()} {fmt % a}", flush=True)

    def rispondi(self, codice, testo):
        b = (testo + "\n").encode(); self.send_response(codice)
        self.send_header("Content-Type", "text/plain; charset=utf-8"); self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)

    def do_GET(self):
        self.rispondi(404, "")

    def do_POST(self):
        if self.path.split("?")[0].rstrip("/") != "/riunione":
            return self.rispondi(404, "")
        atteso = segreto()
        if not atteso or not hmac.compare_digest(self.headers.get("X-Metis-Segreto", ""), atteso):
            time.sleep(1); return self.rispondi(403, "Non autorizzato.")
        a_pezzi = "chunked" in (self.headers.get("Transfer-Encoding") or "").lower()
        n = int(self.headers.get("Content-Length") or 0)
        if not a_pezzi and n <= 0:
            print(f"rifiutata: corpo vuoto (nessuna Content-Length, nessun invio a pezzi)", flush=True)
            return self.rispondi(400, "Registrazione vuota: riprova da Condividi.")
        if n > MAX_BYTE:
            print(f"rifiutata: {n} byte, oltre il limite", flush=True)
            return self.rispondi(413, "Registrazione troppo grande.")
        os.makedirs(ARRIVI, mode=0o700, exist_ok=True)
        tipo = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        f = os.path.join(ARRIVI, f"{datetime.datetime.now():%Y%m%d-%H%M%S}-{secrets.token_hex(3)}{ESTENSIONI.get(tipo, '.m4a')}")
        fd = os.open(f, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        scritti, completo = 0, True
        with os.fdopen(fd, "wb") as out:
            if a_pezzi:   # Transfer-Encoding: chunked (dimensione non dichiarata in anticipo)
                while True:
                    riga = self.rfile.readline(65537).strip()
                    try:
                        dim = int(riga.split(b";")[0], 16)
                    except ValueError:
                        completo = False; break
                    if dim == 0:
                        while self.rfile.readline(65537).strip():   # eventuali intestazioni finali
                            pass
                        break
                    if scritti + dim > MAX_BYTE:
                        completo = False; break
                    resto = dim
                    while resto > 0:
                        blocco = self.rfile.read(min(1 << 20, resto))
                        if not blocco:
                            break
                        out.write(blocco); resto -= len(blocco); scritti += len(blocco)
                    self.rfile.readline(3)   # il CRLF dopo ogni pezzo
                    if resto:
                        completo = False; break
            else:
                resto = n
                while resto > 0:
                    blocco = self.rfile.read(min(1 << 20, resto))
                    if not blocco:
                        break
                    out.write(blocco); resto -= len(blocco); scritti += len(blocco)
                completo = resto == 0
        if completo and scritti < MIN_BYTE:
            os.remove(f)
            print(f"rifiutata: {scritti} byte, troppo pochi per una registrazione (a pezzi: {a_pezzi})", flush=True)
            return self.rispondi(400, "Registrazione vuota o troppo corta.")
        if not completo or scritti == 0:
            os.remove(f)
            print(f"rifiutata: arrivata a metà o troppo grande ({scritti} byte, a pezzi: {a_pezzi})", flush=True)
            return self.rispondi(400, "Registrazione arrivata a metà o troppo grande: riprova.")
        print(f"ricevuta: {scritti} byte, tipo {tipo or '?'}, a pezzi: {a_pezzi}", flush=True)
        titolo = self.headers.get("X-Titolo", "")[:60]
        self.rispondi(200, "Ricevuta. La trascrivo e ti scrivo su Telegram.")
        threading.Thread(target=lavora_e_avvisa, args=(f, titolo), daemon=True).start()


def lavora_e_avvisa(f, titolo):
    try:
        print(f"lavorata: {lavora(f, titolo)}", flush=True)
    except Exception as e:
        print(f"errore su {f}: {e}", flush=True)
        telegram(f"La riunione registrata non è andata a buon fine: {e}. L'audio è rimasto sul server: chi ti assiste può recuperarlo.")


def main(a):
    if not a:
        print(__doc__); return 2
    if a[0] == "segreto":
        print(segreto(crea=True)); return 0
    if a[0] == "lavora" and len(a) > 1:
        print(lavora(a[1], a[2] if len(a) > 2 else "")); return 0
    if a[0] == "ascolta":
        if not segreto():
            print("manca il segreto: riunioni.py segreto", file=sys.stderr); return 1
        s = http.server.ThreadingHTTPServer(("127.0.0.1", PORTA), Gestore)
        print(f"riunioni: in ascolto su 127.0.0.1:{PORTA}", flush=True); s.serve_forever()
    print(__doc__); return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
