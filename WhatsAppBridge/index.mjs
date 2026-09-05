import fs from 'node:fs';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { Queue, atomicJSON } from './queue.mjs';
import { createServer } from './server.mjs';

const args = process.argv.slice(2);
const flag = name => args.includes(name);
const dataIndex = args.indexOf('--data');
if (dataIndex < 0 || !args[dataIndex + 1]) throw new Error('Specifica --data con la cartella privata dei dati.');
const directory = path.resolve(args[dataIndex + 1]);
fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
const configFile = path.join(directory, 'config.json');
if (flag('--init')) {
  if (!fs.existsSync(configFile)) {
    const fd = fs.openSync(configFile, 'wx', 0o600);
    fs.writeFileSync(fd, JSON.stringify({ token: randomBytes(32).toString('hex') }));
    fs.closeSync(fd);
  }
  console.log('Configurazione pronta.');
  process.exit(0);
}
const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
if (!/^[0-9a-f]{64}$/.test(config.token)) throw new Error('Configurazione non valida.');
const port = 47322;
if (flag('--pair')) {
  const { default: qrCode } = await import('qrcode-terminal');
  let last = '';
  console.log('Su iPhone: WhatsApp > Impostazioni > Dispositivi collegati > Collega un dispositivo.');
  console.log('Scansiona il QR qui sotto. Questa finestra non invia messaggi.');
  const until = Date.now() + 5 * 60_000;
  while (Date.now() < until) {
    const response = await fetch(`http://127.0.0.1:${port}/v1/qr`, { headers: { Authorization: 'Bearer ' + config.token }, signal: AbortSignal.timeout(5000) });
    if (!response.ok) throw new Error('Componente non raggiungibile. Riavvia iDom WhatsApp da Utilità di pianificazione.');
    const status = await response.json();
    if (status.connection === 'ready') { console.log('WhatsApp collegato. Puoi chiudere questa finestra.'); process.exit(0); }
    if (status.qr && status.qr !== last) { last = status.qr; qrCode.generate(last, { small: true }); }
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  console.log('Tempo scaduto. Riapri Collega-WhatsApp.ps1 per riprovare.');
  process.exit(1);
}

const adapter = { ready: false, simulated: flag('--dry-run'), connection: 'starting', qr: null, account: null };
const health = { error: null };
let queue;
const server = createServer({ token: config.token, queue: () => queue, adapter, health });
server.requestTimeout = 10_000; server.headersTimeout = 10_000;
server.on('error', () => { console.error('Porta occupata o servizio già avviato.'); process.exit(1); });
// Bind first so a second instance cannot change the queue of a running sender.
await new Promise(resolve => server.listen(port, '127.0.0.1', resolve));
try { queue = new Queue(path.join(directory, adapter.simulated ? 'simulation-queue.json' : 'queue.json')); }
catch { health.error = 'Coda non leggibile. Originali conservati; invii bloccati.'; }
let client;
if (!health.error) {
  if (adapter.simulated) {
    adapter.ready = true; adapter.connection = 'ready';
    adapter.send = async () => ({ id: 'simulation', simulated: true });
  } else {
    const { default: WhatsApp } = await import('whatsapp-web.js');
    const browserCandidates = [process.env.IDOM_BROWSER,
      path.join(process.env['ProgramFiles(x86)'] || '', 'Microsoft/Edge/Application/msedge.exe'),
      path.join(process.env.ProgramFiles || '', 'Microsoft/Edge/Application/msedge.exe'),
      path.join(process.env.ProgramFiles || '', 'Google/Chrome/Application/chrome.exe')].filter(Boolean);
    const executablePath = browserCandidates.find(file => fs.existsSync(file));
    if (!executablePath) {
      health.error = 'Installa Microsoft Edge o Google Chrome sul PC, poi riavvia iDom WhatsApp.';
    } else {
      client = new WhatsApp.Client({
        authStrategy: new WhatsApp.LocalAuth({ dataPath: path.join(directory, 'session') }),
        puppeteer: { executablePath, headless: true },
        webVersionCache: { type: 'local', path: path.join(directory, 'web-cache') },
        deviceName: 'iDom sul mio PC', authTimeoutMs: 120_000, qrMaxRetries: 0
      });
      client.on('qr', value => { adapter.qr = value; adapter.ready = false; adapter.connection = 'pairing'; });
      client.on('ready', () => {
        adapter.qr = null; adapter.account = client.info?.wid?.user || null;
        adapter.ready = Boolean(adapter.account); adapter.connection = adapter.ready ? 'ready' : 'disconnected';
      });
      client.on('auth_failure', () => { adapter.qr = null; adapter.ready = false; adapter.connection = 'disconnected'; });
      client.on('disconnected', () => {
        adapter.qr = null; adapter.ready = false; adapter.connection = 'disconnected';
        // Let Task Scheduler restart the process; never retry an already claimed message.
        setTimeout(() => process.exit(1), 5000);
      });
      client.on('message_ack', (message, ack) => {
        try { queue.acknowledge(message.id._serialized, ack); }
        catch { health.error = 'Salvataggio stato non riuscito. Invii sospesi: controlla il PC.'; adapter.ready = false; }
      });
      adapter.send = async job => {
        const recipient = await client.getNumberId(job.recipient);
        if (!recipient) { const error = new Error('Numero non registrato'); error.definitelyNotSent = true; throw error; }
        const sent = await client.sendMessage(recipient._serialized, job.message, { sendSeen: false, linkPreview: false });
        if (!sent?.id?._serialized) throw new Error('Conferma mancante');
        return { id: sent.id._serialized, ack: sent.ack };
      };
      client.initialize().catch(() => { health.error = 'Avvio WhatsApp non riuscito. Riavvia il componente sul PC.'; adapter.ready = false; });
    }
  }
}
setInterval(() => {
  if (queue && !health.error) queue.tick(adapter).catch(() => {
    health.error = 'Salvataggio coda non riuscito. Invii sospesi; controlla spazio e permessi sul PC.'; adapter.ready = false;
  });
}, 1000);
const stop = async () => { adapter.ready = false; server.close(); if (client) await client.destroy().catch(() => {}); process.exit(0); };
process.on('SIGINT', stop); process.on('SIGTERM', stop);
console.log('iDom WhatsApp disponibile solo tramite collegamento autenticato.');
