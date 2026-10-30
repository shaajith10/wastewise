const express = require('express');
const { body, validationResult } = require('express-validator');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');

const router = express.Router();
router.use(authenticate);

/**
 * GET /api/notifications
 * Returns notifications for the current user.
 */
router.get('/', async (req, res) => {
  try {
    const db = getDb();
    const snapshot = await db
      .collection('notifications')
      .where('toUid', '==', req.user.uid)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const notifications = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json({ notifications });
  } catch (err) {
    console.error('[Notifications] List error:', err.message);
    res.status(500).json({ error: 'Failed to fetch notifications' });
  }
});

/**
 * PATCH /api/notifications/:id/read
 * Mark a notification as read.
 */
router.patch('/:id/read', async (req, res) => {
  try {
    const db = getDb();
    const ref = db.collection('notifications').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ error: 'Notification not found' });
    if (doc.data().toUid !== req.user.uid && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied' });
    }
    await ref.update({ read: true });
    res.json({ message: 'Notification marked as read' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update notification' });
  }
});

/**
 * PATCH /api/notifications/read-all
 * Mark all notifications for current user as read.
 */
router.patch('/read-all', async (req, res) => {
  try {
    const db = getDb();
    const snapshot = await db
      .collection('notifications')
      .where('toUid', '==', req.user.uid)
      .where('read', '==', false)
      .get();

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.update(doc.ref, { read: true }));
    await batch.commit();
    res.json({ message: `${snapshot.size} notifications marked as read` });
  } catch (err) {
    res.status(500).json({ error: 'Failed to mark all as read' });
  }
});

module.exports = router;
