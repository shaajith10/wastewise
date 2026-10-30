const express = require('express');
const { body, validationResult } = require('express-validator');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { publicUser } = require('../services/authService');

const router = express.Router();
router.use(authenticate, requireRole('admin'));

/**
 * GET /api/collectors
 * List all collector accounts.
 */
router.get('/', async (req, res) => {
  try {
    const db = getDb();
    const snapshot = await db
      .collection('users')
      .where('role', '==', 'collector')
      .orderBy('displayName')
      .get();
    const collectors = snapshot.docs.map(d => publicUser({ id: d.id, ...d.data() }));
    res.json({ collectors });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch collectors' });
  }
});

/**
 * GET /api/collectors/:uid
 */
router.get('/:uid', async (req, res) => {
  try {
    const db = getDb();
    const doc = await db.collection('users').doc(req.params.uid).get();
    if (!doc.exists || doc.data().role !== 'collector') {
      return res.status(404).json({ error: 'Collector not found' });
    }
    res.json({ collector: publicUser({ id: doc.id, ...doc.data() }) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch collector' });
  }
});

/**
 * POST /api/collectors
 * Register a new collector account.
 * Expects: { uid, displayName, email, phone? }
 * The Firebase Auth account must already exist for the uid.
 */
router.post(
  '/',
  [
    body('uid').notEmpty().withMessage('uid is required'),
    body('displayName').notEmpty().trim(),
    body('email').isEmail().normalizeEmail(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { uid, displayName, email, phone = '' } = req.body;

    try {
      const db = getDb();
      const ref = db.collection('users').doc(uid);
      const existing = await ref.get();

      if (existing.exists) {
        // Update role to collector
        await ref.update({ role: 'collector', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        return res.json({ message: 'User promoted to collector' });
      }

      await ref.set({
        uid,
        displayName,
        email,
        phone,
        role: 'collector',
        rewardBalance: 0,
        active: true,
        fcmToken: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(201).json({ message: 'Collector account created' });
    } catch (err) {
      console.error('[Collectors] Create error:', err.message);
      res.status(500).json({ error: 'Failed to create collector' });
    }
  }
);

/**
 * PATCH /api/collectors/:uid
 * Update collector profile (admin only).
 */
router.patch('/:uid', async (req, res) => {
  const { displayName, phone, active } = req.body;
  const updates = {};
  if (displayName !== undefined) updates.displayName = displayName;
  if (phone !== undefined) updates.phone = phone;
  if (active !== undefined) updates.active = active;
  updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

  try {
    const db = getDb();
    await db.collection('users').doc(req.params.uid).update(updates);
    res.json({ message: 'Collector updated' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update collector' });
  }
});

module.exports = router;
