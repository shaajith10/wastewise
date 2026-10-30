const { body, validationResult } = require('express-validator');
const express = require('express');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { verifyPassword, createSessionToken, publicUser, createUserAccount } = require('../services/authService');

const router = express.Router();

/**
 * POST /api/auth/register
 * Citizen self-registration. Creates a new, empty citizen account and logs it in.
 * Body: { displayName, email, phone, password }
 * Returns: { token, user }
 */
router.post(
  '/register',
  [
    body('displayName').trim().notEmpty().withMessage('Display name is required'),
    body('email').trim().isEmail().withMessage('Valid email is required').toLowerCase(),
    body('phone')
      .trim()
      .notEmpty().withMessage('Phone number is required')
      .custom((v) => /^\d{10,13}$/.test(v.replace(/\D/g, ''))).withMessage('Enter a valid 10-digit phone number'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg, errors: errors.array() });

    const { displayName, email, phone, password } = req.body;

    try {
      // Self-registration is always citizen — role can't be set by the client.
      const userData = await createUserAccount({ displayName, email, phone, password, role: 'citizen' });
      res.status(201).json({
        message: 'Account created',
        token: createSessionToken(userData.uid),
        user: publicUser(userData),
      });
    } catch (err) {
      if (err.status) return res.status(err.status).json({ error: err.message });
      console.error('[Auth] Register error:', err.message);
      res.status(500).json({ error: 'Registration failed' });
    }
  }
);

/**
 * POST /api/auth/login
 * Authenticates user by email/password and returns { token, user }
 */
router.post(
  '/login',
  [
    body('email').trim().notEmpty().withMessage('Email is required').toLowerCase(),
    body('password').notEmpty().withMessage('Password is required'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg, errors: errors.array() });

    const { email, password } = req.body;

    try {
      const db = getDb();
      const snap = await db.collection('users').where('email', '==', email).limit(1).get();
      const userDoc = snap.empty ? null : snap.docs[0];
      const userData = userDoc ? userDoc.data() : null;

      if (!userData || !verifyPassword(password, userData.passwordHash)) {
        return res.status(401).json({ error: 'Incorrect email or password.' });
      }
      if (userData.active === false) {
        return res.status(403).json({ error: 'This account has been deactivated.' });
      }

      const uid = userData.uid || userDoc.id;
      res.json({
        message: 'Login successful',
        token: createSessionToken(uid),
        user: publicUser({ id: uid, ...userData }),
      });
    } catch (err) {
      console.error('[Auth] Login error:', err.message);
      res.status(500).json({ error: 'Login failed' });
    }
  }
);

/**
 * GET /api/auth/me
 * Returns the authenticated user's profile.
 */
router.get('/me', authenticate, async (req, res) => {
  try {
    const db = getDb();
    const doc = await db.collection('users').doc(req.user.uid).get();
    if (!doc.exists) return res.status(404).json({ error: 'User profile not found' });
    res.json({ user: publicUser(doc.data()) });
  } catch (err) {
    console.error('[Auth] Me error:', err.message);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

/**
 * PATCH /api/auth/fcm-token
 * Update FCM token for push notifications.
 */
router.patch('/fcm-token', authenticate, async (req, res) => {
  const { fcmToken } = req.body;
  if (!fcmToken) return res.status(400).json({ error: 'fcmToken is required' });

  try {
    const db = getDb();
    await db.collection('users').doc(req.user.uid).update({
      fcmToken,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ message: 'FCM token updated' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update FCM token' });
  }
});

module.exports = router;
