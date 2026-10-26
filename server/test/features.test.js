'use strict';
/**
 * Tests des fonctions v5 du serveur : node --test server/test/
 * Les appels externes (CinetPay, Twilio, Anthropic) sont simulés : aucun accès réseau.
 */
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

// Environnement de test (avant de charger le serveur)
const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lago-test-'));
Object.assign(process.env, {
  DATA_DIR: dataDir,
  DEMO_MODE: 'true',
  LAGO_SECRET: 'x'.repeat(40),
  PUBLIC_URL: 'https://api.example.test',
  CINETPAY_APIKEY: 'key',
  CINETPAY_SITE_ID: 'site',
  CINETPAY_SECRET_KEY: 'secret',
  MESSAGING_PROVIDER: 'webhook',
  MESSAGING_WEBHOOK_URL: 'https://hooks.example.test/sms',
  ANTHROPIC_API_KEY: 'test-key'
});

// Faux réseau
const calls = [];
let cinetpayStatus = 'ACCEPTED';
const realFetch = global.fetch;
global.fetch = async (url, opts = {}) => {
  const u = String(url);
  if (u.startsWith('http://127.0.0.1')) return realFetch(url, opts);
  calls.push({ url: u, body: opts.body });
  const json = obj => ({ ok: true, status: 200, json: async () => obj });
  if (u.endsWith('/v2/payment')) return json({ code: '201', data: { payment_url: 'https://checkout.cinetpay.com/payment/abc', payment_token: 't' } });
  if (u.endsWith('/v2/payment/check')) return json({ code: '00', data: { status: cinetpayStatus } });
  if (u.startsWith('https://hooks.example.test')) return json({});
  if (u.startsWith('https://api.anthropic.com')) return json({ content: [{ type: 'text', text: 'Réponse de test.' }] });
  throw new Error('URL inattendue ' + u);
};

const { server, db } = require('../server.js');
const features = require('../features.js');
let base;

test.before(async () => {
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
test.after(() => {
  if (db.writeTimer) clearTimeout(db.writeTimer);
  db.writeTimer = null;
  db.flush();
  server.close();
  fs.rmSync(dataDir, { recursive: true, force: true });
});

async function api(method, p, body, token, headers = {}) {
  const res = await realFetch(base + p, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
    body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body)
  });
  const text = await res.text();
  let data = null;
  try { data = JSON.parse(text); } catch (e) { data = text; }
  return { status: res.status, data };
}

async function login(email, password) {
  const r = await api('POST', '/api/auth/login', { email, password });
  assert.strictEqual(r.status, 200, JSON.stringify(r.data));
  return r.data;
}

test('fonctions disponibles annoncées à l’app', async () => {
  const r = await api('GET', '/api/features');
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.data.premium.enabled, true);
  assert.strictEqual(r.data.premium.currency, 'XAF');
  assert.deepStrictEqual(r.data.premium.plans.map(p => p.amount), [500, 4000]);
  assert.strictEqual(r.data.messaging.enabled, true);
  assert.strictEqual(r.data.assistant.enabled, true);
});

test('nouveaux champs : modes de vie et signes de fertilité acceptés et filtrés', async () => {
  const { token } = await login('sarah@lago.app', 'user123');
  let r = await api('POST', '/api/cycle/settings', { settings: { lifeMode: 'pregnancy', contraception: 'implant', pregnancyStartDate: '2026-09-01', dataSaver: true, lifeModeX: 'bad' } }, token);
  assert.strictEqual(r.data.settings.lifeMode, 'pregnancy');
  assert.strictEqual(r.data.settings.contraception, 'implant');
  assert.strictEqual(r.data.settings.pregnancyStartDate, '2026-09-01');
  assert.strictEqual(r.data.settings.dataSaver, true);
  assert.strictEqual(r.data.settings.lifeModeX, undefined);
  r = await api('POST', '/api/cycle/settings', { settings: { lifeMode: 'nimporte', contraception: '???' } }, token);
  assert.strictEqual(r.data.settings.lifeMode, 'pregnancy');
  r = await api('POST', '/api/cycle/import', { mode: 'merge', logs: { '2026-10-01': { flow: 'none', ovulationTest: 'positive', mucus: 'eggwhite' }, '2026-10-02': { ovulationTest: 'hack', mucus: '<b>' } } }, token);
  assert.strictEqual(r.status, 200, JSON.stringify(r.data));
  const logs = (await api('GET', '/api/cycle/logs', undefined, token)).data.logs;
  assert.strictEqual(logs['2026-10-01'].ovulationTest, 'positive');
  assert.strictEqual(logs['2026-10-01'].mucus, 'eggwhite');
  assert.strictEqual(logs['2026-10-02'].ovulationTest, '');
  assert.strictEqual(logs['2026-10-02'].mucus, '');
  await api('POST', '/api/cycle/settings', { settings: { lifeMode: 'cycle' } }, token);
});

