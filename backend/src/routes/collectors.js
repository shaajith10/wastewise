const express = require('express');
const { body, validationResult } = require('express-validator');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { publicUser, createUserAccount } = require('../services/authService');

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
 * Registers a brand-new collector account with a password, so they can log in
 * immediately. Expects: { displayName, email, phone, password, vehicleType?, vehicleNumber? }
 */
router.post(
  '/',
  [
    body('displayName').trim().notEmpty().withMessage('Name is required'),
    body('email').trim().isEmail().withMessage('A valid email is required'),
    body('phone')
      .trim()
      .notEmpty().withMessage('Phone number is required')
      .custom((v) => /^\d{10,13}$/.test(v.replace(/\D/g, ''))).withMessage('Enter a valid 10-digit phone number'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg, errors: errors.array() });

    try {
      const { displayName, email, phone, password, vehicleType = '', vehicleNumber = '' } = req.body;
      const userData = await createUserAccount({
        displayName, email, phone, password, role: 'collector',
        extra: { vehicleType, vehicleNumber },
      });
      res.status(201).json({ message: 'Collector account created', collector: publicUser(userData) });
    } catch (err) {
      if (err.status) return res.status(err.status).json({ error: err.message });
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
