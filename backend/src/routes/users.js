const { body, validationResult } = require('express-validator');
const express = require('express');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { publicUser } = require('../services/authService');
const { sendNotification } = require('../services/notificationService');

const router = express.Router();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/users
 * Admin: list all users. Others: 403.
 */
router.get('/', requireRole('admin'), async (req, res) => {
  try {
    const db = getDb();
    const snapshot = await db.collection('users').orderBy('createdAt', 'desc').get();
    const users = snapshot.docs.map(d => publicUser({ id: d.id, ...d.data() }));
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

/**
 * GET /api/users/:uid
 * Admin can view any user. Users can only view their own profile.
 */
router.get('/:uid', async (req, res) => {
  const { uid } = req.params;
  if (req.user.role !== 'admin' && req.user.uid !== uid) {
    return res.status(403).json({ error: 'Access denied' });
  }
  try {
    const db = getDb();
    const doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) return res.status(404).json({ error: 'User not found' });
    res.json({ user: publicUser({ id: doc.id, ...doc.data() }) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

/**
 * PATCH /api/users/:uid
 * Admin can update role/active status. Users can update their own displayName/phone/fcmToken.
 */
router.patch(
  '/:uid',
  [
    body('displayName').optional().notEmpty().trim(),
    body('phone').optional().trim(),
    body('role').optional().isIn(['citizen', 'collector', 'admin']),
    body('active').optional().isBoolean(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { uid } = req.params;
    const isAdmin = req.user.role === 'admin';
    const isSelf = req.user.uid === uid;

    if (!isAdmin && !isSelf) return res.status(403).json({ error: 'Access denied' });

    const allowedFields = isAdmin
      ? ['displayName', 'phone', 'role', 'active', 'fcmToken']
      : ['displayName', 'phone', 'fcmToken'];

    const updates = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    }
    updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    try {
      const db = getDb();
      await db.collection('users').doc(uid).update(updates);
      res.json({ message: 'User updated' });
    } catch (err) {
      res.status(500).json({ error: 'Failed to update user' });
    }
  }
);

/**
 * DELETE /api/users/:uid
 * Admin only — soft delete (set active: false).
 */
router.delete('/:uid', requireRole('admin'), async (req, res) => {
  try {
    const db = getDb();
    await db.collection('users').doc(req.params.uid).update({
      active: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ message: 'User deactivated' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to deactivate user' });
  }
});

module.exports = router;
