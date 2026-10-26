/**
 * LaGo 🌸 — Fonctions v5 côté serveur (module séparé de server.js)
 *
 *  - Premium par Mobile Money via CinetPay (MTN MoMo, Orange Money, cartes…)
 *  - Rappels par SMS / WhatsApp (sur consentement, texte discret par défaut)
 *  - Assistant de questions-réponses (optionnel, nécessite ANTHROPIC_API_KEY)
 *  - Communauté anonyme modérée (questions / réponses validées par l'équipe)
 *  - Partenaires (pharmacies, ONG, téléconsultation)
 *  - Statistiques anonymisées pour les ONG (groupes d'au moins 10 personnes)
 *
 * Variables d'environnement (toutes facultatives : sans elles, la fonction est simplement désactivée) :
 *   PUBLIC_URL               URL publique du serveur (ex. https://api.lago.app) — nécessaire pour CinetPay
 *   CINETPAY_APIKEY, CINETPAY_SITE_ID, CINETPAY_SECRET_KEY
 *   PREMIUM_CURRENCY         XAF (défaut) ou XOF, CDF, GNF, USD
 *   PREMIUM_PRICE_MONTH      prix du mois (défaut 500)
 *   PREMIUM_PRICE_YEAR       prix de l'année (défaut 4000)
 *   MESSAGING_PROVIDER       'twilio' ou 'webhook'
 *   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_SMS, TWILIO_FROM_WHATSAPP
 *   MESSAGING_WEBHOOK_URL    (provider 'webhook') reçoit POST {to, channel, text}
 *   MESSAGING_HOUR           heure d'envoi des rappels (défaut 9, heure du serveur)
 *   ANTHROPIC_API_KEY        active l'assistant en ligne
 *   ASSISTANT_MODEL          modèle utilisé (défaut claude-haiku-4-5)
 */
'use strict';

const crypto = require('crypto');

const env = (k, d = '') => (process.env[k] === undefined ? d : process.env[k]);

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
function premiumConfig() {
  const currency = ['XAF', 'XOF', 'CDF', 'GNF', 'USD'].includes(env('PREMIUM_CURRENCY')) ? env('PREMIUM_CURRENCY') : 'XAF';
  const round5 = n => (currency === 'USD' ? n : Math.max(5, Math.round(n / 5) * 5)); // CinetPay : multiple de 5
  const month = round5(parseInt(env('PREMIUM_PRICE_MONTH', '500'), 10) || 500);
  const year = round5(parseInt(env('PREMIUM_PRICE_YEAR', '4000'), 10) || 4000);
  return {
    enabled: Boolean(env('CINETPAY_APIKEY') && env('CINETPAY_SITE_ID') && env('PUBLIC_URL')),
    currency,
    plans: [
      { id: 'month', label: '1 mois', days: 31, amount: month },
      { id: 'year', label: '12 mois', days: 366, amount: year }
    ]
  };
}

function messagingConfig() {
  const provider = env('MESSAGING_PROVIDER');
  const ok =
    (provider === 'twilio' && env('TWILIO_ACCOUNT_SID') && env('TWILIO_AUTH_TOKEN') && (env('TWILIO_FROM_SMS') || env('TWILIO_FROM_WHATSAPP'))) ||
    (provider === 'webhook' && env('MESSAGING_WEBHOOK_URL'));
  return {
    enabled: Boolean(ok),
    provider,
    channels: provider === 'twilio'
      ? [env('TWILIO_FROM_SMS') && 'sms', env('TWILIO_FROM_WHATSAPP') && 'whatsapp'].filter(Boolean)
      : ['sms', 'whatsapp'],
    hour: Math.min(23, Math.max(0, parseInt(env('MESSAGING_HOUR', '9'), 10) || 9))
  };
}

const PHONE_RE = /^\+[1-9]\d{7,14}$/; // format international E.164
const MIN_GROUP = 10; // k-anonymat des statistiques ONG

