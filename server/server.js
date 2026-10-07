/**
 * LaGo 🌸 - Serveur HTTP & API REST sécurisée (zéro dépendance externe)
 *
 * Variables d'environnement :
 *   PORT              Port d'écoute (défaut 8080)
 *   LAGO_SECRET       Secret de signature des jetons (≥ 32 caractères, recommandé en production)
 *   DEMO_MODE         "false" pour désactiver les comptes de démonstration (défaut : activé)
 *   ADMIN_EMAIL       Crée/assure un Super Admin au démarrage (avec ADMIN_PASSWORD ≥ 8 caractères)
 *   ADMIN_PASSWORD
 *   ALLOWED_ORIGINS   Origines CORS autorisées, séparées par des virgules (l'app mobile est déjà incluse)
 *   STATIC_DIR        Dossier des fichiers web servis (défaut : dist/web, sinon src/)
 *   DATA_DIR          Dossier de la base de données (défaut : data/)
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const { Database } = require('./db');
const security = require('./security');

const ROOT = __dirname; // dossier server/ autonome (API seule pour l'app Flutter)
const PORT = parseInt(process.env.PORT, 10) || 8080;
const DATA_DIR = process.env.DATA_DIR ? path.resolve(process.env.DATA_DIR) : path.join(ROOT, 'data');
const DEMO_MODE = process.env.DEMO_MODE !== 'false';
const MAX_BODY_BYTES = 2 * 1024 * 1024; // 2 Mo (import de sauvegarde et photo de profil chiffrée inclus)
const MAX_AVATAR_CHARS = 1500000; // photo chiffrée encodée en base64
const INVITE_TTL_MS = 48 * 60 * 60 * 1000; // code d'invitation parent valable 48 h
const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function resolveStaticDir() {
  if (process.env.STATIC_DIR) return path.resolve(process.env.STATIC_DIR);
  const dist = path.join(ROOT, 'dist', 'web');
  return fs.existsSync(path.join(dist, 'index.html')) ? dist : path.join(ROOT, 'src');
}
const STATIC_DIR = resolveStaticDir();

const DEFAULT_ORIGINS = [
  'capacitor://localhost', // iOS
  'https://localhost',     // Android (androidScheme https)
  'http://localhost',
  'ionic://localhost'
];
const ALLOWED_ORIGINS = new Set(
  DEFAULT_ORIGINS.concat((process.env.ALLOWED_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean))
);

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------
const db = new Database({
  dataDir: DATA_DIR,
  seedFile: path.join(ROOT, 'data', 'seed.json'),
  demoMode: DEMO_MODE
}).load();
const SECRET = security.loadSecret(DATA_DIR);
const loginLimiter = security.createRateLimiter({ windowMs: 15 * 60 * 1000, max: 10 });
const registerLimiter = security.createRateLimiter({ windowMs: 60 * 60 * 1000, max: 20 });
setInterval(() => { loginLimiter.cleanup(); registerLimiter.cleanup(); }, 10 * 60 * 1000).unref();

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const FLOWS = ['none', 'spotting', 'light', 'medium', 'heavy'];
const MOODS = ['calm', 'happy', 'energetic', 'romantic', 'sensitive', 'tired', 'stressed', 'irritated'];
const SYMPTOMS = ['cramps', 'breasts', 'headache', 'bloating', 'fatigue', 'acne', 'cravings', 'backpain', 'libido', 'cervical'];
const SYMPTOM_LABELS = {
  cramps: 'Crampes', breasts: 'Seins sensibles', headache: 'Maux de tête', bloating: 'Ballonnements',
  fatigue: 'Fatigue intense', acne: 'Acné', cravings: 'Fringales', backpain: 'Mal de dos',
  libido: 'Libido accrue', cervical: 'Glaire cervicale'
};

function isValidDate(s) {
  if (typeof s !== 'string' || !DATE_RE.test(s)) return false;
  const [y, m, d] = s.split('-').map(Number);
  const dt = new Date(y, m - 1, d);
  return dt.getFullYear() === y && dt.getMonth() === m - 1 && dt.getDate() === d;
}

function clampInt(value, min, max, fallback) {
  const n = parseInt(value, 10);
  if (Number.isNaN(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function sanitizeSettings(input, previous = {}) {
  const out = { ...previous };
  if (!input || typeof input !== 'object') return out;
  if (isValidDate(input.lastPeriodDate)) out.lastPeriodDate = input.lastPeriodDate;
  if (input.cycleLength !== undefined) out.cycleLength = clampInt(input.cycleLength, 15, 60, 28);
  if (input.periodDuration !== undefined) out.periodDuration = clampInt(input.periodDuration, 1, 15, 5);
  ['petalsEnabled', 'darkMode', 'discreetMode', 'remindersEnabled', 'learnFromJournal'].forEach(k => {
    if (typeof input[k] === 'boolean') out[k] = input[k];
  });
  if (['regular', 'irregular', 'unknown'].includes(input.cycleRegularity)) out.cycleRegularity = input.cycleRegularity;
  // Le code PIN reste exclusivement sur l'appareil : jamais stocké côté serveur.
  delete out.pinCode;
  delete out.pinHash;
  out.updatedAt = new Date().toISOString();
  return out;
}

function sanitizeLog(input) {
  const src = input && typeof input === 'object' ? input : {};
  let temperature = '';
  if (src.temperature !== undefined && src.temperature !== null && src.temperature !== '') {
    const t = parseFloat(src.temperature);
    if (!Number.isNaN(t) && t >= 34 && t <= 43) temperature = t.toFixed(2).replace(/0$/, '');
  }
  return {
    flow: FLOWS.includes(src.flow) ? src.flow : 'none',
    mood: MOODS.includes(src.mood) ? src.mood : 'calm',
    temperature,
    symptoms: Array.isArray(src.symptoms) ? [...new Set(src.symptoms.filter(s => SYMPTOMS.includes(s)))] : [],
    notes: typeof src.notes === 'string' ? src.notes.slice(0, 2000) : '',
    updatedAt: typeof src.updatedAt === 'string' && !Number.isNaN(Date.parse(src.updatedAt))
      ? src.updatedAt
      : new Date().toISOString()
  };
}

function publicUser(u) {
  return {
    id: u.id,
    name: u.name,
    email: u.email,
    role: u.role,
    accountType: u.accountType === 'parent' ? 'parent' : 'member',
    age: u.age,
    status: u.status,
    createdAt: u.createdAt
  };
}

// ---------------------------------------------------------------------------
// Utilitaires HTTP
// ---------------------------------------------------------------------------
function corsHeaders(req) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    return {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '600',
      Vary: 'Origin'
    };
  }
  return {};
}

const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'X-Frame-Options': 'DENY',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()'
};

const CSP = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data:",
  "font-src 'self'",
  "connect-src 'self'",
  "manifest-src 'self'",
  "worker-src 'self'",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'"
].join('; ');

function sendJson(req, res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...SECURITY_HEADERS,
    ...corsHeaders(req)
  });
  res.end(JSON.stringify(data));
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', chunk => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(Object.assign(new Error('Requête trop volumineuse'), { status: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf-8');
      if (!raw) return resolve({});
      try {
        const parsed = JSON.parse(raw);
        resolve(parsed && typeof parsed === 'object' ? parsed : {});
      } catch (e) {
        reject(Object.assign(new Error('JSON invalide'), { status: 400 }));
      }
    });
    req.on('error', reject);
  });
}

function clientIp(req) {
  return (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || req.socket.remoteAddress || 'unknown';
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/** Retourne l'utilisatrice authentifiée (ou lève 401). Le rôle est toujours relu en base. */
function requireAuth(req) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  const payload = security.verifyToken(SECRET, token);
  if (!payload) throw new HttpError(401, 'Session expirée, veuillez vous reconnecter.');
  const user = db.data.users.find(u => u.id === payload.sub);
  if (!user) throw new HttpError(401, 'Compte introuvable.');
  if (user.status === 'blocked') throw new HttpError(403, 'Ce compte a été suspendu.');
  return user;
}

