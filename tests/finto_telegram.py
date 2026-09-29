#!/usr/bin/env python3
"""finto_telegram.py — server finto del Bot API di Telegram e della trascrizione di Groq, per le prove.

Uso: finto_telegram.py <cartella di lavoro> <porta>
Nella cartella di lavoro:
  aggiornamenti.json   elenco di update che getUpdates restituisce (rispettando offset)
  file/<file_id>       i byte che getFile + download restituiscono per quel file_id
  trascrizione.txt     il testo che la trascrizione restituisce
Il server scrive:
  inviati.jsonl        una riga per ogni sendMessage (chat_id, text)
  chiamate.jsonl       una riga per ogni chiamata (metodo, parametri, intestazione Authorization)
Token accettato: quello in token.txt; ogni altro token riceve 401, come il servizio vero.
"""
import json, os, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

DIR, PORTA = sys.argv[1], int(sys.argv[2])
TOKEN = open(os.path.join(DIR, "token.txt")).read().strip()


def scrivi(nome, d):
    with open(os.path.join(DIR, nome), "a", encoding="utf-8") as f:
        f.write(json.dumps(d, ensure_ascii=False) + "\n")


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def rispondi(self, codice, corpo, tipo="application/json"):
        b = corpo if isinstance(corpo, bytes) else json.dumps(corpo, ensure_ascii=False).encode()
        self.send_response(codice); self.send_header("Content-Type", tipo); self.send_header("Content-Length", str(len(b)))
        self.end_headers(); self.wfile.write(b)

    def do_GET(self):
        # download dei file: /file/bot<token>/<percorso>
        if self.path.startswith(f"/file/bot{TOKEN}/"):
            fid = self.path.rsplit("/", 1)[1]
            p = os.path.join(DIR, "file", fid)
            return self.rispondi(200, open(p, "rb").read(), "application/octet-stream") if os.path.exists(p) else self.rispondi(404, {"ok": False})
        # metodi del bot anche in GET, come il servizio vero (parametri nella query)
        if "?" in self.path:
            self.path, q = self.path.split("?", 1)
        else:
            q = ""
        return self.metodo(q.encode())

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); corpo = self.rfile.read(n)
        return self.metodo(corpo, n)

    def metodo(self, corpo, n=0):
        if self.path == "/openai/v1/audio/transcriptions":
            scrivi("chiamate.jsonl", {"metodo": "trascrizione", "auth": self.headers.get("Authorization"), "byte": n})
            if self.headers.get("Authorization") != "Bearer chiave-finta":
                return self.rispondi(401, {"error": "chiave non valida"})
            return self.rispondi(200, open(os.path.join(DIR, "trascrizione.txt"), "rb").read(), "text/plain")
        parti = self.path.strip("/").split("/")
        if len(parti) != 2 or parti[0] != f"bot{TOKEN}":
            return self.rispondi(401, {"ok": False, "description": "Unauthorized"})
        metodo = parti[1]
        p = {k: v[0] for k, v in urllib.parse.parse_qs(corpo.decode()).items()}
        scrivi("chiamate.jsonl", {"metodo": metodo, "parametri": p})
        if metodo == "getMe":
            return self.rispondi(200, {"ok": True, "result": {"id": 1, "is_bot": True, "username": "bot_di_prova"}})
        if metodo == "getUpdates":
            tutti = json.load(open(os.path.join(DIR, "aggiornamenti.json")))
            offset = int(p.get("offset", 0))
            return self.rispondi(200, {"ok": True, "result": [u for u in tutti if u["update_id"] >= offset]})
        if metodo == "sendMessage":
            scrivi("inviati.jsonl", {"chat_id": p.get("chat_id"), "text": p.get("text")})
            return self.rispondi(200, {"ok": True, "result": {"message_id": 1}})
        if metodo == "sendChatAction":
            return self.rispondi(200, {"ok": True, "result": True})
        if metodo == "getFile":
            return self.rispondi(200, {"ok": True, "result": {"file_id": p["file_id"], "file_path": p["file_id"]}})
        self.rispondi(400, {"ok": False, "description": f"metodo {metodo} non simulato"})


HTTPServer(("127.0.0.1", PORTA), H).serve_forever()