test('Premium CinetPay : paiement, notification signée, vérification', async () => {
  const { token, user } = await login('lea@lago.app', 'user123');
  let r = await api('GET', '/api/premium/status', undefined, token);
  assert.strictEqual(r.data.premium, false);

  r = await api('POST', '/api/premium/checkout', { plan: 'month' }, token);
  assert.strictEqual(r.status, 200, JSON.stringify(r.data));
  assert.match(r.data.paymentUrl, /^https:\/\/checkout\.cinetpay\.com/);
  const sentInit = JSON.parse(calls.find(c => c.url.endsWith('/v2/payment')).body);
  assert.strictEqual(sentInit.amount % 5, 0);
  assert.strictEqual(sentInit.notify_url, 'https://api.example.test/api/premium/notify');
  const tx = r.data.transactionId;

  // Notification avec un mauvais jeton : ignorée
  const form = new URLSearchParams({ cpm_site_id: 'site', cpm_trans_id: tx, cpm_trans_date: '2026-10-26', cpm_amount: '500', cpm_currency: 'XAF' });
  r = await api('POST', '/api/premium/notify', form.toString(), null, { 'Content-Type': 'application/x-www-form-urlencoded', 'x-token': 'faux' });
  assert.strictEqual(r.status, 200);
  assert.strictEqual((await api('GET', '/api/premium/status', undefined, token)).data.premium, false);

  // Notification correctement signée : Premium activé après vérification /check
  const fields = ['cpm_site_id', 'cpm_trans_id', 'cpm_trans_date', 'cpm_amount', 'cpm_currency', 'signature', 'payment_method', 'cel_phone_num',
    'cpm_phone_prefixe', 'cpm_language', 'cpm_version', 'cpm_payment_config', 'cpm_page_action', 'cpm_custom', 'cpm_designation', 'cpm_error_message'];
  const goodToken = crypto.createHmac('sha256', 'secret').update(fields.map(f => form.get(f) || '').join('')).digest('hex');
  r = await api('POST', '/api/premium/notify', form.toString(), null, { 'Content-Type': 'application/x-www-form-urlencoded', 'x-token': goodToken });
  assert.strictEqual(r.status, 200);
  const status = (await api('GET', '/api/premium/status', undefined, token)).data;
  assert.strictEqual(status.premium, true);
  const until1 = status.until;

  // Notification répétée : pas de double prolongation
  await api('POST', '/api/premium/notify', form.toString(), null, { 'Content-Type': 'application/x-www-form-urlencoded', 'x-token': goodToken });
  assert.strictEqual((await api('GET', '/api/premium/status', undefined, token)).data.until, until1);

  // Vérification par l'app d'un paiement refusé
  cinetpayStatus = 'REFUSED';
  const r2 = await api('POST', '/api/premium/checkout', { plan: 'year' }, token);
  r = await api('POST', '/api/premium/verify', { transactionId: r2.data.transactionId }, token);
  assert.strictEqual(r.data.status, 'REFUSED');
  cinetpayStatus = 'ACCEPTED';
  assert.ok(features.isPremium(db, user.id));
});