function requireAdmin(req) {
  const user = requireAuth(req);
  if (user.role !== 'superadmin') throw new HttpError(403, 'Accès réservé au Super Admin.');
  return user;
}

function countSuperAdmins() {
  return db.data.users.filter(u => u.role === 'superadmin' && u.status !== 'blocked').length;
}

function validateNewAccount({ name, email, password, age, accountType }) {
  const cleanName = String(name || '').trim().slice(0, 60);
  const cleanEmail = String(email || '').toLowerCase().trim();
  if (!cleanName) throw new HttpError(400, 'Le prénom est obligatoire.');
  if (!EMAIL_RE.test(cleanEmail)) throw new HttpError(400, 'Adresse email invalide.');
  if (typeof password !== 'string' || password.length < 6) {
    throw new HttpError(400, 'Le mot de passe doit contenir au moins 6 caractères.');
  }
  if (db.data.users.some(u => u.email === cleanEmail)) {
    throw new HttpError(409, 'Un compte existe déjà avec cet email.');
  }
  return {
    id: 'usr_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
    name: cleanName,
    email: cleanEmail,
    passwordHash: security.hashPassword(password),
    role: 'user',
    accountType: accountType === 'parent' ? 'parent' : 'member',
    age: clampInt(age, 10, 99, null),
    createdAt: new Date().toISOString(),
    status: 'active'
  };
}

