import fs from 'node:fs';
import { randomUUID, createHash } from 'node:crypto';

export class APIError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export const uuid = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
export function phoneNumber(value) {
  if (typeof value !== 'string' || !/^[+0-9 ().-]+$/.test(value)) return null;
  const result = value.replace(/[ ().-]/g, '').replace(/^(\+|00)/, '');
  return /^[1-9][0-9]{6,14}$/.test(result) ? result : null;
}
export function atomicJSON(file, value) {
  const temp = file + '.' + randomUUID() + '.tmp';
  try {
    const fd = fs.openSync(temp, 'wx', 0o600);
    try { fs.writeFileSync(fd, JSON.stringify(value)); fs.fsyncSync(fd); }
    finally { fs.closeSync(fd); }
    fs.renameSync(temp, file);
  } finally { if (fs.existsSync(temp)) fs.unlinkSync(temp); }
}
const states = new Set(['queued', 'sending', 'submitted', 'delivered', 'read', 'uncertain', 'failed', 'missed', 'cancelled', 'simulated']);
const fingerprint = job => createHash('sha256').update(JSON.stringify([job.recipient, job.message, job.scheduledAt])).digest('hex');
export class Queue {
  constructor(file, { now = () => Date.now(), write = atomicJSON } = {}) {
    this.file = file; this.now = now; this.write = write; this.busy = false;
    if (fs.existsSync(file)) {
      this.data = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (this.data.version !== 1 || !Array.isArray(this.data.jobs) || this.data.jobs.length > 1000 ||
          this.data.jobs.some(j => !uuid(j.id) || !states.has(j.state) || !phoneNumber(j.recipient) ||
            typeof j.message !== 'string' || j.message.length > 4096 || !Number.isFinite(j.scheduledAt) ||
            j.fingerprint !== fingerprint(j)) || new Set(this.data.jobs.map(j => j.id)).size !== this.data.jobs.length) {
        throw new Error('Coda non leggibile. Originale conservato; nessun messaggio verrà inviato.');
      }
    } else { this.data = { version: 1, jobs: [] }; this.write(file, this.data); }
    if (this.data.jobs.some(j => j.state === 'sending')) {
      this.commit(this.data.jobs.map(j => j.state === 'sending'
        ? { ...j, state: 'uncertain', detail: 'Il programma si è interrotto durante l’invio. Controlla la chat prima di riprogrammare.' } : j));
    }
  }
  commit(jobs) { const next = { version: 1, jobs }; this.write(this.file, next); this.data = next; }
  list() { return this.data.jobs.map(j => ({ ...j })).sort((a, b) => b.scheduledAt - a.scheduledAt); }
  add(input) {
    if (!input || Object.keys(input).sort().join(',') !== 'id,message,recipient,scheduledAt' || !uuid(input.id))
      throw new APIError(400, 'Richiesta non valida.');
    const recipient = phoneNumber(input.recipient);
    if (!recipient || typeof input.message !== 'string' || !input.message.trim() || input.message.length > 4096 || !Number.isSafeInteger(input.scheduledAt))
      throw new APIError(400, 'Controlla numero internazionale, testo (massimo 4096 caratteri) e orario.');
    const candidate = { id: input.id.toLowerCase(), recipient, message: input.message, scheduledAt: input.scheduledAt };
    const hash = fingerprint(candidate);
    const existing = this.data.jobs.find(j => j.id === candidate.id);
    if (existing) {
      if (existing.fingerprint !== hash) throw new APIError(409, 'Questa richiesta è già stata usata per un altro messaggio.');
      return { ...existing };
    }
    if (input.scheduledAt < this.now() + 10_000 || input.scheduledAt > this.now() + 366 * 86400_000)
      throw new APIError(400, 'Scegli un orario tra almeno 10 secondi ed entro un anno.');
    if (this.data.jobs.length >= 1000 || this.data.jobs.filter(j => j.state === 'queued').length >= 200)
      throw new APIError(409, 'Limite della coda raggiunto (200 programmati, 1000 totali).');
    const job = { ...candidate, fingerprint: hash, state: 'queued', createdAt: this.now() };
    this.commit([...this.data.jobs, job]);
    return { ...job };
  }
  cancel(id) {
    const job = this.data.jobs.find(j => j.id === id.toLowerCase());
    if (!job) throw new APIError(404, 'Messaggio non trovato.');
    if (job.state === 'cancelled') return { ...job };
    if (job.state !== 'queued') throw new APIError(409, 'Invio già iniziato o messaggio concluso: non è più annullabile.');
    return this.update(job.id, { state: 'cancelled', detail: 'Programmazione annullata.' });
  }
  update(id, changes) {
    this.commit(this.data.jobs.map(j => j.id === id ? { ...j, ...changes } : j));
    return { ...this.data.jobs.find(j => j.id === id) };
  }
  acknowledge(messageID, ack) {
    const job = this.data.jobs.find(j => j.messageID === messageID);
    if (!job || !['submitted', 'delivered', 'read', 'uncertain'].includes(job.state)) return;
    const rank = { uncertain: 0, submitted: 1, delivered: 2, read: 3 };
    const state = ack >= 3 ? 'read' : ack >= 2 ? 'delivered' : ack === 1 ? 'submitted' : null;
    if (state && rank[state] > rank[job.state]) this.update(job.id, { state, detail: undefined });
  }
  async tick(adapter) {
    if (this.busy) return;
    this.busy = true;
    try {
      for (const original of [...this.data.jobs].sort((a, b) => a.scheduledAt - b.scheduledAt)) {
        const job = this.data.jobs.find(j => j.id === original.id);
        if (job.state !== 'queued' || job.scheduledAt > this.now()) continue;
        if (this.now() - job.scheduledAt > 300_000) {
          this.update(job.id, { state: 'missed', detail: 'PC o WhatsApp non disponibili entro 5 minuti dall’orario. Nessun invio tardivo.' });
          continue;
        }
        if (!adapter.ready) continue;
        // Durable claim before any external action. Ambiguous sends are never retried.
        this.update(job.id, { state: 'sending' });
        let timeout;
        try {
          const result = await Promise.race([
            adapter.send(job),
            new Promise((_, reject) => { timeout = setTimeout(() => reject(new Error('timeout')), 45_000); })
          ]);
          this.update(job.id, { state: result.simulated ? 'simulated' : 'submitted', messageID: result.id,
            submittedAt: this.now(), detail: result.simulated ? 'Simulazione: nessun messaggio inviato.' : 'Affidato a WhatsApp; consegna non ancora confermata.' });
          if (!result.simulated && result.ack != null) this.acknowledge(result.id, result.ack);
        } catch (error) {
          this.update(job.id, { state: error.definitelyNotSent ? 'failed' : 'uncertain', detail: error.definitelyNotSent
            ? 'Numero non trovato su WhatsApp. Nessun messaggio inviato.'
            : 'Esito non confermato. Controlla la chat prima di riprogrammare; nessun nuovo tentativo automatico.' });
          // A stuck browser send could still finish: do not start another send this tick.
          return;
        } finally { clearTimeout(timeout); }
      }
    } finally { this.busy = false; }
  }
}
