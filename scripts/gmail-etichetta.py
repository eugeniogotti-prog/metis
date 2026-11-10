#!/usr/bin/env python3
"""gmail-etichetta.py — porta nell'Inbox del vault le mail a cui il cliente mette un'etichetta in Gmail (default «vault»).

Il cliente mette l'etichetta a una mail, anche dal telefono. A ogni giro (google.sh etichetta-installa: ogni 30 minuti):
  1. cerca in Gmail le mail con l'etichetta (la crea se manca, così il cliente la trova già pronta);
  2. per ciascuna scrive una nota nella cartella Email/ dell'Inbox: frontmatter con source: Gmail, mittente, data,
     link al thread; testo in chiaro; gli allegati sono solo elencati (si scaricano dopo, se servono, con la posta locale);
  3. toglie l'etichetta e mette «<etichetta>-fatto», così in Gmail si vede che la mail è entrata.
Poi il giro dell'inbox-processor lavora la nota come ogni altra cosa arrivata.

Autorizzazione: la stessa della posta locale (google.sh credenziali-posta e account-posta), cartella
~/.config/google-workspace-mcp: credentials.json e tokens.json. Il token d'accesso si rinnova a ogni giro e resta in
memoria; il file dei token non si tocca. Il consenso della posta locale comprende già la modifica delle etichette
(scope gmail.modify, verificato sul pacchetto 3.4.4).
Che cosa fa sulla posta: legge le mail etichettate e cambia due etichette. Non invia, non cancella, non archivia.

Uso: gmail-etichetta.py --dest <cartella Email dell'Inbox> [--etichetta vault] [--dir <cartella OAuth>] [--up <nota>] [--prova]
     --prova: elenca le mail etichettate senza scrivere né toccare le etichette (e senza creare l'etichetta)
Uscita: 0 riuscito (anche senza mail) · 1 autorizzazione da rifare · 2 errore di rete o di Gmail (si riprova al giro dopo).
Per le prove: METIS_GOOGLE_TOKEN_URL e METIS_GMAIL_API sostituiscono gli indirizzi di Google.
"""
import argparse, base64, datetime, html, json, os, re, sys, urllib.error, urllib.parse, urllib.request
from email.utils import parsedate_to_datetime

TOKEN_URL = os.environ.get("METIS_GOOGLE_TOKEN_URL", "https://oauth2.googleapis.com/token")
API = os.environ.get("METIS_GMAIL_API", "https://gmail.googleapis.com/gmail/v1/users/me").rstrip("/")


class Errore(Exception):
    def __init__(self, codice, msg):
        super().__init__(msg); self.codice = codice


def token_accesso(d):
    try:
        c = json.load(open(os.path.join(d, "credentials.json")))
        t = json.load(open(os.path.join(d, "tokens.json")))
    except (OSError, ValueError) as e:
        raise Errore(1, f"autorizzazione della posta locale assente o illeggibile in {d} ({type(e).__name__}): "
                        "google.sh credenziali-posta <file> e google.sh account-posta")
    c = c.get("installed") or c.get("web") or c
    if not c.get("client_id") or not t.get("refresh_token"):
        raise Errore(1, "autorizzazione incompleta (manca client_id o refresh_token): google.sh account-posta")
    dati = {"client_id": c["client_id"], "refresh_token": t["refresh_token"], "grant_type": "refresh_token"}
    if c.get("client_secret"): dati["client_secret"] = c["client_secret"]
    req = urllib.request.Request(TOKEN_URL, data=urllib.parse.urlencode(dati).encode(), method="POST")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            at = json.load(r).get("access_token")
    except urllib.error.HTTPError as e:
        try: err = json.load(e).get("error", "")
        except Exception: err = ""
        if err in ("invalid_grant", "invalid_client", "unauthorized_client"):
            raise Errore(1, f"autorizzazione Google non valida ({err}): google.sh account-posta")
        raise Errore(2, f"Google ha risposto {e.code} {err}")
    except Exception as e:
        raise Errore(2, f"rete non raggiungibile ({type(e).__name__})")
    if not at: raise Errore(2, "risposta di Google senza token d'accesso")
    return at


