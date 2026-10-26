#!/usr/bin/env node
// gmail-bozza.mjs — crea una bozza Gmail con allegati presi dal disco, rilegge una bozza esistente o la sostituisce
// con una nuova, attraverso il server locale google-workspace-mcp (@dguido/google-workspace-mcp 3.4.4, modulo google,
// strada «posta locale»).
//
// Perché esiste: lo strumento draft_email del server accetta gli allegati solo come base64 dentro la chiamata, che
// Claude non può copiare a mano senza rischiare di corrompere il file. Lo script legge i file e li passa lui.
//
// SOLO BOZZE. Lo script chiama soltanto draft_email, list_drafts, read_email, download_attachment e delete_draft, e avvia
// il server con il solo servizio Gmail. Non invia mai: passando da Bash scavalcherebbe la conferma che le regole del
// vault chiedono per send_email. L'invio lo fa il cliente da Gmail. Non aggiungere strumenti a STRUMENTI.
// delete_draft si usa solo con --sostituisce, sulla bozza indicata, dopo che la nuova è salvata e verificata.
//
// Una bozza non si riscrive mai (drafts.update): con Gmail aperto nel browser il cliente vedrebbe la copia vecchia,
// senza gli allegati nuovi. Per correggerla: --leggi, si parte dal testo letto, poi --sostituisce.
//
// Uso:
//   node gmail-bozza.mjs --to a@x.it [--to b@y.it] [--cc ...] [--bcc ...] --subject "Oggetto" \
//        (--body "testo" | --body-file testo.txt) [--html-file corpo.html] [--attach file.pdf ...] \
//        [--thread-id 1a2b] [--sostituisce r-123 --se-messaggio 19a2b (--thread-id 1a2b | --senza-thread)]
//   node gmail-bozza.mjs --leggi r-123 [--salva-in cartella]
//
//   --leggi riporta la bozza com'è adesso in Gmail: destinatari (come li scrive Gmail, e in «indirizzi» come elenchi
//   di indirizzi nudi), oggetto, testo, allegati, e messageId. Con --salva-in
//   scrive nella cartella corpo.txt, corpo.html (se c'è) e gli allegati, con il loro hash: le modifiche fatte dal
//   cliente in Gmail sono il punto di partenza della bozza nuova.
//   --sostituisce crea una bozza nuova completa (destinatari, oggetto, testo e allegati si ripassano tutti) e, solo se
//   è salvata e gli allegati tornano, cancella la vecchia. --se-messaggio è il messageId riportato da --leggi: se la
//   bozza è cambiata dopo la lettura (il cliente l'ha toccata), lo script si ferma prima di creare la nuova.
//   --to, --cc e --bcc accettano anche «Nome <indirizzo>» e più indirizzi separati da virgole: al server passa solo
//   l'indirizzo, e nella bozza nuova il nome visualizzato si perde (limite noto).
//   Thread: --thread-id per restare nella conversazione, --senza-thread per una bozza a sé. Il server non scrive
//   In-Reply-To né References nelle bozze: in Gmail la risposta sta nel thread, nei programmi di chi la riceve
//   potrebbe comparire come conversazione nuova.
//   Server: variabile METIS_GMAIL_SERVER, altrimenti google-workspace-mcp nel PATH, /opt/homebrew/bin, /usr/local/bin.
//
// Dopo il salvataggio riscarica ogni allegato dalla bozza e ne confronta l'hash SHA-256 con l'originale.
// Uscita: una riga JSON su stdout; codice 0 se bozza salvata e allegati verificati, 1 altrimenti.
// Se la bozza è stata salvata ma qualcosa dopo fallisce, l'uscita riporta comunque draftId: la bozza esiste.

import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const TIMEOUT_MS = 120_000;
// Gmail limita il messaggio intero a 25 MB dopo la codifica base64 (+1/3): sui file grezzi il tetto utile è più basso.
const MAX_CODIFICATO = 25 * 1024 * 1024 - 256 * 1024;