// ---------------------------------------------------------------------------
// Outils
// ---------------------------------------------------------------------------
function ensureCollections(db) {
  const d = db.data;
  d.payments = d.payments || [];
  d.premium = d.premium || {};
  d.messaging = d.messaging || {};
  d.messagingLog = d.messagingLog || {};
  d.community = d.community || [];
  d.partners = d.partners || [];
}

function readRawBody(req, limit = 64 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', c => {
      size += c.length;
      if (size > limit) {
        reject(Object.assign(new Error('Requête trop volumineuse'), { status: 413 }));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    req.on('error', reject);
  });
}

function isoDay(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function parseIso(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const [y, m, d] = s.split('-').map(Number);
  const dt = new Date(y, m - 1, d);
  return dt.getMonth() === m - 1 ? dt : null;
}

function addDays(d, n) {
  const r = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  r.setDate(r.getDate() + n);
  return r;
}

function diffDays(a, b) {
  return Math.round((Date.UTC(a.getFullYear(), a.getMonth(), a.getDate()) - Date.UTC(b.getFullYear(), b.getMonth(), b.getDate())) / 86400000);
}

function sanitizeText(s, max) {
  return String(s || '').replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '').trim().slice(0, max);
}

/** Prochaine date de règles estimée à partir des réglages (même règle que l'app). */
function nextPeriod(settings, today = new Date()) {
  const lmp = parseIso(settings && settings.lastPeriodDate);
  if (!lmp) return null;
  const len = Math.min(60, Math.max(15, parseInt(settings.cycleLength, 10) || 28));
  let start = lmp;
  const t = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  while (diffDays(addDays(start, len), t) < 0) start = addDays(start, len);
  return addDays(start, len);
}

function isPremium(db, userId, now = Date.now()) {
  const p = db.data.premium && db.data.premium[userId];
  return Boolean(p && Date.parse(p.until) > now);
}

// ---------------------------------------------------------------------------
// CinetPay
// ---------------------------------------------------------------------------
const CINETPAY_URL = 'https://api-checkout.cinetpay.com/v2/payment';

async function cinetpayCheck(transactionId, fetchImpl = fetch) {
  const res = await fetchImpl(`${CINETPAY_URL}/check`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'User-Agent': 'LaGo/5.0' },
    body: JSON.stringify({ apikey: env('CINETPAY_APIKEY'), site_id: env('CINETPAY_SITE_ID'), transaction_id: transactionId })
  });
  const json = await res.json().catch(() => ({}));
  return (json && json.data && json.data.status) || 'UNKNOWN';
}

/** Vérifie le jeton HMAC (en-tête x-token) envoyé par CinetPay avec la notification. */
function verifyCinetpayToken(form, token, secret = env('CINETPAY_SECRET_KEY')) {
  if (!secret) return true; // clé secrète non configurée : on s'appuie uniquement sur /check
  if (!token) return false;
  const fields = ['cpm_site_id', 'cpm_trans_id', 'cpm_trans_date', 'cpm_amount', 'cpm_currency', 'signature', 'payment_method',
    'cel_phone_num', 'cpm_phone_prefixe', 'cpm_language', 'cpm_version', 'cpm_payment_config', 'cpm_page_action', 'cpm_custom',
    'cpm_designation', 'cpm_error_message'];
  const data = fields.map(f => form.get(f) || '').join('');
  const expected = crypto.createHmac('sha256', secret).update(data).digest('hex');
  const a = Buffer.from(expected);
  const b = Buffer.from(String(token));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/** Active (ou prolonge) le Premium d'une utilisatrice après un paiement accepté. */
function grantPremium(db, payment) {
  if (payment.status === 'ACCEPTED') return false; // déjà traité (les notifications peuvent arriver plusieurs fois)
  payment.status = 'ACCEPTED';
  payment.paidAt = new Date().toISOString();
  const current = db.data.premium[payment.userId];
  const from = current && Date.parse(current.until) > Date.now() ? new Date(current.until) : new Date();
  from.setDate(from.getDate() + payment.days);
  db.data.premium[payment.userId] = { until: from.toISOString(), plan: payment.plan, lastPayment: payment.id };
  return true;
}

// ---------------------------------------------------------------------------
// Messagerie (SMS / WhatsApp)
// ---------------------------------------------------------------------------
async function sendMessage(to, channel, text, fetchImpl = fetch) {
  const cfg = messagingConfig();
  if (!cfg.enabled) return false;
  if (cfg.provider === 'webhook') {
    const res = await fetchImpl(env('MESSAGING_WEBHOOK_URL'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ to, channel, text })
    });
    return res.ok;
  }
  // Twilio
  const from = channel === 'whatsapp' ? `whatsapp:${env('TWILIO_FROM_WHATSAPP')}` : env('TWILIO_FROM_SMS');
  const dest = channel === 'whatsapp' ? `whatsapp:${to}` : to;
  const body = new URLSearchParams({ From: from, To: dest, Body: text });
  const auth = Buffer.from(`${env('TWILIO_ACCOUNT_SID')}:${env('TWILIO_AUTH_TOKEN')}`).toString('base64');
  const res = await fetchImpl(`https://api.twilio.com/2010-04-01/Accounts/${env('TWILIO_ACCOUNT_SID')}/Messages.json`, {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body
  });
  return res.ok;
}

