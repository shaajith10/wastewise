const { admin, getDb } = require('../config/firebase');
const { verifySessionToken } = require('../services/authService');

/**
 * Verifies the Bearer token from the Authorization header.
 * Accepts app session tokens (issued by /api/auth/login and /register) and,
 * when Firebase is configured, Firebase ID tokens.
 * Attaches req.user = { uid, email, role, displayName, fcmToken }
 */
async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const token = authHeader.slice('Bearer '.length).trim();

  let uid;
  let email = null;
  let displayName = '';
  let isSession = false;

  try {
    ({ uid } = verifySessionToken(token));
    isSession = true;
  } catch (_) {
    try {
      let decoded;
      if (process.env.NODE_ENV === 'test' && global.__mockAuthVerify) {
        decoded = global.__mockAuthVerify(token);
      } else if (admin.apps.length > 0) {
        decoded = await admin.auth().verifyIdToken(token);
      } else {
        throw new Error('Not a valid session token');
      }
      uid = decoded.uid;
      email = decoded.email || null;
      displayName = decoded.name || '';
    } catch (err) {
      console.error('[Auth] Token verification failed:', err.message);
      return res.status(401).json({ error: 'Invalid or expired session. Please log in again.' });
    }
  }

  try {
    const userDoc = await getDb().collection('users').doc(uid).get();
    if (isSession && !userDoc.exists) {
      return res.status(401).json({ error: 'Account no longer exists. Please log in again.' });
    }

    const data = userDoc.exists ? userDoc.data() : {};
    if (data.active === false) {
      return res.status(403).json({ error: 'This account has been deactivated.' });
    }

    req.user = {
      uid,
      email: data.email || email,
      role: data.role || 'citizen',
      displayName: data.displayName || displayName,
      fcmToken: data.fcmToken || null,
    };
    next();
  } catch (err) {
    console.error('[Auth] User lookup failed:', err.message);
    return res.status(500).json({ error: 'Authentication failed' });
  }
}

module.exports = { authenticate };