const stato = { draftId: undefined, messageId: undefined, threadId: undefined };
let srv, timer, tmp;
const log = [];
function pulisci() {
  clearTimeout(timer);
  try { srv?.kill(); } catch {}
  if (tmp) fs.rmSync(tmp, { recursive: true, force: true });
}
function esci(ok, dati) {
  pulisci();
  const bozza = stato.draftId ? { draftId: stato.draftId, messageId: stato.messageId, threadId: stato.threadId } : {};
  console.log(JSON.stringify({ ok, ...bozza, ...dati }));
  process.exit(ok ? 0 : 1);
}

// --- argomenti ---
const multipli = new Set(['to', 'cc', 'bcc', 'attach']);
const conValore = new Set([...multipli, 'subject', 'body', 'body-file', 'html-file', 'draft-id', 'thread-id', 'leggi', 'salva-in', 'sostituisce', 'se-messaggio']);
const senzaValore = new Set(['senza-thread']);
const opz = { to: [], cc: [], bcc: [], attach: [] };
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const k = argv[i].startsWith('--') ? argv[i].slice(2) : null;
  if (k && senzaValore.has(k)) { opz[k] = true; continue; }
  if (!k || !conValore.has(k)) esci(false, { errore: `argomento non riconosciuto: ${argv[i]}` });
  const v = argv[++i];
  if (v === undefined) esci(false, { errore: `manca il valore di --${k}` });
  if (multipli.has(k)) opz[k].push(v); else opz[k] = v;
}
const LETTURA = !!opz.leggi;
if (opz['draft-id'])
  esci(false, { errore: '--draft-id non c\'è più: una bozza non si riscrive. Usa --leggi, poi --sostituisce con una bozza nuova' });
if (LETTURA) {
  if (opz.to.length || opz.subject || opz.attach.length || opz.sostituisce) esci(false, { errore: '--leggi va da solo (con --salva-in)' });
} else {
  if (opz['salva-in']) esci(false, { errore: '--salva-in vale solo con --leggi' });
  if (!opz.to.length) esci(false, { errore: 'manca --to' });
  if (!opz.subject) esci(false, { errore: 'manca --subject' });
  if (opz.body === undefined && !opz['body-file']) esci(false, { errore: 'manca --body o --body-file' });
  if (opz.sostituisce && !opz['se-messaggio'])
    esci(false, { errore: 'con --sostituisce serve --se-messaggio <messageId riportato da --leggi>: si sostituisce solo la bozza che si è letta' });
  if (opz.sostituisce && !opz['thread-id'] && !opz['senza-thread'])
    esci(false, { errore: 'con --sostituisce serve --thread-id (resta nel thread) o --senza-thread' });
  if (opz['se-messaggio'] && !opz.sostituisce) esci(false, { errore: '--se-messaggio vale solo con --sostituisce' });
}
const leggi = f => { try { return fs.readFileSync(f, 'utf8'); } catch (e) { esci(false, { errore: `file non leggibile: ${f} (${e.code})` }); } };
const corpo = LETTURA ? '' : opz['body-file'] ? leggi(opz['body-file']) : opz.body;
const sha256 = b => createHash('sha256').update(b).digest('hex');

