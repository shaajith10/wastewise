const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/firebase');

const SESSION_SECRET = process.env.JWT_SECRET || 'dev_secret_replace_in_production';
const SESSION_EXPIRY = '30d';

/**
 * Built-in accounts so collectors and admins can log in without self-registration
 * (self-registration always creates citizens). Fixed uids keep existing demo data attached.
 */
const DEFAULT_ACCOUNTS = [
  { uid: 'seed-admin-uid', email: 'admin@waste.dev', password: 'admin123', role: 'admin', displayName: 'Admin Manager' },
  { uid: 'seed-collector-uid', email: 'collector@waste.dev', password: 'collector123', role: 'collector', displayName: 'Authorized Collector' },
  { uid: 'seed-citizen-uid', email: 'citizen@waste.dev', password: 'citizen123', role: 'citizen', displayName: 'Demo Citizen' },
];

/** scrypt hash stored as "salt:hash" (hex). */
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  if (typeof stored !== 'string' || !stored.includes(':')) return false;
  const [salt, hash] = stored.split(':');
  const expected = Buffer.from(hash, 'hex');
  if (expected.length === 0) return false;
  const candidate = crypto.scryptSync(String(password), salt, expected.length);
  return crypto.timingSafeEqual(candidate, expected);
}

function createSessionToken(uid) {
  return jwt.sign({ uid, typ: 'session' }, SESSION_SECRET, { expiresIn: SESSION_EXPIRY });
}

/** Throws unless the token is a valid, unexpired session token (QR tokens are rejected). */
function verifySessionToken(token) {
  const payload = jwt.verify(token, SESSION_SECRET);
  if (payload.typ !== 'session' || !payload.uid) throw new Error('Not a session token');
  return payload;
}

/** User document safe to send to clients. */
function publicUser(data) {
  if (!data) return data;
  const { passwordHash, ...rest } = data;
  return rest;
}

/**
 * Creates a new user account with a password (used by self-registration and by
 * admin-created accounts). Throws { status, message } on a validation failure
 * (duplicate email) so routes can turn it into the right HTTP response.
 */
async function createUserAccount({ displayName, email, phone, password, role = 'citizen', extra = {} }) {
  const db = getDb();
  const cleanEmail = String(email).trim().toLowerCase();

  const existing = await db.collection('users').where('email', '==', cleanEmail).limit(1).get();
  if (!existing.empty) {
    const err = new Error('An account with this email already exists.');
    err.status = 409;
    throw err;
  }

  const uid = `user_${uuidv4()}`;
  const now = new Date().toISOString();
  const userData = {
    uid,
    displayName: String(displayName).trim(),
    email: cleanEmail,
    phone: String(phone || '').trim(),
    role,
    rewardBalance: 0,
    active: true,
    fcmToken: null,
    passwordHash: hashPassword(password),
    createdAt: now,
    updatedAt: now,
    ...extra,
  };

  await db.collection('users').doc(uid).set(userData);
  return userData;
}

/** Creates the default accounts, or gives them a password if they predate password login. */
async function ensureDefaultAccounts() {
  const db = getDb();
  for (const acct of DEFAULT_ACCOUNTS) {
    const ref = db.collection('users').doc(acct.uid);
    const snap = await ref.get();
    const now = new Date().toISOString();

    if (!snap.exists) {
      await ref.set({
        uid: acct.uid,
        email: acct.email,
        displayName: acct.displayName,
        phone: '',
        role: acct.role,
        rewardBalance: 0,
        active: true,
        fcmToken: null,
        passwordHash: hashPassword(acct.password),
        createdAt: now,
        updatedAt: now,
      });
    } else if (!snap.data().passwordHash) {
      await ref.update({
        email: acct.email,
        role: acct.role,
        passwordHash: hashPassword(acct.password),
        updatedAt: now,
      });
    }
  }
}

module.exports = {
  DEFAULT_ACCOUNTS,
  hashPassword,
  verifyPassword,
  createSessionToken,
  verifySessionToken,
  publicUser,
  createUserAccount,
  ensureDefaultAccounts,
};