/** Texte du rappel. Discret par défaut : aucun mot lié aux règles. */
function reminderText(kind, discreet, days) {
  if (discreet) return 'LaGo 🌸 : petit rappel bien-être. Ouvrez l’application pour en savoir plus.';
  if (kind === 'periodSoon') return `LaGo 🌸 : vos règles sont prévues dans ${days} jour${days > 1 ? 's' : ''}. Pensez à prévoir vos protections.`;
  if (kind === 'periodStart') return 'LaGo 🌸 : vos règles sont prévues aujourd’hui. Notez-les dans votre journal.';
  return 'LaGo 🌸 : un petit rappel de votre application.';
}

/** Envoie les rappels du jour. Renvoie le nombre de messages envoyés. */
async function runDailyReminders(db, today = new Date(), sender = sendMessage) {
  ensureCollections(db);
  const todayIso = isoDay(today);
  let sent = 0;
  for (const [userId, sub] of Object.entries(db.data.messaging)) {
    if (!sub || !sub.enabled || !sub.consent || !PHONE_RE.test(sub.phone || '')) continue;
    const user = db.data.users.find(u => u.id === userId);
    if (!user || user.status === 'blocked') continue;
    const settings = db.data.settings[userId];
    if (settings && settings.lifeMode && settings.lifeMode !== 'cycle') continue; // grossesse, etc. : pas de rappel de règles
    const next = nextPeriod(settings, today);
    if (!next) continue;
    const days = diffDays(next, today);
    const soon = Math.min(5, Math.max(1, parseInt(sub.daysBefore, 10) || 2));
    let kind = null;
    if (days === soon) kind = 'periodSoon';
    else if (days === 0) kind = 'periodStart';
    if (!kind) continue;
    const key = `${todayIso}|${kind}`;
    if ((db.data.messagingLog[userId] || []).includes(key)) continue; // déjà envoyé aujourd'hui
    try {
      if (await sender(sub.phone, sub.channel, reminderText(kind, sub.discreet !== false, days))) {
        db.data.messagingLog[userId] = [key, ...(db.data.messagingLog[userId] || [])].slice(0, 20);
        sent++;
      }
    } catch (e) {
      console.error('[Messagerie]', e.message);
    }
  }
  if (sent) db.save();
  return sent;
}

function startScheduler(db) {
  const cfg = messagingConfig();
  if (!cfg.enabled) return null;
  let lastRun = '';
  const timer = setInterval(() => {
    const now = new Date();
    const day = isoDay(now);
    if (now.getHours() === cfg.hour && lastRun !== day) {
      lastRun = day;
      runDailyReminders(db, now).catch(e => console.error('[Messagerie]', e));
    }
  }, 5 * 60 * 1000);
  timer.unref();
  return timer;
}

