import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { Queue, phoneNumber } from '../queue.mjs';
import { createServer } from '../server.mjs';

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'idom-wa-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  let now = 1800000000000;
  const file = path.join(dir, 'queue.json');
  const queue = new Queue(file, { now: () => now });
  const input = () => ({ id: randomUUID(), recipient: '+39 333 1234567', message: 'Prova & caffè 👋\nseconda riga', scheduledAt: now + 60_000 });
  return { queue, file, input, advance: ms => { now += ms; }, now: () => now };
}
test('international numbers are normalized without accepting destinations or extensions', () => {
  assert.equal(phoneNumber('+39 (333) 123-4567'), '393331234567');
  assert.equal(phoneNumber('00393331234567'), '393331234567');
  for (const value of ['123', '1234567@g.us', '++393331234567', '０１２３４５６７', 'abc393331234567', '+0123456789']) assert.equal(phoneNumber(value), null);
});
test('invalid text, time, UUID and extra fields are rejected', t => {
  const { queue, input, now } = fixture(t);
  for (const changes of [{ message: ' ' }, { message: 'a'.repeat(4097) }, { scheduledAt: now() }, { scheduledAt: now() + 367 * 86400000 }, { id: 'bad' }, { extra: true }]) {
    assert.throws(() => queue.add({ ...input(), ...changes }));
  }
  assert.equal(queue.list().length, 0);
});
test('durable request id prevents duplicates across restart, including cancelled jobs', t => {
  const f = fixture(t); const request = f.input(); f.queue.add(request);
  const restarted = new Queue(f.file, { now: f.now });
  assert.equal(restarted.add(request).id, request.id);
  assert.equal(restarted.list().length, 1);
  assert.throws(() => restarted.add({ ...request, message: 'different' }));
  restarted.cancel(request.id); assert.equal(restarted.add(request).state, 'cancelled');
});
test('not before schedule; cancellation prevents a send', async t => {
  const f = fixture(t); const job = f.queue.add(f.input()); let sends = 0;
  const adapter = { ready: true, send: async () => { sends++; return { id: 'one' }; } };
  await f.queue.tick(adapter); assert.equal(sends, 0);
  f.queue.cancel(job.id); f.advance(60000); await f.queue.tick(adapter); assert.equal(sends, 0);
});
test('offline waits up to five minutes; missed messages never send after reboot', async t => {
  const f = fixture(t); f.queue.add(f.input()); f.advance(60000);
  await f.queue.tick({ ready: false }); assert.equal(f.queue.list()[0].state, 'queued');
  f.advance(300001); await f.queue.tick({ ready: false }); assert.equal(f.queue.list()[0].state, 'missed');
  const restarted = new Queue(f.file, { now: f.now });
  await restarted.tick({ ready: true, send: () => assert.fail('late send') });
});
test('single flight, durable sending claim, cancellation race and delivery acknowledgements', async t => {
  const f = fixture(t); const job = f.queue.add(f.input()); f.advance(60000);
  let finish; let sends = 0;
  const adapter = { ready: true, send: () => { sends++; return new Promise(resolve => { finish = resolve; }); } };
  const running = f.queue.tick(adapter);
  assert.equal(JSON.parse(fs.readFileSync(f.file)).jobs[0].state, 'sending');
  assert.throws(() => f.queue.cancel(job.id));
  await f.queue.tick(adapter); assert.equal(sends, 1);
  finish({ id: 'sent-1', ack: 1 }); await running;
  assert.equal(f.queue.list()[0].state, 'submitted');
  f.queue.acknowledge('sent-1', 3); f.queue.acknowledge('sent-1', 2);
  assert.equal(f.queue.list()[0].state, 'read');
});
test('ambiguous send is not retried; restart during send remains uncertain', async t => {
  const f = fixture(t); const job = f.queue.add(f.input()); f.advance(60000);
  let sends = 0;
  const adapter = { ready: true, send: async () => { sends++; throw new Error('connection lost'); } };
  await f.queue.tick(adapter); await f.queue.tick(adapter);
  assert.equal(sends, 1); assert.equal(f.queue.list()[0].state, 'uncertain');
  f.queue.update(job.id, { state: 'sending' });
  const restarted = new Queue(f.file, { now: f.now });
  assert.equal(restarted.list()[0].state, 'uncertain'); await restarted.tick(adapter); assert.equal(sends, 1);
});
test('unregistered recipient is a definitive failure; simulation is explicitly marked', async t => {
  const f = fixture(t); f.queue.add(f.input()); f.advance(60000);
  await f.queue.tick({ ready: true, send: async () => { const e = new Error(); e.definitelyNotSent = true; throw e; } });
  assert.equal(f.queue.list()[0].state, 'failed');
  f.queue.add(f.input()); f.advance(60000);
  await f.queue.tick({ ready: true, send: async () => ({ id: 'test', simulated: true }) });
  assert.equal(f.queue.list()[0].state, 'simulated');
});
test('corrupt data is preserved and disk failures prevent external sends', async t => {
  const f = fixture(t); const job = f.queue.add(f.input());
  const before = fs.readFileSync(f.file, 'utf8');
  f.queue.write = () => { throw new Error('disk full'); }; f.advance(60000);
  await assert.rejects(f.queue.tick({ ready: true, send: () => assert.fail('should not send') }));
  assert.equal(f.queue.list()[0].state, 'queued'); assert.equal(fs.readFileSync(f.file, 'utf8'), before);
  fs.writeFileSync(f.file, '{broken'); assert.throws(() => new Queue(f.file));
  assert.equal(fs.readFileSync(f.file, 'utf8'), '{broken');
});
test('HTTP authentication, browser isolation, role, validation, scheduling and cancellation', async t => {
  const f = fixture(t); const token = 'a'.repeat(64);
  const server = createServer({ token, queue: () => f.queue, adapter: { ready: true, connection: 'ready', simulated: true }, health: {} });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}/v1`;
  const headers = { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' };
  assert.equal((await fetch(base + '/status')).status, 401);
  assert.equal((await fetch(base + '/status', { headers: { ...headers, Origin: 'https://attacker.example' } })).status, 403);
  const status = await (await fetch(base + '/status', { headers })).json(); assert.equal(status.role, 'whatsapp');
  assert.equal(status.simulated, true);
  const input = f.input();
  const add = () => fetch(base + '/jobs', { method: 'POST', headers, body: JSON.stringify(input) });
  assert.equal((await add()).status, 200); assert.equal((await add()).status, 200); assert.equal(f.queue.list().length, 1);
  assert.equal((await fetch(base + '/jobs', { method: 'POST', headers, body: '{bad' })).status, 400);
  assert.equal((await fetch(base + '/jobs', { method: 'POST', headers, body: JSON.stringify({ ...input, message: 'x'.repeat(40000) }) })).status, 413);
  assert.equal((await fetch(base + '/jobs/' + input.id + '/cancel', { method: 'POST', headers, body: '{}' })).status, 200);
  assert.equal(f.queue.list()[0].state, 'cancelled');
  assert.equal((await fetch(base + '/shutdown', { method: 'POST', headers, body: '{}' })).status, 404);
});

test('changing the linked WhatsApp account cannot send an existing scheduled message', async t => {
  const f = fixture(t); f.queue.add(f.input(), 'original-account'); f.advance(60000);
  await f.queue.tick({ ready: true, account: 'different-account', send: () => assert.fail('wrong sender') });
  assert.equal(f.queue.list()[0].state, 'failed');
  assert.match(f.queue.list()[0].detail, /Account WhatsApp cambiato/);
});