class Gmail:
    def __init__(self, at): self.at = at

    def __call__(self, metodo, percorso, corpo=None, **q):
        url = API + percorso + ("?" + urllib.parse.urlencode(q, doseq=True) if q else "")
        dati = json.dumps(corpo).encode() if corpo is not None else None
        req = urllib.request.Request(url, data=dati, method=metodo,
                                     headers={"Authorization": "Bearer " + self.at, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                raise Errore(1, f"Gmail ha rifiutato l'accesso ({e.code}): manca il permesso sulle etichette? google.sh account-posta")
            raise Errore(2, f"Gmail ha risposto {e.code} su {percorso}")
        except Errore:
            raise
        except Exception as e:
            raise Errore(2, f"rete non raggiungibile ({type(e).__name__})")


def id_etichetta(g, nome, crea):
    for l in g("GET", "/labels").get("labels", []):
        if l["name"].lower() == nome.lower():
            return l["id"]
    if not crea:
        return None
    return g("POST", "/labels", {"name": nome, "labelListVisibility": "labelShow", "messageListVisibility": "show"})["id"]


def html_a_testo(h):
    h = re.sub(r"(?is)<(script|style).*?</\1>", "", h)
    h = re.sub(r"(?i)<br\s*/?>|</p>|</div>|</tr>|</li>|</h\d>", "\n", h)
    h = re.sub(r"(?i)<li[^>]*>", "- ", h)
    h = re.sub(r"(?s)<[^>]+>", "", h)
    return re.sub(r"\n\s*\n\s*\n+", "\n\n", html.unescape(h)).strip()


def parti(p, testi, htmls, allegati):
    mt = p.get("mimeType", "")
    if p.get("filename"):
        allegati.append(f"{p['filename']} ({mt}, {p.get('body', {}).get('size', 0) // 1024} KB)")
        return
    dati = p.get("body", {}).get("data")
    if dati:
        t = base64.urlsafe_b64decode(dati + "=" * (-len(dati) % 4)).decode("utf-8", "replace")
        if mt == "text/plain": testi.append(t)
        elif mt == "text/html": htmls.append(t)
    for q in p.get("parts", []) or []:
        parti(q, testi, htmls, allegati)


def nome_file(dest, data, oggetto, mittente):
    base = f"{data} Email {oggetto or 'senza oggetto'} — {mittente}"
    base = re.sub(r'[/\\:*?"<>|#^\[\]]', " ", base)
    base = re.sub(r"\s+", " ", base).strip()[:110].strip()
    p = os.path.join(dest, base + ".md"); n = 2
    while os.path.exists(p):
        p = os.path.join(dest, f"{base} {n}.md"); n += 1
    return p


def gia_scritta(dest, mid):
    """Una nota con questo gmail_id c'è già (giro precedente interrotto prima di cambiare le etichette)."""
    riga = f"gmail_id: {mid}\n"
    try:
        nomi = os.listdir(dest)
    except OSError:
        return False
    for n in nomi:
        if n.endswith(".md"):
            try:
                with open(os.path.join(dest, n), encoding="utf-8", errors="replace") as f:
                    if riga in f.read(4096): return True
            except OSError:
                pass
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", required=True)
    ap.add_argument("--etichetta", default="vault")
    ap.add_argument("--dir", default=os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
                                                  "google-workspace-mcp"))
    ap.add_argument("--up", default="")
    ap.add_argument("--prova", action="store_true")
    a = ap.parse_args()
    nome, fatto = a.etichetta.strip(), a.etichetta.strip() + "-fatto"
    ora = f"{datetime.datetime.now():%Y-%m-%d %H:%M}"

    g = Gmail(token_accesso(a.dir))
    lid = id_etichetta(g, nome, crea=not a.prova)
    if not lid:
        print(f"{ora} etichetta «{nome}» assente in Gmail (prova: non creata)"); return
    msgs = g("GET", "/messages", labelIds=lid, maxResults=50).get("messages", [])
    if not msgs:
        return   # niente da fare: nessuna riga, per non riempire il registro ogni mezz'ora
    fid = None if a.prova else id_etichetta(g, fatto, crea=True)
    scritte = 0
    for m in msgs:
        o = g("GET", f"/messages/{m['id']}", format="full")
        h = {x["name"].lower(): x["value"] for x in o.get("payload", {}).get("headers", [])}
        try:
            dt = parsedate_to_datetime(h.get("date", ""))
        except Exception:
            dt = datetime.datetime.now()
        mitt_full = h.get("from", "")
        mitt = re.sub(r"\s*<.*?>", "", mitt_full).strip('" ') or mitt_full
        testi, htmls, allegati = [], [], []
        parti(o.get("payload", {}), testi, htmls, allegati)
        corpo = "\n\n".join(testi).strip() or html_a_testo("\n".join(htmls)) or o.get("snippet", "")
        if a.prova:
            print(f"{ora} PROVA {h.get('subject', '(senza oggetto)')} — {mitt}"); continue
        if not gia_scritta(a.dest, m["id"]):
            path = nome_file(a.dest, f"{dt:%Y-%m-%d}", h.get("subject", ""), mitt)
            fm = ["---", f"created_at: {datetime.date.today().isoformat()}", "tags:", "- contenuto/email"]
            if a.up: fm += ["up:", f"- '[[{a.up}]]'"]
            fm += ["source: Gmail", f"gmail_id: {m['id']}", f"thread_id: {o.get('threadId', '')}",
                   f"mittente: {json.dumps(mitt_full, ensure_ascii=False)}",
                   f"destinatari: {json.dumps(h.get('to', ''), ensure_ascii=False)}",
                   f"data_mail: {dt.isoformat()}", f"origine: etichetta «{nome}» in Gmail", "---", ""]
            testo = [f"# {h.get('subject', '(senza oggetto)')}", "", f"**Da:** {mitt_full}  ", f"**A:** {h.get('to', '')}  "]
            if h.get("cc"): testo.append(f"**Cc:** {h['cc']}  ")
            testo += [f"**Data:** {dt:%d/%m/%Y %H:%M}  ",
                      f"**Gmail:** https://mail.google.com/mail/u/0/#all/{o.get('threadId', '')}", ""]
            if allegati:
                testo += ["**Allegati (non scaricati):**"] + [f"- {x}" for x in allegati] + [""]
            testo += ["---", "", corpo, ""]
            os.makedirs(a.dest, exist_ok=True)
            tmp = path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                f.write("\n".join(fm + testo))
            os.replace(tmp, path)
            scritte += 1
            print(f"{ora} nota scritta: {os.path.basename(path)}")
        g("POST", f"/messages/{m['id']}/modify", {"removeLabelIds": [lid], "addLabelIds": [fid]})
    if not a.prova:
        print(f"{ora} {len(msgs)} mail con l'etichetta «{nome}»: {scritte} note nuove, etichetta cambiata in «{fatto}»")


if __name__ == "__main__":
    try:
        main()
    except Errore as e:
        print(f"{datetime.datetime.now():%Y-%m-%d %H:%M} gmail-etichetta: {e}", file=sys.stderr)
        sys.exit(e.codice)