// ---------------------------------------------------------------------------
// Assistant
// ---------------------------------------------------------------------------
const ASSISTANT_SYSTEM = [
  'Tu es l’assistante santé de LaGo, une application de suivi du cycle menstruel utilisée surtout en Afrique francophone, y compris par des adolescentes.',
  'Réponds dans la langue de la question, avec bienveillance, en 120 mots maximum, avec des informations médicales reconnues et sans jugement.',
  'Tu ne poses jamais de diagnostic et tu ne prescris aucun médicament ni dosage.',
  'Pour toute douleur intense, saignement très abondant, fièvre, retard de règles avec possible grossesse, violence ou situation urgente, conseille de consulter rapidement un professionnel de santé ou les urgences.',
  'Si l’utilisatrice est mineure, adapte le contenu à son âge et encourage le dialogue avec un adulte de confiance ou un professionnel.',
  'Rappelle si utile que LaGo n’est pas une méthode de contraception.',
  'Refuse poliment les sujets sans rapport avec la santé, le corps, le cycle, la sexualité, la contraception ou le bien-être.'
].join(' ');

async function askAssistant(question, age, fetchImpl = fetch) {
  const key = env('ANTHROPIC_API_KEY');
  if (!key) return null;
  const res = await fetchImpl('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({
      model: env('ASSISTANT_MODEL', 'claude-haiku-4-5'),
      max_tokens: 400,
      system: ASSISTANT_SYSTEM + (age ? ` L’utilisatrice a ${age} ans.` : ''),
      messages: [{ role: 'user', content: question }]
    })
  });
  if (!res.ok) throw Object.assign(new Error('Assistant indisponible'), { status: 502 });
  const json = await res.json();
  const text = (json.content || []).filter(c => c.type === 'text').map(c => c.text).join('\n').trim();
  return text || null;
}

// ---------------------------------------------------------------------------
// Statistiques anonymisées (ONG)
// ---------------------------------------------------------------------------
function aggregate(db) {
  const users = db.data.users.filter(u => u.role !== 'superadmin' && u.accountType !== 'parent');
  const bands = { '10-14': 0, '15-17': 0, '18-24': 0, '25-34': 0, '35-44': 0, '45+': 0, 'inconnu': 0 };
  users.forEach(u => {
    const a = parseInt(u.age, 10);
    if (!a) bands.inconnu++;
    else if (a <= 14) bands['10-14']++;
    else if (a <= 17) bands['15-17']++;
    else if (a <= 24) bands['18-24']++;
    else if (a <= 34) bands['25-34']++;
    else if (a <= 44) bands['35-44']++;
    else bands['45+']++;
  });
  const hide = obj => Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, v >= MIN_GROUP ? v : `<${MIN_GROUP}`]));

  const cycleLens = [];
  const periodLens = [];
  const modes = {};
  const symptoms = {};
  let withLogs = 0;
  users.forEach(u => {
    const s = db.data.settings[u.id];
    if (s) {
      cycleLens.push(parseInt(s.cycleLength, 10) || 28);
      periodLens.push(parseInt(s.periodDuration, 10) || 5);
      const mode = s.lifeMode || 'cycle';
      modes[mode] = (modes[mode] || 0) + 1;
    }
    const logs = db.data.logs[u.id] || {};
    if (Object.keys(logs).length) withLogs++;
    const seen = new Set();
    Object.values(logs).forEach(l => (l.symptoms || []).forEach(x => seen.add(x)));
    seen.forEach(x => { symptoms[x] = (symptoms[x] || 0) + 1; });
  });
  const avg = arr => (arr.length >= MIN_GROUP ? Math.round((arr.reduce((a, b) => a + b, 0) / arr.length) * 10) / 10 : null);
  return {
    generatedAt: new Date().toISOString(),
    minGroup: MIN_GROUP,
    totalUsers: users.length >= MIN_GROUP ? users.length : `<${MIN_GROUP}`,
    activeJournals: withLogs >= MIN_GROUP ? withLogs : `<${MIN_GROUP}`,
    ageBands: hide(bands),
    lifeModes: hide(modes),
    averageCycleLength: avg(cycleLens),
    averagePeriodLength: avg(periodLens),
    symptomsReported: hide(symptoms) // nombre d'utilisatrices ayant noté chaque symptôme au moins une fois
  };
}