const allegati = [];
let codificato = 0;
const nomi = new Set();
for (const f of opz.attach) {
  const p = path.resolve(f);
  if (!fs.existsSync(p) || !fs.statSync(p).isFile()) esci(false, { errore: `allegato non trovato: ${p}` });
  const nome = path.basename(p);
  // Il server scrive il nome fra virgolette nelle intestazioni MIME, senza codificarlo: virgolette e a capo le romperebbero.
  if (/["\r\n\x00-\x1f]/.test(nome)) esci(false, { errore: `nome di file non ammesso (virgolette o caratteri di controllo): ${nome}` });
  if (nomi.has(nome)) esci(false, { errore: `due allegati con lo stesso nome: ${nome}. Rinominane uno: in Gmail non si distinguerebbero` });
  nomi.add(nome);
  const dati = fs.readFileSync(p);
  codificato += Math.ceil(dati.length / 3) * 4;
  allegati.push({ percorso: p, nome, byte: dati.length, sha256: sha256(dati), b64: dati.toString('base64') });
}
if (codificato > MAX_CODIFICATO)
  esci(false, { errore: `allegati troppo grandi: ${(codificato / 1048576).toFixed(1)} MB una volta codificati, oltre il limite di Gmail (25 MB). Usa un link a Drive.` });

// Destinatari: il server accetta solo indirizzi nudi. Gmail web scrive «Nome <indirizzo>» e --leggi li riporta così:
// qui si tiene l'indirizzo e si perde il nome visualizzato (limite noto). Una voce può contenerne più d'uno, con le virgole.
function indirizzi(voci) {
  const fuori = [];
  for (const voce of voci) {
    let pezzo = '', virgolette = false, angolo = false;
    const pezzi = [];
    for (const c of voce) {
      if (c === '"' && !angolo) virgolette = !virgolette;
      else if (c === '<' && !virgolette) angolo = true;
      else if (c === '>' && !virgolette) angolo = false;
      if (c === ',' && !virgolette && !angolo) { pezzi.push(pezzo); pezzo = ''; } else pezzo += c;
    }
    pezzi.push(pezzo);
    for (const p of pezzi.map(x => x.trim()).filter(Boolean)) {
      const a = (p.match(/<([^<>]*)>\s*$/)?.[1] ?? p).trim();
      if (!/^[^\s@<>",]+@[^\s@<>",]+$/.test(a)) esci(false, { errore: `destinatario non valido: ${p}` });
      fuori.push(a);
    }
  }
  return fuori;
}
const args = { to: LETTURA ? [] : indirizzi(opz.to), subject: opz.subject, body: corpo };
if (opz['html-file']) args.html = leggi(opz['html-file']);
if (opz.cc.length) args.cc = indirizzi(opz.cc);
if (opz.bcc.length) args.bcc = indirizzi(opz.bcc);
if (opz['thread-id']) args.threadId = opz['thread-id'];
if (allegati.length) args.attachments = allegati.map(a => ({ filename: a.nome, content: a.b64 }));

// --- il server ---
function trovaServer() {
  if (process.env.METIS_GMAIL_SERVER) return process.env.METIS_GMAIL_SERVER;
  try { return execFileSync('/usr/bin/which', ['google-workspace-mcp'], { encoding: 'utf8' }).trim(); } catch {}
  for (const c of ['/opt/homebrew/bin/google-workspace-mcp', '/usr/local/bin/google-workspace-mcp']) if (fs.existsSync(c)) return c;
  return null;
}
const SERVER = trovaServer();
if (!SERVER) esci(false, { errore: 'server google-workspace-mcp non trovato (METIS_GMAIL_SERVER, PATH, /opt/homebrew/bin, /usr/local/bin)' });

// Senza autorizzazione il server apre il browser e aspetta: prima di avviarlo si controlla che il token ci sia.
// La verifica completa (rinnovo presso Google) la fa scripts/google-token.py, richiamato da «google.sh controlla».
const GDIR = process.env.GOOGLE_WORKSPACE_MCP_TOKEN_PATH ? path.dirname(process.env.GOOGLE_WORKSPACE_MCP_TOKEN_PATH)
  : path.join(process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config'), 'google-workspace-mcp');
try {
  if (!JSON.parse(fs.readFileSync(path.join(GDIR, 'tokens.json'), 'utf8')).refresh_token) throw new Error('senza refresh_token');
} catch (e) {
  esci(false, { errore: `autorizzazione Google assente o incompleta in ${GDIR} (${e.code || e.message}): serve il consenso del cliente (google.sh account-posta)` });
}

// --- client MCP minimo su stdio ---
const t0 = Date.now();
const coda = () => log.join('').slice(-1500);
srv = spawn(SERVER, ['start'], { stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, GOOGLE_WORKSPACE_SERVICES: 'gmail' } });
srv.stderr.on('data', d => { log.push(String(d)); if (log.length > 40) log.shift(); });
srv.on('error', e => esci(false, { errore: `server non avviato: ${e.message}` }));
const attese = new Map();
srv.on('exit', (code, sig) => {
  if (attese.size) esci(false, { errore: `il server si è chiuso (codice ${code}${sig ? ', ' + sig : ''}) prima di rispondere`, log: coda() });
});
timer = setTimeout(() => {
  // Senza un'autorizzazione valida il server apre la pagina di consenso nel browser e aspetta (provato il 23/10/2026).
  const auth = !stato.draftId && /Error saving tokens|authoriz|authenticat|consent/i.test(coda());
  esci(false, { errore: `nessuna risposta in ${TIMEOUT_MS / 1000} s${auth ? ': probabilmente manca l\'autorizzazione Google (il server può aver aperto una pagina nel browser)' : ''}`, log: coda() });
}, TIMEOUT_MS);

let buf = '', prossimo = 1;
srv.stdout.on('data', d => {
  buf += d;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const riga = buf.slice(0, i); buf = buf.slice(i + 1);
    if (!riga.trim()) continue;
    let m;
    try { m = JSON.parse(riga); } catch { continue; }
    if (m.id !== undefined && attese.has(m.id)) { const ok = attese.get(m.id); attese.delete(m.id); ok(m); }
  }
});
const scrivi = m => srv.stdin.write(JSON.stringify(m) + '\n');
const richiesta = (method, params) => new Promise(ok => { const id = prossimo++; attese.set(id, ok); scrivi({ jsonrpc: '2.0', id, method, params }); });

const STRUMENTI = new Set(['draft_email', 'list_drafts', 'read_email', 'download_attachment', 'delete_draft']); // recinto: niente invii
async function chiama(name, a) {
  if (!STRUMENTI.has(name)) throw new Error(`strumento non ammesso: ${name}`);
  const r = await richiesta('tools/call', { name, arguments: a });
  if (r.error) throw new Error(`${name}: ${r.error.message}`);
  if (r.result?.isError) throw new Error(`${name}: ${r.result.content?.map(c => c.text).join(' ')}`);
  if (r.result?.structuredContent) return r.result.structuredContent;
  try { return JSON.parse(r.result.content[0].text); } catch { throw new Error(`${name}: risposta non leggibile`); }
}

// La bozza e il suo messaggio: il server non ha get_draft, quindi si cerca il draftId nell'elenco delle bozze.
async function trovaBozza(draftId) {
  let pageToken;
  for (let pagina = 0; pagina < 20; pagina++) {
    const r = await chiama('list_drafts', { maxResults: 500, ...(pageToken && { pageToken }) });
    const d = (r.drafts || []).find(x => x.draftId === draftId);
    if (d) return d;
    if (!(pageToken = r.nextPageToken)) return null;
  }
  return null;
}

async function leggiBozza(draftId, cartella) {
  const d = await trovaBozza(draftId);
  if (!d) return [false, { errore: `bozza non trovata: ${draftId}` }];
  const m = await chiama('read_email', { id: d.id, contentFormat: 'full' });
  const h = m.headers || {};
  const out = { draftId, messageId: m.id, threadId: m.threadId, to: h.to || '', cc: h.cc || '', bcc: h.bcc || '',
    indirizzi: { to: indirizzi([h.to || '']), cc: indirizzi([h.cc || '']), bcc: indirizzi([h.bcc || '']) },
    subject: h.subject || '', testo: m.body?.text || '', html: !!m.body?.html, troncato: !!m.truncated,
    allegati: (m.attachments || []).map(a => ({ nome: a.filename, byte: a.size })) };
  if (cartella) {
    const dir = path.resolve(cartella);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'corpo.txt'), out.testo);
    if (m.body?.html) fs.writeFileSync(path.join(dir, 'corpo.html'), m.body.html);
    fs.mkdirSync(path.join(dir, 'allegati'), { recursive: true });
    const usati = new Set();
    for (const [n, a] of (m.attachments || []).entries()) {
      // il nome viene dalla bozza: niente percorsi, e due allegati omonimi non si sovrascrivono
      let nome = path.basename(String(a.filename).replace(/[\\/\x00-\x1f]/g, '_'));
      if (!nome || nome === '.' || nome === '..') nome = `allegato-${n}`;
      if (usati.has(nome)) nome = `${n}-${nome}`;
      usati.add(nome);
      const sc = await chiama('download_attachment', { id: m.id, attachmentId: a.id, outputPath: path.join(dir, 'allegati'), filename: nome });
      Object.assign(out.allegati[n], { file: sc.path, sha256: sha256(fs.readFileSync(sc.path)) });
    }
    out.cartella = dir;
  }
  return [!out.troncato, out.troncato ? { ...out, errore: 'testo troncato dal server: non usarlo come base senza controllarlo in Gmail' } : out];
}

