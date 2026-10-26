#!/usr/bin/env node
// Finta Gmail per le prove di gmail-bozza.mjs: parla MCP su stdio come google-workspace-mcp e tiene le bozze in
// $FINTO_GMAIL/bozze.json. Nessuna rete, nessun account. Registra ogni chiamata in $FINTO_GMAIL/chiamate.log.
// Variabili di prova: FINTO_ALTERA=1 corrompe gli allegati salvati (verifica degli hash), FINTO_TRONCA=1 tronca la lettura.
import fs from 'node:fs';
import path from 'node:path';

const DIR = process.env.FINTO_GMAIL;
const DB = path.join(DIR, 'bozze.json');
const carica = () => { try { return JSON.parse(fs.readFileSync(DB, 'utf8')); } catch { return { n: 0, bozze: [] }; } };
const salva = db => fs.writeFileSync(DB, JSON.stringify(db));
const ok = (id, sc) => process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: 'ok' }], structuredContent: sc } }) + '\n');
const ko = (id, msg) => process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id, result: { isError: true, content: [{ type: 'text', text: msg }] } }) + '\n');

function gestisci(m) {
  if (m.method === 'initialize') return process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: m.id, result: { protocolVersion: '2024-11-05', capabilities: {}, serverInfo: { name: 'finto', version: '0' } } }) + '\n');
  if (m.method !== 'tools/call') return;
  const { name, arguments: a } = m.params;
  fs.appendFileSync(path.join(DIR, 'chiamate.log'), `${name} ${JSON.stringify(a.id ?? a.draftId ?? '')}\n`);
  const db = carica();
  switch (name) {
    case 'draft_email': {
      if (a.draftId) return ko(m.id, 'update non ammesso nella finta Gmail');
      const n = ++db.n;
      const allegati = (a.attachments || []).map((x, i) => ({ id: `att${n}-${i}`, filename: x.filename,
        content: process.env.FINTO_ALTERA ? Buffer.from('alterato').toString('base64') : x.content }));
      const b = { draftId: `r-${n}`, id: `msg${n}`, threadId: a.threadId || `thr${n}`, to: a.to.join(', '), cc: (a.cc || []).join(', '),
        subject: a.subject, text: a.body, html: a.html || '', allegati };
      db.bozze.push(b); salva(db);
      return ok(m.id, { draftId: b.draftId, id: b.id, threadId: b.threadId });
    }
    case 'list_drafts':
      return ok(m.id, { drafts: db.bozze.map(b => ({ draftId: b.draftId, id: b.id, threadId: b.threadId, to: b.to, subject: b.subject })) });
    case 'read_email': {
      const b = db.bozze.find(x => x.id === a.id);
      if (!b) return ko(m.id, 'messaggio non trovato');
      return ok(m.id, { id: b.id, threadId: b.threadId, headers: { to: b.to, ...(b.cc && { cc: b.cc }), subject: b.subject },
        body: a.contentFormat === 'headers' ? undefined : { text: b.text, html: b.html },
        attachments: b.allegati.map(x => ({ id: x.id, filename: x.filename, size: Buffer.from(x.content, 'base64').length })),
        truncated: !!process.env.FINTO_TRONCA });
    }
    case 'download_attachment': {
      const b = db.bozze.find(x => x.id === a.id);
      const x = b?.allegati.find(y => y.id === a.attachmentId);
      if (!x) return ko(m.id, 'allegato non trovato');
      const p = path.join(a.outputPath, a.filename);
      fs.writeFileSync(p, Buffer.from(x.content, 'base64'));
      return ok(m.id, { path: p });
    }
    case 'delete_draft': {
      const i = db.bozze.findIndex(x => x.draftId === a.id);
      if (i < 0) return ko(m.id, 'bozza non trovata');
      db.bozze.splice(i, 1); salva(db);
      return ok(m.id, { deleted: 1, ids: [a.id] });
    }
    default: return ko(m.id, `strumento sconosciuto: ${name}`);
  }
}
let buf = '';
process.stdin.on('data', d => {
  buf += d; let i;
  while ((i = buf.indexOf('\n')) >= 0) { const r = buf.slice(0, i); buf = buf.slice(i + 1); if (r.trim()) gestisci(JSON.parse(r)); }
});