function deleteUserData(userId) {
  delete db.data.settings[userId];
  delete db.data.logs[userId];
}

/** Supprime tout ce qui relie un compte à d'autres (suivi parental, invitations, photo chiffrée). */
function deleteUserLinks(userId) {
  db.data.familyLinks = (db.data.familyLinks || []).filter(l => l.parentId !== userId && l.childId !== userId);
  db.data.familyInvites = (db.data.familyInvites || []).filter(i => i.childId !== userId);
  if (db.data.avatars) delete db.data.avatars[userId];
}

/** Données partagées avec un parent : cycle et journal SANS les notes personnelles. */
function sharedChildData(child, link) {
  const s = db.data.settings[child.id] || null;
  const logs = {};
  Object.entries(db.data.logs[child.id] || {}).forEach(([date, e]) => {
    logs[date] = { flow: e.flow, mood: e.mood, temperature: e.temperature, symptoms: e.symptoms, updatedAt: e.updatedAt };
  });
  return {
    id: child.id,
    name: child.name,
    age: child.age,
    linkedAt: link.createdAt,
    settings: s && {
      lastPeriodDate: s.lastPeriodDate,
      cycleLength: s.cycleLength,
      periodDuration: s.periodDuration,
      cycleRegularity: s.cycleRegularity,
      learnFromJournal: s.learnFromJournal
    },
    logs
  };
}

function newInviteCode() {
  const bytes = require('crypto').randomBytes(6);
  let code = '';
  for (let i = 0; i < 6; i++) code += INVITE_ALPHABET[bytes[i] % INVITE_ALPHABET.length];
  return code;
}