try {
  const init = await richiesta('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'gmail-bozza', version: '2' } });
  if (init.error) throw new Error(`initialize: ${init.error.message}`);
  scrivi({ jsonrpc: '2.0', method: 'notifications/initialized' });

  if (LETTURA) esci(...await leggiBozza(opz.leggi, opz['salva-in']));

  if (opz.sostituisce) {
    const vecchia = await trovaBozza(opz.sostituisce);
    if (!vecchia) throw new Error(`bozza da sostituire non trovata: ${opz.sostituisce}. Nessuna bozza creata`);
    if (vecchia.id !== opz['se-messaggio'])
      throw new Error(`la bozza ${opz.sostituisce} è cambiata dopo la lettura (messaggio ${vecchia.id}, letto ${opz['se-messaggio']}): rileggila con --leggi e riparti da quel testo. Nessuna bozza creata`);
  }

  const bozza = await chiama('draft_email', args);
  Object.assign(stato, { draftId: bozza.draftId, messageId: bozza.id, threadId: bozza.threadId });

  // verifica: ogni allegato si riscarica dalla bozza e si confronta con l'originale (i nomi sono unici)
  const verifica = [];
  if (allegati.length) {
    const msg = await chiama('read_email', { id: bozza.id, contentFormat: 'headers' });
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'gmail-bozza-'));
    for (const [n, a] of allegati.entries()) {
      const remoto = (msg.attachments || []).find(x => x.filename === a.nome);
      if (!remoto) { verifica.push({ file: a.nome, ok: false, motivo: 'assente nella bozza' }); continue; }
      const sc = await chiama('download_attachment', { id: bozza.id, attachmentId: remoto.id, outputPath: tmp, filename: `v${n}${path.extname(a.nome)}` });
      const h = sha256(fs.readFileSync(sc.path));
      verifica.push({ file: a.nome, byte: a.byte, sha256: a.sha256, ok: h === a.sha256, ...(h !== a.sha256 && { motivo: 'hash diverso' }) });
    }
  }
  const tuttoOk = verifica.every(v => v.ok);
  const dati = { allegati: verifica };
  if (opz.sostituisce) {
    if (tuttoOk) {
      await chiama('delete_draft', { id: opz.sostituisce });
      dati.sostituita = opz.sostituisce;
    } else dati.avviso = `la bozza vecchia ${opz.sostituisce} NON è stata cancellata: gli allegati della nuova non tornano`;
  }
  esci(tuttoOk, { ...dati, secondi: +((Date.now() - t0) / 1000).toFixed(1) });
} catch (e) {
  esci(false, { errore: e.message, log: coda() });
}