test('rappels SMS / WhatsApp : consentement, format, envoi discret', async () => {
  const { token, user } = await login('sarah@lago.app', 'user123');
  let r = await api('POST', '/api/messaging', { phone: '0612', channel: 'sms', consent: true }, token);
  assert.strictEqual(r.status, 400);
  r = await api('POST', '/api/messaging', { phone: '+237 699 00 00 00', channel: 'whatsapp', consent: false }, token);
  assert.strictEqual(r.status, 400);
  r = await api('POST', '/api/messaging', { phone: '+237 699 00 00 00', channel: 'whatsapp', consent: true, daysBefore: 2 }, token);
  assert.strictEqual(r.status, 200, JSON.stringify(r.data));
  assert.strictEqual(r.data.subscription.phone, '+237699000000');

  // Règles prévues dans 2 jours
  const today = new Date(2026, 9, 26);
  db.data.settings[user.id] = { ...db.data.settings[user.id], lastPeriodDate: '2026-09-30', cycleLength: 28, lifeMode: 'cycle' };
  const before = calls.length;
  const sent = await features.runDailyReminders(db, today);
  assert.strictEqual(sent, 1);
  const msg = JSON.parse(calls[before].body);
  assert.strictEqual(msg.channel, 'whatsapp');
  assert.ok(!/règles/i.test(msg.text), 'texte discret par défaut');
  assert.strictEqual(await features.runDailyReminders(db, today), 0, 'pas de doublon le même jour');

  r = await api('POST', '/api/messaging', { enabled: false }, token);
  assert.strictEqual(r.data.subscription, null);
});

test('assistant et communauté anonyme modérée', async () => {
  const { token } = await login('sarah@lago.app', 'user123');
  let r = await api('POST', '/api/assistant', { question: 'Est-ce normal d’avoir des crampes ?' }, token);
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.data.answer, 'Réponse de test.');

  r = await api('POST', '/api/community/questions', { question: 'Comment soulager les douleurs de règles naturellement ?', topic: 'cycle' }, token);
  assert.strictEqual(r.status, 201);
  r = await api('GET', '/api/community/questions', undefined, token);
  assert.strictEqual(r.data.questions.length, 0, 'invisible avant modération');

  const admin = await login('admin@lago.app', 'admin123');
  const pending = (await api('GET', '/api/admin/community', undefined, admin.token)).data.questions;
  assert.strictEqual(pending[0].status, 'pending');
  r = await api('POST', '/api/admin/community', { id: pending[0].id, action: 'approve', answer: 'Bouillotte, repos, et consultez si la douleur est forte.' }, admin.token);
  assert.strictEqual(r.status, 200);
  const pub = (await api('GET', '/api/community/questions', undefined, token)).data.questions;
  assert.strictEqual(pub.length, 1);
  assert.strictEqual(pub[0].userId, undefined, 'jamais l’identité de l’autrice');
  assert.ok(pub[0].answer.startsWith('Bouillotte'));

  r = await api('GET', '/api/admin/community', undefined, token);
  assert.strictEqual(r.status, 403);
});

test('partenaires et statistiques anonymisées', async () => {
  const admin = await login('admin@lago.app', 'admin123');
  let r = await api('POST', '/api/admin/partners', { name: 'Pharmacie du Lac', type: 'pharmacy', city: 'Yaoundé', promoCode: 'LAGO10', url: 'javascript:alert(1)' }, admin.token);
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.data.partner.url, '', 'seuls les liens https sont acceptés');
  r = await api('GET', '/api/partners');
  assert.strictEqual(r.data.partners[0].name, 'Pharmacie du Lac');

  r = await api('GET', '/api/admin/aggregate', undefined, admin.token);
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.data.aggregate.totalUsers, '<10', 'petits groupes masqués');
  assert.strictEqual(r.data.aggregate.averageCycleLength, null);
  r = await api('GET', '/api/admin/aggregate?format=csv', undefined, admin.token);
  assert.match(r.data, /"indicateur";"valeur"/);
});

test('suppression du compte : données v5 effacées', async () => {
  const r0 = await api('POST', '/api/auth/register', { name: 'Test', email: 'test5@lago.app', password: 'secret123', age: 20 });
  assert.strictEqual(r0.status, 201, JSON.stringify(r0.data));
  const token = r0.data.token;
  const id = r0.data.user.id;
  await api('POST', '/api/messaging', { phone: '+237699111111', channel: 'sms', consent: true }, token);
  assert.ok(db.data.messaging[id]);
  const r = await api('DELETE', '/api/auth/account', undefined, token);
  assert.strictEqual(r.status, 200);
  assert.strictEqual(db.data.messaging[id], undefined);
});

test('prochaine date de règles côté serveur', () => {
  const next = features.nextPeriod({ lastPeriodDate: '2026-09-01', cycleLength: 28 }, new Date(2026, 9, 26));
  assert.strictEqual(next.getDate(), 27);
  assert.strictEqual(next.getMonth(), 9);
});