// ---------------------------------------------------------------------------
// Routes API
// ---------------------------------------------------------------------------
async function handleApi(req, res, url) {
  const p = url.pathname;
  const m = req.method;

  // --- Santé ---
  if (p === '/api/health' && m === 'GET') {
    return sendJson(req, res, 200, { success: true, status: 'ok', demoMode: DEMO_MODE, time: new Date().toISOString() });
  }

  // --- Auth : connexion ---
  if (p === '/api/auth/login' && m === 'POST') {
    const { email, password } = await parseBody(req);
    const cleanEmail = String(email || '').toLowerCase().trim();
    const key = `${clientIp(req)}|${cleanEmail}`;
    if (!loginLimiter.check(key)) {
      throw new HttpError(429, 'Trop de tentatives. Réessayez dans quelques minutes.');
    }
    const user = db.data.users.find(u => u.email === cleanEmail);
    if (!user || !security.verifyPassword(password || '', user.passwordHash)) {
      throw new HttpError(401, 'Email ou mot de passe incorrect.');
    }
    if (user.status === 'blocked') throw new HttpError(403, 'Ce compte a été suspendu par le Super Admin.');
    loginLimiter.reset(key);
    user.lastLoginAt = new Date().toISOString();
    db.logActivity(`Connexion de ${user.name} (${user.role})`);
    db.save();
    return sendJson(req, res, 200, {
      success: true,
      user: publicUser(user),
      token: security.createToken(SECRET, user.id)
    });
  }

  // --- Auth : inscription ---
  if (p === '/api/auth/register' && m === 'POST') {
    if (!registerLimiter.check(clientIp(req))) {
      throw new HttpError(429, 'Trop d’inscriptions depuis cette adresse. Réessayez plus tard.');
    }
    const body = await parseBody(req);
    const newUser = validateNewAccount(body);
    db.data.users.push(newUser);
    // Informations de cycle saisies pendant l'inscription
    if (body.settings && typeof body.settings === 'object') {
      db.data.settings[newUser.id] = sanitizeSettings(body.settings);
    }
    db.logActivity(`Inscription de ${newUser.name}`);
    db.save();
    return sendJson(req, res, 201, {
      success: true,
      user: publicUser(newUser),
      token: security.createToken(SECRET, newUser.id)
    });
  }

  // --- Auth : profil courant ---
  if (p === '/api/auth/me' && m === 'GET') {
    const user = requireAuth(req);
    return sendJson(req, res, 200, { success: true, user: publicUser(user) });
  }

  // --- Auth : changement de mot de passe ---
  if (p === '/api/auth/password' && m === 'POST') {
    const user = requireAuth(req);
    const { currentPassword, newPassword } = await parseBody(req);
    if (!security.verifyPassword(currentPassword || '', user.passwordHash)) {
      throw new HttpError(400, 'Mot de passe actuel incorrect.');
    }
    if (typeof newPassword !== 'string' || newPassword.length < 6) {
      throw new HttpError(400, 'Le nouveau mot de passe doit contenir au moins 6 caractères.');
    }
    user.passwordHash = security.hashPassword(newPassword);
    db.logActivity(`Mot de passe modifié par ${user.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true });
  }

  // --- Auth : suppression de son propre compte (droit à l'effacement) ---
  if (p === '/api/auth/account' && m === 'DELETE') {
    const user = requireAuth(req);
    if (user.role === 'superadmin' && countSuperAdmins() <= 1) {
      throw new HttpError(400, 'Impossible de supprimer le dernier Super Admin.');
    }
    db.data.users = db.data.users.filter(u => u.id !== user.id);
    deleteUserData(user.id);
    deleteUserLinks(user.id);
    db.logActivity(`Compte supprimé par son utilisatrice (${user.name})`);
    db.save();
    return sendJson(req, res, 200, { success: true });
  }

  // --- Cycle : paramètres ---
  if (p === '/api/cycle/settings') {
    const user = requireAuth(req);
    if (m === 'GET') {
      return sendJson(req, res, 200, { success: true, settings: db.data.settings[user.id] || null });
    }
    if (m === 'POST') {
      const { settings } = await parseBody(req);
      db.data.settings[user.id] = sanitizeSettings(settings, db.data.settings[user.id]);
      db.save();
      return sendJson(req, res, 200, { success: true, settings: db.data.settings[user.id] });
    }
  }

  // --- Cycle : journal quotidien ---
  if (p === '/api/cycle/logs') {
    const user = requireAuth(req);
    if (m === 'GET') {
      return sendJson(req, res, 200, { success: true, logs: db.data.logs[user.id] || {} });
    }
    if (m === 'POST') {
      const { date, data } = await parseBody(req);
      if (!isValidDate(date)) throw new HttpError(400, 'Date invalide (format AAAA-MM-JJ).');
      if (!db.data.logs[user.id]) db.data.logs[user.id] = {};
      db.data.logs[user.id][date] = sanitizeLog({ ...data, updatedAt: new Date().toISOString() });
      db.save();
      return sendJson(req, res, 200, { success: true, log: db.data.logs[user.id][date] });
    }
    if (m === 'DELETE') {
      const body = await parseBody(req);
      const date = body.date || url.searchParams.get('date');
      if (!isValidDate(date)) throw new HttpError(400, 'Date invalide.');
      if (db.data.logs[user.id]) delete db.data.logs[user.id][date];
      db.save();
      return sendJson(req, res, 200, { success: true });
    }
  }

  // --- Cycle : import / synchronisation groupée ---
  if (p === '/api/cycle/import' && m === 'POST') {
    const user = requireAuth(req);
    const { settings, logs, mode } = await parseBody(req);
    if (settings) db.data.settings[user.id] = sanitizeSettings(settings, db.data.settings[user.id]);
    if (logs && typeof logs === 'object') {
      const target = mode === 'replace' ? {} : { ...(db.data.logs[user.id] || {}) };
      Object.entries(logs).slice(0, 5000).forEach(([date, entry]) => {
        if (!isValidDate(date)) return;
        if (entry === null) { delete target[date]; return; }
        const clean = sanitizeLog(entry);
        const existing = target[date];
        // Dernière modification gagnante
        if (!existing || mode === 'replace' || Date.parse(clean.updatedAt) >= Date.parse(existing.updatedAt || 0)) {
          target[date] = clean;
        }
      });
      db.data.logs[user.id] = target;
    }
    db.save();
    return sendJson(req, res, 200, {
      success: true,
      settings: db.data.settings[user.id] || null,
      logs: db.data.logs[user.id] || {}
    });
  }

  // --- Cycle : réinitialisation des données personnelles ---
  if (p === '/api/cycle/data' && m === 'DELETE') {
    const user = requireAuth(req);
    deleteUserData(user.id);
    db.logActivity(`Données de cycle réinitialisées par ${user.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true });
  }

  // =========================================================================
  // Suivi parental (le parent voit le cycle et le journal de son enfant, sans les notes)
  // =========================================================================
  if (p === '/api/family/invite' && m === 'POST') {
    const user = requireAuth(req);
    if (user.accountType === 'parent') throw new HttpError(400, 'Un compte parent ne peut pas être suivi.');
    db.data.familyInvites = (db.data.familyInvites || []).filter(i => i.childId !== user.id && Date.parse(i.expiresAt) > Date.now());
    let code;
    do { code = newInviteCode(); } while (db.data.familyInvites.some(i => i.code === code));
    const invite = { code, childId: user.id, expiresAt: new Date(Date.now() + INVITE_TTL_MS).toISOString() };
    db.data.familyInvites.push(invite);
    db.save();
    return sendJson(req, res, 200, { success: true, code, expiresAt: invite.expiresAt });
  }

  if (p === '/api/family/link' && m === 'POST') {
    const user = requireAuth(req);
    if (user.accountType !== 'parent') throw new HttpError(403, 'Réservé aux comptes parent.');
    if (!loginLimiter.check(`family|${clientIp(req)}|${user.id}`)) {
      throw new HttpError(429, 'Trop de tentatives. Réessayez dans quelques minutes.');
    }
    const code = String((await parseBody(req)).code || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
    const invites = db.data.familyInvites || [];
    const invite = invites.find(i => i.code === code && Date.parse(i.expiresAt) > Date.now());
    if (!invite) throw new HttpError(404, 'Code invalide ou expiré.');
    const child = db.data.users.find(u => u.id === invite.childId);
    if (!child || child.id === user.id) throw new HttpError(404, 'Code invalide ou expiré.');
    db.data.familyLinks = db.data.familyLinks || [];
    if (!db.data.familyLinks.some(l => l.parentId === user.id && l.childId === child.id)) {
      db.data.familyLinks.push({ parentId: user.id, childId: child.id, createdAt: new Date().toISOString() });
    }
    db.data.familyInvites = invites.filter(i => i !== invite);
    db.logActivity(`Suivi parental : ${user.name} suit ${child.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true, child: { id: child.id, name: child.name } });
  }

  if (p === '/api/family/children' && m === 'GET') {
    const user = requireAuth(req);
    const children = (db.data.familyLinks || [])
      .filter(l => l.parentId === user.id)
      .map(l => {
        const child = db.data.users.find(u => u.id === l.childId && u.status !== 'blocked');
        return child ? sharedChildData(child, l) : null;
      })
      .filter(Boolean);
    return sendJson(req, res, 200, { success: true, children });
  }

  if (p === '/api/family/followers' && m === 'GET') {
    const user = requireAuth(req);
    const followers = (db.data.familyLinks || [])
      .filter(l => l.childId === user.id)
      .map(l => {
        const parent = db.data.users.find(u => u.id === l.parentId);
        return parent ? { id: parent.id, name: parent.name, email: parent.email, linkedAt: l.createdAt } : null;
      })
      .filter(Boolean);
    return sendJson(req, res, 200, { success: true, followers });
  }

  if (p === '/api/family/link' && m === 'DELETE') {
    const user = requireAuth(req);
    const other = url.searchParams.get('userId') || '';
    const before = (db.data.familyLinks || []).length;
    db.data.familyLinks = (db.data.familyLinks || []).filter(l =>
      !((l.parentId === user.id && l.childId === other) || (l.childId === user.id && l.parentId === other)));
    if (db.data.familyLinks.length !== before) db.logActivity(`Suivi parental retiré par ${user.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true });
  }

  // =========================================================================
  // Photo de profil chiffrée sur l'appareil (le serveur ne peut pas la lire)
  // =========================================================================
  if (p === '/api/profile/avatar') {
    const user = requireAuth(req);
    db.data.avatars = db.data.avatars || {};
    if (m === 'GET') {
      const a = db.data.avatars[user.id];
      if (!a) throw new HttpError(404, 'Aucune sauvegarde.');
      return sendJson(req, res, 200, { success: true, data: a.data, updatedAt: a.updatedAt });
    }
    if (m === 'POST') {
      const { data } = await parseBody(req);
      if (typeof data !== 'string' || !data || data.length > MAX_AVATAR_CHARS || !/^[A-Za-z0-9+/=]+$/.test(data)) {
        throw new HttpError(400, 'Photo invalide ou trop volumineuse.');
      }
      db.data.avatars[user.id] = { data, updatedAt: new Date().toISOString() };
      db.save();
      return sendJson(req, res, 200, { success: true });
    }
    if (m === 'DELETE') {
      delete db.data.avatars[user.id];
      db.save();
      return sendJson(req, res, 200, { success: true });
    }
  }

  // =========================================================================
  // Super Admin
  // =========================================================================
  if (p === '/api/admin/stats' && m === 'GET') {
    requireAdmin(req);
    let totalLogs = 0;
    const symptomCounts = {};
    Object.values(db.data.logs).forEach(userLogs => {
      Object.values(userLogs).forEach(entry => {
        totalLogs++;
        (entry.symptoms || []).forEach(s => { symptomCounts[s] = (symptomCounts[s] || 0) + 1; });
      });
    });
    const top = Object.entries(symptomCounts).sort((a, b) => b[1] - a[1])[0];
    return sendJson(req, res, 200, {
      success: true,
      stats: {
        totalUsers: db.data.users.length,
        superAdmins: db.data.users.filter(u => u.role === 'superadmin').length,
        blockedUsers: db.data.users.filter(u => u.status === 'blocked').length,
        totalLogs,
        topSymptom: top ? { key: top[0], label: SYMPTOM_LABELS[top[0]] || top[0], count: top[1] } : null,
        activityLogs: db.data.activityLogs.slice(0, 100)
      }
    });
  }

  if (p === '/api/admin/users' && m === 'GET') {
    requireAdmin(req);
    return sendJson(req, res, 200, {
      success: true,
      users: db.data.users.map(u => ({ ...publicUser(u), logsCount: Object.keys(db.data.logs[u.id] || {}).length }))
    });
  }

  if (p === '/api/admin/user' && m === 'POST') {
    const admin = requireAdmin(req);
    const body = await parseBody(req);
    const newUser = validateNewAccount(body);
    db.data.users.push(newUser);
    db.logActivity(`Création manuelle de ${newUser.name} par ${admin.name}`);
    db.save();
    return sendJson(req, res, 201, { success: true, user: publicUser(newUser) });
  }

  if (p === '/api/admin/user/role' && m === 'POST') {
    const admin = requireAdmin(req);
    const { userId, role } = await parseBody(req);
    if (!['user', 'superadmin'].includes(role)) throw new HttpError(400, 'Rôle invalide.');
    const target = db.data.users.find(u => u.id === userId);
    if (!target) throw new HttpError(404, 'Utilisatrice introuvable.');
    if (target.id === admin.id) throw new HttpError(400, 'Vous ne pouvez pas modifier votre propre rôle.');
    if (target.role === 'superadmin' && role === 'user' && countSuperAdmins() <= 1) {
      throw new HttpError(400, 'Impossible de rétrograder le dernier Super Admin.');
    }
    target.role = role;
    db.logActivity(`Rôle de ${target.name} modifié en ${role} par ${admin.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true, user: publicUser(target) });
  }

  if (p === '/api/admin/user/status' && m === 'POST') {
    const admin = requireAdmin(req);
    const { userId, status } = await parseBody(req);
    if (!['active', 'blocked'].includes(status)) throw new HttpError(400, 'Statut invalide.');
    const target = db.data.users.find(u => u.id === userId);
    if (!target) throw new HttpError(404, 'Utilisatrice introuvable.');
    if (target.id === admin.id) throw new HttpError(400, 'Vous ne pouvez pas suspendre votre propre compte.');
    target.status = status;
    db.logActivity(`Compte de ${target.name} ${status === 'blocked' ? 'suspendu' : 'réactivé'} par ${admin.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true, user: publicUser(target) });
  }

  if (p === '/api/admin/user' && m === 'DELETE') {
    const admin = requireAdmin(req);
    const userId = url.searchParams.get('userId');
    const target = db.data.users.find(u => u.id === userId);
    if (!target) throw new HttpError(404, 'Utilisatrice introuvable.');
    if (target.id === admin.id) throw new HttpError(400, 'Vous ne pouvez pas supprimer votre propre compte ici.');
    if (target.role === 'superadmin' && countSuperAdmins() <= 1) {
      throw new HttpError(400, 'Impossible de supprimer le dernier Super Admin.');
    }
    db.data.users = db.data.users.filter(u => u.id !== userId);
    deleteUserData(userId);
    deleteUserLinks(userId);
    db.logActivity(`Suppression de l'utilisatrice ${target.name} par ${admin.name}`);
    db.save();
    return sendJson(req, res, 200, { success: true });
  }

  throw new HttpError(404, 'Route API introuvable');
}

// ---------------------------------------------------------------------------
// Fichiers statiques (uniquement le dossier web public)
// ---------------------------------------------------------------------------
const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.txt': 'text/plain; charset=utf-8'
};

