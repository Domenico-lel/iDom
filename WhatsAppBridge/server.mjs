import http from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { APIError, uuid } from './queue.mjs';

export function createServer({ token, queue, adapter, health }) {
  return http.createServer(async (req, res) => {
    const reply = (status, value) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      res.end(JSON.stringify(value));
    };
    try {
      if (req.headers.origin || req.headers['sec-fetch-site']) throw new APIError(403, 'Usa iDom per accedere al componente.');
      const credential = req.headers.authorization || '';
      const expected = 'Bearer ' + token;
      if (Buffer.byteLength(credential) !== Buffer.byteLength(expected) || !timingSafeEqual(Buffer.from(credential), Buffer.from(expected)))
        throw new APIError(401, 'Chiave di collegamento errata.');
      if (req.method === 'GET' && req.url === '/v1/status') {
        return reply(200, { protocolVersion: 1, role: 'whatsapp', name: 'iDom WhatsApp',
          simulated: adapter.simulated, connection: adapter.connection, error: health.error,
          account: adapter.account || null, jobs: queue()?.list() || [] });
      }
      if (req.method === 'GET' && req.url === '/v1/qr') return reply(200, { qr: adapter.qr, connection: adapter.connection });
      if (!queue() || health.error) throw new APIError(503, 'Componente non pronto: controlla il PC.');
      if (req.method !== 'POST') throw new APIError(404, 'Operazione non disponibile.');
      if (req.headers['content-type']?.split(';')[0] !== 'application/json') throw new APIError(415, 'Richiesto JSON.');
      let size = 0; const chunks = [];
      for await (const chunk of req) {
        size += chunk.length;
        if (size > 32768) throw new APIError(413, 'Richiesta troppo grande.');
        chunks.push(chunk);
      }
      let body;
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
      catch { throw new APIError(400, 'JSON non valido.'); }
      if (req.url === '/v1/jobs') {
        if (!adapter.ready) throw new APIError(409, 'Collega WhatsApp sul PC prima di programmare.');
        return reply(200, queue().add(body));
      }
      const cancel = req.url.match(/^\/v1\/jobs\/([^/]+)\/cancel$/);
      if (cancel && uuid(cancel[1]) && body && Object.keys(body).length === 0) return reply(200, queue().cancel(cancel[1]));
      throw new APIError(404, 'Operazione non disponibile.');
    } catch (error) {
      reply(error.status || 500, { error: error instanceof APIError ? error.message : 'Operazione non riuscita; controlla lo stato prima di riprovare.' });
    }
  });
}