function aggregateCsv(a) {
  const rows = [['indicateur', 'valeur']];
  rows.push(['utilisatrices', a.totalUsers], ['journaux actifs', a.activeJournals],
    ['durée moyenne du cycle', a.averageCycleLength ?? 'masqué'], ['durée moyenne des règles', a.averagePeriodLength ?? 'masqué']);
  Object.entries(a.ageBands).forEach(([k, v]) => rows.push([`âge ${k}`, v]));
  Object.entries(a.lifeModes).forEach(([k, v]) => rows.push([`mode ${k}`, v]));
  Object.entries(a.symptomsReported).forEach(([k, v]) => rows.push([`symptôme ${k}`, v]));
  return rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(';')).join('\n');
}

// ---------------------------------------------------------------------------
// Partenaires
// ---------------------------------------------------------------------------
const PARTNER_TYPES = ['pharmacy', 'ngo', 'teleconsultation', 'clinic', 'other'];

function sanitizePartner(p) {
  const src = p && typeof p === 'object' ? p : {};
  const url = sanitizeText(src.url, 300);
  return {
    id: sanitizeText(src.id, 40) || 'prt_' + crypto.randomBytes(5).toString('hex'),
    type: PARTNER_TYPES.includes(src.type) ? src.type : 'other',
    name: sanitizeText(src.name, 80),
    description: sanitizeText(src.description, 400),
    city: sanitizeText(src.city, 60),
    phone: sanitizeText(src.phone, 30),
    whatsapp: sanitizeText(src.whatsapp, 30),
    url: /^https:\/\//.test(url) ? url : '',
    promoCode: sanitizeText(src.promoCode, 30)
  };
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------
/**
 * Traite les routes v5. Renvoie true si la route a été prise en charge.
 * ctx : { req, res, url, db, sendJson, parseBody, requireAuth, requireAdmin, HttpError, fetchImpl }
 */
async function handle(ctx) {
  const { req, res, url, db, sendJson, parseBody, requireAuth, requireAdmin, HttpError } = ctx;
  const fetchImpl = ctx.fetchImpl || fetch;
  const p = url.pathname;
  const m = req.method;
  ensureCollections(db);

  // ----- Fonctions disponibles (l'app adapte son interface) -----
  if (p === '/api/features' && m === 'GET') {
    const pc = premiumConfig();
    const mc = messagingConfig();
    return sendJson(req, res, 200, {
      success: true,
      premium: { enabled: pc.enabled, currency: pc.currency, plans: pc.plans },
      messaging: { enabled: mc.enabled, channels: mc.channels },
      assistant: { enabled: Boolean(env('ANTHROPIC_API_KEY')) },
      community: { enabled: true }
    }), true;
  }

  // ----- Premium -----
  if (p === '/api/premium/status' && m === 'GET') {
    const user = requireAuth(req);
    const pc = premiumConfig();
    const pr = db.data.premium[user.id];
    return sendJson(req, res, 200, {
      success: true,
      enabled: pc.enabled,
      premium: isPremium(db, user.id),
      until: pr ? pr.until : null,
      currency: pc.currency,
      plans: pc.plans
    }), true;
  }

  if (p === '/api/premium/checkout' && m === 'POST') {
    const user = requireAuth(req);
    const pc = premiumConfig();
    if (!pc.enabled) throw new HttpError(503, 'Le paiement n’est pas encore activé sur ce serveur.');
    const { plan, phone } = await parseBody(req);
    const chosen = pc.plans.find(x => x.id === plan);
    if (!chosen) throw new HttpError(400, 'Formule inconnue.');
    const id = 'LAGO' + Date.now().toString(36).toUpperCase() + crypto.randomBytes(3).toString('hex').toUpperCase();
    const base = env('PUBLIC_URL').replace(/\/+$/, '');
    const payload = {
      apikey: env('CINETPAY_APIKEY'),
      site_id: env('CINETPAY_SITE_ID'),
      transaction_id: id,
      amount: chosen.amount,
      currency: pc.currency,
      description: `LaGo Premium ${chosen.label}`,
      notify_url: `${base}/api/premium/notify`,
      return_url: `${base}/api/premium/return?tx=${id}`,
      channels: 'ALL',
      lang: 'fr',
      metadata: user.id,
      customer_id: user.id,
      customer_name: user.name || 'LaGo',
      customer_surname: user.name || 'LaGo',
      customer_email: user.email || 'contact@lago.app'
    };
    if (typeof phone === 'string' && PHONE_RE.test(phone)) payload.customer_phone_number = phone;
    db.data.payments.unshift({
      id, userId: user.id, plan: chosen.id, days: chosen.days, amount: chosen.amount, currency: pc.currency,
      status: 'PENDING', createdAt: new Date().toISOString()
    });
    db.data.payments.length = Math.min(db.data.payments.length, 5000);
    db.save();
    const r = await fetchImpl('https://api-checkout.cinetpay.com/v2/payment', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'User-Agent': 'LaGo/5.0' },
      body: JSON.stringify(payload)
    });
    const json = await r.json().catch(() => ({}));
    if (String(json.code) !== '201' || !json.data || !json.data.payment_url) {
      throw new HttpError(502, `Paiement indisponible (${json.description || json.message || 'CinetPay'}).`);
    }
    return sendJson(req, res, 200, { success: true, transactionId: id, paymentUrl: json.data.payment_url }), true;
  }

  // Notification CinetPay (formulaire x-www-form-urlencoded) — doit répondre 200
  if (p === '/api/premium/notify' && (m === 'POST' || m === 'GET')) {
    if (m === 'GET') return sendJson(req, res, 200, { success: true }), true;
    const form = new URLSearchParams(await readRawBody(req));
    const txId = form.get('cpm_trans_id');
    const payment = txId && db.data.payments.find(x => x.id === txId);
    if (!payment) return sendJson(req, res, 200, { success: true }), true;
    if (!verifyCinetpayToken(form, req.headers['x-token'])) {
      console.warn('[CinetPay] jeton x-token invalide pour', txId);
      return sendJson(req, res, 200, { success: true }), true;
    }
    if (payment.status !== 'ACCEPTED') {
      const status = await cinetpayCheck(txId, fetchImpl).catch(() => 'UNKNOWN');
      if (status === 'ACCEPTED') {
        grantPremium(db, payment);
        db.logActivity(`Premium activé (${payment.plan}) pour ${payment.userId}`);
      } else if (status === 'REFUSED') {
        payment.status = 'REFUSED';
      }
      db.save();
    }
    return sendJson(req, res, 200, { success: true }), true;
  }

  // L'app vérifie elle-même au retour (si la notification a été retardée)
  if (p === '/api/premium/verify' && m === 'POST') {
    const user = requireAuth(req);
    const { transactionId } = await parseBody(req);
    const payment = db.data.payments.find(x => x.id === transactionId && x.userId === user.id);
    if (!payment) throw new HttpError(404, 'Paiement introuvable.');
    if (payment.status !== 'ACCEPTED' && premiumConfig().enabled) {
      const status = await cinetpayCheck(payment.id, fetchImpl).catch(() => 'UNKNOWN');
      if (status === 'ACCEPTED') grantPremium(db, payment);
      else if (status === 'REFUSED') payment.status = 'REFUSED';
      db.save();
    }
    return sendJson(req, res, 200, {
      success: true, status: payment.status, premium: isPremium(db, user.id),
      until: db.data.premium[user.id] ? db.data.premium[user.id].until : null
    }), true;
  }

  if (p === '/api/premium/return' && m === 'GET') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<title>LaGo</title><body style="font-family:sans-serif;text-align:center;padding:40px;background:#fff5f7;color:#3a2e39">' +
      '<h1>🌸 Merci !</h1><p>Votre paiement est en cours de vérification.</p><p>Retournez dans l’application LaGo.</p></body>');
    return true;
  }

  // ----- Rappels SMS / WhatsApp -----
  if (p === '/api/messaging' && m === 'GET') {
    const user = requireAuth(req);
    const mc = messagingConfig();
    const sub = db.data.messaging[user.id] || null;
    return sendJson(req, res, 200, { success: true, enabled: mc.enabled, channels: mc.channels, subscription: sub }), true;
  }

  if (p === '/api/messaging' && m === 'POST') {
    const user = requireAuth(req);
    const body = await parseBody(req);
    if (body.enabled === false) {
      delete db.data.messaging[user.id];
      delete db.data.messagingLog[user.id];
      db.save();
      return sendJson(req, res, 200, { success: true, subscription: null }), true;
    }
    const mc = messagingConfig();
    if (!mc.enabled) throw new HttpError(503, 'Les rappels par SMS / WhatsApp ne sont pas encore activés sur ce serveur.');
    const phone = String(body.phone || '').replace(/[\s.-]/g, '');
    if (!PHONE_RE.test(phone)) throw new HttpError(400, 'Numéro invalide : utilisez le format international, ex. +237 6XX XX XX XX.');
    if (!mc.channels.includes(body.channel)) throw new HttpError(400, 'Canal non disponible.');
    if (body.consent !== true) throw new HttpError(400, 'Votre accord est nécessaire pour recevoir des messages.');
    db.data.messaging[user.id] = {
      phone,
      channel: body.channel,
      enabled: true,
      consent: true,
      consentAt: new Date().toISOString(),
      discreet: body.discreet !== false,
      daysBefore: Math.min(5, Math.max(1, parseInt(body.daysBefore, 10) || 2))
    };
    db.logActivity(`Rappels ${body.channel} activés par ${user.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true, subscription: db.data.messaging[user.id] }), true;
  }

  // ----- Assistant -----
  if (p === '/api/assistant' && m === 'POST') {
    const user = requireAuth(req);
    const { question } = await parseBody(req);
    const q = sanitizeText(question, 800);
    if (q.length < 3) throw new HttpError(400, 'Posez votre question en quelques mots.');
    const limiter = ctx.assistantLimiter;
    if (limiter && !limiter.check(user.id)) throw new HttpError(429, 'Vous avez posé beaucoup de questions. Réessayez dans une heure.');
    const answer = await askAssistant(q, user.age, fetchImpl);
    if (!answer) throw new HttpError(503, 'L’assistant en ligne n’est pas activé sur ce serveur.');
    return sendJson(req, res, 200, { success: true, answer }), true;
  }

  // ----- Communauté anonyme modérée -----
  if (p === '/api/community/questions' && m === 'GET') {
    requireAuth(req);
    const items = db.data.community
      .filter(q => q.status === 'approved')
      .slice(0, 200)
      .map(q => ({ id: q.id, topic: q.topic, question: q.question, answer: q.answer || '', createdAt: q.createdAt, answeredAt: q.answeredAt || null }));
    return sendJson(req, res, 200, { success: true, questions: items }), true;
  }

  if (p === '/api/community/questions' && m === 'POST') {
    const user = requireAuth(req);
    const { question, topic } = await parseBody(req);
    const q = sanitizeText(question, 600);
    if (q.length < 10) throw new HttpError(400, 'Votre question est trop courte.');
    const mine = db.data.community.filter(x => x.userId === user.id && Date.now() - Date.parse(x.createdAt) < 86400000);
    if (mine.length >= 5) throw new HttpError(429, 'Maximum 5 questions par jour.');
    db.data.community.unshift({
      id: 'q_' + crypto.randomBytes(6).toString('hex'),
      userId: user.id, // jamais renvoyé publiquement
      topic: ['cycle', 'sexualite', 'contraception', 'grossesse', 'bienetre', 'autre'].includes(topic) ? topic : 'autre',
      question: q,
      status: 'pending',
      createdAt: new Date().toISOString()
    });
    db.data.community.length = Math.min(db.data.community.length, 5000);
    db.save();
    return sendJson(req, res, 201, { success: true, message: 'Merci ! Votre question sera publiée anonymement après relecture.' }), true;
  }

  if (p === '/api/admin/community' && m === 'GET') {
    requireAdmin(req);
    return sendJson(req, res, 200, {
      success: true,
      questions: db.data.community.slice(0, 300).map(q => ({ id: q.id, topic: q.topic, question: q.question, answer: q.answer || '', status: q.status, createdAt: q.createdAt }))
    }), true;
  }

  if (p === '/api/admin/community' && m === 'POST') {
    const admin = requireAdmin(req);
    const { id, action, answer } = await parseBody(req);
    const q = db.data.community.find(x => x.id === id);
    if (!q) throw new HttpError(404, 'Question introuvable.');
    if (action === 'delete') {
      db.data.community = db.data.community.filter(x => x.id !== id);
    } else if (action === 'approve' || action === 'reject') {
      q.status = action === 'approve' ? 'approved' : 'rejected';
      const a = sanitizeText(answer, 2000);
      if (a) {
        q.answer = a;
        q.answeredAt = new Date().toISOString();
      }
      q.moderatedBy = admin.id;
    } else {
      throw new HttpError(400, 'Action inconnue.');
    }
    db.save();
    return sendJson(req, res, 200, { success: true }), true;
  }

  // ----- Partenaires -----
  if (p === '/api/partners' && m === 'GET') {
    return sendJson(req, res, 200, { success: true, partners: db.data.partners }), true;
  }

  if (p === '/api/admin/partners' && m === 'POST') {
    const admin = requireAdmin(req);
    const body = await parseBody(req);
    const partner = sanitizePartner(body);
    if (!partner.name) throw new HttpError(400, 'Le nom du partenaire est obligatoire.');
    const idx = db.data.partners.findIndex(x => x.id === partner.id);
    if (idx >= 0) db.data.partners[idx] = partner;
    else db.data.partners.push(partner);
    db.logActivity(`Partenaire « ${partner.name} » enregistré par ${admin.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true, partner }), true;
  }

  if (p === '/api/admin/partners' && m === 'DELETE') {
    requireAdmin(req);
    const id = url.searchParams.get('id');
    db.data.partners = db.data.partners.filter(x => x.id !== id);
    db.save();
    return sendJson(req, res, 200, { success: true }), true;
  }

  // ----- Statistiques anonymisées (ONG) -----
  if (p === '/api/admin/aggregate' && m === 'GET') {
    requireAdmin(req);
    const a = aggregate(db);
    if (url.searchParams.get('format') === 'csv') {
      res.writeHead(200, { 'Content-Type': 'text/csv; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end('﻿' + aggregateCsv(a));
      return true;
    }
    return sendJson(req, res, 200, { success: true, aggregate: a }), true;
  }

  return false;
}

/** Effacement des données v5 d'un compte (droit à l'effacement). */
function onUserDeleted(db, userId) {
  ensureCollections(db);
  delete db.data.premium[userId];
  delete db.data.messaging[userId];
  delete db.data.messagingLog[userId];
  db.data.community.forEach(q => { if (q.userId === userId) q.userId = null; }); // la question publiée reste anonyme
  db.data.payments.forEach(x => { if (x.userId === userId) x.userId = null; }); // trace comptable conservée, anonymisée
}

module.exports = {
  handle,
  onUserDeleted,
  startScheduler,
  runDailyReminders,
  verifyCinetpayToken,
  grantPremium,
  aggregate,
  nextPeriod,
  premiumConfig,
  messagingConfig,
  reminderText,
  isPremium,
  sanitizePartner
};