function serveStatic(req, res, url) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, SECURITY_HEADERS);
    return res.end();
  }

  // Configuration d'exécution générée dynamiquement (mode démo, URL API)
  if (url.pathname === '/config.js') {
    res.writeHead(200, {
      'Content-Type': 'application/javascript; charset=utf-8',
      'Cache-Control': 'no-cache',
      ...SECURITY_HEADERS
    });
    return res.end(`window.LAGO_CONFIG = Object.assign(window.LAGO_CONFIG || {}, ${JSON.stringify({
      platform: 'web', apiBaseUrl: '', demoMode: DEMO_MODE
    })});\n`);
  }

  let rel;
  try {
    rel = decodeURIComponent(url.pathname);
  } catch (e) {
    res.writeHead(400, SECURITY_HEADERS);
    return res.end('400');
  }
  if (rel === '/' || rel === '') rel = '/index.html';
  const filePath = path.normalize(path.join(STATIC_DIR, rel));
  if (!filePath.startsWith(STATIC_DIR + path.sep)) {
    res.writeHead(403, SECURITY_HEADERS);
    return res.end('403');
  }
  // Fichiers cachés interdits
  if (rel.split('/').some(seg => seg.startsWith('.'))) {
    res.writeHead(404, SECURITY_HEADERS);
    return res.end('404');
  }

  fs.stat(filePath, (err, stats) => {
    let target = filePath;
    if (err || !stats.isFile()) {
      // Repli SPA uniquement pour les routes sans extension
      if (path.extname(rel)) {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8', ...SECURITY_HEADERS });
        return res.end('404 - Fichier introuvable');
      }
      target = path.join(STATIC_DIR, 'index.html');
    }
    const ext = path.extname(target).toLowerCase();
    const noCache = ext === '.html' || target.endsWith('sw.js') || ext === '.webmanifest' || target.endsWith('manifest.json');
    fs.readFile(target, (readErr, content) => {
      if (readErr) {
        res.writeHead(500, SECURITY_HEADERS);
        return res.end('500');
      }
      const headers = {
        'Content-Type': MIME_TYPES[ext] || 'application/octet-stream',
        'Cache-Control': noCache ? 'no-cache' : 'public, max-age=86400',
        ...SECURITY_HEADERS
      };
      if (ext === '.html') headers['Content-Security-Policy'] = CSP;
      res.writeHead(200, headers);
      res.end(req.method === 'HEAD' ? undefined : content);
    });
  });
}

// ---------------------------------------------------------------------------
// Serveur
// ---------------------------------------------------------------------------
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');

  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders(req));
    return res.end();
  }

  if (url.pathname.startsWith('/api/')) {
    try {
      await handleApi(req, res, url);
    } catch (err) {
      const status = err.status || 500;
      if (status === 500) console.error('[API]', err);
      sendJson(req, res, status, { success: false, message: status === 500 ? 'Erreur interne du serveur.' : err.message });
    }
    return;
  }

  serveStatic(req, res, url);
});

function shutdown() {
  try { db.flush(); } catch (e) { /* ignore */ }
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`🌸 Serveur LaGo en ligne : http://localhost:${PORT}`);
    console.log(`📂 Fichiers web : ${STATIC_DIR}`);
    console.log(`🗄️  Base de données : ${db.file}`);
    console.log(`🧪 Mode démo : ${DEMO_MODE ? 'activé (DEMO_MODE=false pour le désactiver)' : 'désactivé'}`);
    if (!process.env.LAGO_SECRET) console.log('⚠️  LAGO_SECRET non défini : un secret local a été généré dans data/.secret');
  });
}

module.exports = { server, db };
