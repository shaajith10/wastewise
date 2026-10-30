const { body, param, validationResult } = require('express-validator');
const express = require('express');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { generateQrToken } = require('../services/qrService');
const { sendNotification, notifyStatusChange } = require('../services/notificationService');

const router = express.Router();
router.use(authenticate);

// ─── Status transition rules ──────────────────────────────────────────────────
const ALLOWED_TRANSITIONS = {
  citizen: {
    Pending: ['Cancelled'],
    Assigned: ['Cancelled'],
    Accepted: ['Cancelled'],
  },
  collector: {
    Pending: ['Accepted', 'Assigned'],
    Assigned: ['Accepted', 'Collected', 'Completed', 'Cancelled'],
    Accepted: ['Collected', 'Completed', 'Cancelled'],
    Collected: ['Verified', 'Completed'],
    Verified: ['Completed'],
  },
  admin: {
    Pending: ['Assigned', 'Accepted', 'Cancelled'],
    Assigned: ['Accepted', 'Collected', 'Cancelled'],
    Accepted: ['Collected', 'Cancelled'],
    Collected: ['Verified', 'Completed', 'Cancelled'],
    Verified: ['Completed'],
  },
};

function canTransition(role, currentStatus, newStatus) {
  const allowed = ALLOWED_TRANSITIONS[role]?.[currentStatus] || [];
  return allowed.includes(newStatus);
}

// ─── Routes ───────────────────────────────────────────────────────────────────

/**
 * POST /api/pickup-requests
 * Citizen creates a new pickup request.
 */
router.post(
  '/',
  requireRole('citizen', 'admin'),
  async (req, res) => {
    let { categoryId, categoryName, quantityKg, description, address } = req.body;

    // Support payload aliases
    categoryId = categoryId || req.body.category || 'cat_plastic';
    categoryName = categoryName || req.body.categoryName || (categoryId.charAt(0).toUpperCase() + categoryId.slice(1));
    quantityKg = quantityKg !== undefined ? parseFloat(quantityKg) : (req.body.estimatedWeightKg ? parseFloat(req.body.estimatedWeightKg) : 0);

    if (!address || !address.trim()) {
      return res.status(422).json({ error: 'address is required' });
    }
    if (!quantityKg || isNaN(quantityKg) || quantityKg <= 0) {
      return res.status(422).json({ error: 'quantityKg must be a positive number' });
    }

    const latitude = req.body.latitude ? parseFloat(req.body.latitude) : 12.9716;
    const longitude = req.body.longitude ? parseFloat(req.body.longitude) : 77.5946;

    try {
      const db = getDb();
      const requestRef = db.collection('pickupRequests').doc();
      const qrToken = generateQrToken(requestRef.id, req.user.uid);
      const now = new Date().toISOString();

      const requestData = {
        id: requestRef.id,
        citizenUid: req.user.uid,
        citizenName: req.user.displayName || 'Citizen',
        citizenEmail: req.user.email,
        categoryId,
        categoryName,
        quantityKg: parseFloat(quantityKg),
        description: description || '',
        address,
        latitude,
        longitude,
        status: 'Pending',
        qrToken,
        collectorUid: null,
        collectorName: null,
        qrVerified: false,
        statusHistory: [{ status: 'Pending', timestamp: now, by: req.user.uid }],
        createdAt: now,
        updatedAt: now,
      };

      await requestRef.set(requestData);

      // Notify all admins and collectors
      const [adminSnap, collectorSnap] = await Promise.all([
        db.collection('users').where('role', '==', 'admin').get(),
        db.collection('users').where('role', '==', 'collector').get(),
      ]);

      for (const doc of [...adminSnap.docs, ...collectorSnap.docs]) {
        const user = doc.data();
        sendNotification({
          toUid: user.uid,
          title: '📢 New Waste Pickup Request',
          body: `${req.user.displayName || 'Citizen'} requested ${categoryName} pickup (${quantityKg} kg) at ${address}.`,
          type: 'request_submitted',
          data: { requestId: requestRef.id },
          fcmToken: user.fcmToken,
        }).catch(() => {});
      }

      res.status(201).json({ message: 'Pickup request created successfully', request: requestData });
    } catch (err) {
      console.error('[PickupRequest] Create error:', err.message);
      res.status(500).json({ error: 'Failed to create pickup request' });
    }
  }
);

/**
 * GET /api/pickup-requests
 * - Citizen: own requests
 * - Collector: assigned requests AND available pending requests
 * - Admin: all requests
 */
router.get('/', async (req, res) => {
  try {
    const db = getDb();
    let query = db.collection('pickupRequests');

    if (req.user.role === 'citizen') {
      query = query.where('citizenUid', '==', req.user.uid);
    } else if (req.user.role === 'collector') {
      if (req.query.scope === 'assigned') {
        query = query.where('collectorUid', '==', req.user.uid);
      } else if (req.query.scope === 'available') {
        query = query.where('status', '==', 'Pending');
      }
      // default: return all tasks relevant to collector (will filter or return all)
    }

    if (req.query.status) {
      query = query.where('status', '==', req.query.status);
    }

    query = query.orderBy('createdAt', 'desc').limit(parseInt(req.query.limit || '100', 10));
    const snapshot = await query.get();
    let requests = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));

    // If collector without scope specified, include their tasks + available pending tasks
    if (req.user.role === 'collector' && !req.query.scope) {
      requests = requests.filter(
        (r) => r.collectorUid === req.user.uid || r.status === 'Pending'
      );
    }

    // Sort descending by createdAt
    requests.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    res.json({ requests });
  } catch (err) {
    console.error('[PickupRequest] List error:', err.message);
    res.status(500).json({ error: 'Failed to fetch requests' });
  }
});

/**
 * GET /api/pickup-requests/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const db = getDb();
    const doc = await db.collection('pickupRequests').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Request not found' });

    const data = { id: doc.id, ...doc.data() };

    // Ownership check (Admins and Collectors can inspect any task)
    if (req.user.role === 'citizen' && data.citizenUid !== req.user.uid) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json({ request: data });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch request' });
  }
});

/**
 * POST /api/pickup-requests/:id/claim
 * Collector self-assigns / accepts an open pending request.
 */
router.post('/:id/claim', requireRole('collector', 'admin'), async (req, res) => {
  const { id } = req.params;

  try {
    const db = getDb();
    const doc = await db.collection('pickupRequests').doc(id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Request not found' });

    const reqData = doc.data();
    if (reqData.status !== 'Pending') {
      const why = reqData.status === 'Cancelled'
        ? 'This request was cancelled.'
        : `Task is already assigned to ${reqData.collectorName || 'another collector'}.`;
      return res.status(400).json({ error: why });
    }

    const now = new Date().toISOString();
    await db.collection('pickupRequests').doc(id).update({
      collectorUid: req.user.uid,
      collectorName: req.user.displayName || 'Authorized Collector',
      status: 'Accepted',
      updatedAt: now,
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        status: 'Accepted',
        timestamp: now,
        by: req.user.uid,
      }),
    });

    // Notify citizen
    const citizenDoc = await db.collection('users').doc(reqData.citizenUid).get();
    const citizenData = citizenDoc.exists ? citizenDoc.data() : {};
    sendNotification({
      toUid: reqData.citizenUid,
      title: '🚛 Collector is On The Way!',
      body: `${req.user.displayName || 'A collector'} has accepted your pickup request and is heading to your location.`,
      type: 'task_assigned',
      data: { requestId: id },
      fcmToken: citizenData.fcmToken,
    }).catch(() => {});

    res.json({ message: 'Pickup task claimed and accepted successfully!', status: 'Accepted' });
  } catch (err) {
    console.error('[PickupRequest] Claim error:', err.message);
    res.status(500).json({ error: 'Failed to claim task' });
  }
});

/**
 * PATCH /api/pickup-requests/:id/status
 * Update request status (role-based allowed transitions).
 */
router.patch('/:id/status', [body('status').notEmpty()], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

  const { status: newStatus } = req.body;
  const { id } = req.params;

  try {
    const db = getDb();
    const doc = await db.collection('pickupRequests').doc(id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Request not found' });

    const data = doc.data();

    // Ownership check
    if (req.user.role === 'citizen' && data.citizenUid !== req.user.uid) {
      return res.status(403).json({ error: 'Access denied' });
    }
    if (!canTransition(req.user.role, data.status, newStatus)) {
      return res.status(400).json({ error: `Cannot change status from ${data.status} to ${newStatus}.` });
    }

    const now = new Date().toISOString();
    await db.collection('pickupRequests').doc(id).update({
      status: newStatus,
      updatedAt: now,
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        status: newStatus,
        timestamp: now,
        by: req.user.uid,
      }),
    });

    // Notify citizen
    const citizenDoc = await db.collection('users').doc(data.citizenUid).get();
    const citizenData = citizenDoc.exists ? citizenDoc.data() : {};
    notifyStatusChange({
      requestId: id,
      citizenUid: data.citizenUid,
      citizenFcmToken: citizenData.fcmToken,
      newStatus,
    }).catch(() => {});

    res.json({ message: `Status updated to ${newStatus}`, status: newStatus });
  } catch (err) {
    console.error('[PickupRequest] Status update error:', err.message);
    res.status(500).json({ error: 'Failed to update status' });
  }
});

// A request can be cancelled or released only before the waste is collected.
const CANCELLABLE_STATUSES = ['Pending', 'Assigned', 'Accepted'];

async function notifyUser(db, uid, notification) {
  if (!uid) return;
  const doc = await db.collection('users').doc(uid).get();
  sendNotification({
    toUid: uid,
    fcmToken: doc.exists ? doc.data().fcmToken : null,
    ...notification,
  }).catch(() => {});
}

/**
 * POST /api/pickup-requests/:id/cancel
 * Citizen (own request) or admin cancels a request that hasn't been collected yet.
 * A collector may also cancel, but only while the request is still unclaimed
 * (Pending) — once they've claimed it, they use /release instead.
 * Body: { reason? }
 */
router.post('/:id/cancel', requireRole('citizen', 'collector', 'admin'), async (req, res) => {
  const { id } = req.params;
  const reason = String(req.body.reason || '').trim().slice(0, 200);

  try {
    const db = getDb();
    const doc = await db.collection('pickupRequests').doc(id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Request not found' });

    const data = doc.data();
    if (req.user.role === 'citizen' && data.citizenUid !== req.user.uid) {
      return res.status(403).json({ error: 'Access denied' });
    }
    if (req.user.role === 'collector' && data.status !== 'Pending') {
      return res.status(403).json({ error: 'Only unclaimed requests can be cancelled this way. Use "Cancel Pickup" on your claimed task instead.' });
    }
    if (!CANCELLABLE_STATUSES.includes(data.status)) {
      return res.status(400).json({ error: `A ${data.status.toLowerCase()} request can no longer be cancelled.` });
    }

    const now = new Date().toISOString();
    await db.collection('pickupRequests').doc(id).update({
      status: 'Cancelled',
      cancelledBy: req.user.role,
      cancelReason: reason || null,
      updatedAt: now,
      statusHistory: admin.firestore.FieldValue.arrayUnion({ status: 'Cancelled', timestamp: now, by: req.user.uid }),
    });

    const byText = req.user.role === 'admin' ? 'an administrator' : (req.user.role === 'collector' ? 'a collector' : 'the citizen');
    notifyUser(db, data.collectorUid, {
      title: '🚫 Pickup Cancelled',
      body: `The ${data.categoryName} pickup at ${data.address} was cancelled by ${byText}.`,
      type: 'request_cancelled',
      data: { requestId: id },
    });
    if (req.user.role !== 'citizen') {
      notifyUser(db, data.citizenUid, {
        title: '🚫 Pickup Request Cancelled',
        body: `Your ${data.categoryName} pickup request was cancelled by ${byText}.${reason ? ` Reason: ${reason}` : ''}`,
        type: 'request_cancelled',
        data: { requestId: id },
      });
    }

    res.json({ message: 'Pickup request cancelled', status: 'Cancelled' });
  } catch (err) {
    console.error('[PickupRequest] Cancel error:', err.message);
    res.status(500).json({ error: 'Failed to cancel request' });
  }
});

/**
 * POST /api/pickup-requests/:id/release
 * Collector drops an assigned/accepted task. The request goes back to Pending
 * so another collector can claim it; the citizen's request stays open.
 */
router.post('/:id/release', requireRole('collector', 'admin'), async (req, res) => {
  const { id } = req.params;

  try {
    const db = getDb();
    const doc = await db.collection('pickupRequests').doc(id).get();
    if (!doc.exists) return res.status(404).json({ error: 'Request not found' });

    const data = doc.data();
    if (req.user.role === 'collector' && data.collectorUid !== req.user.uid) {
      return res.status(403).json({ error: 'This task is not assigned to you.' });
    }
    if (!['Assigned', 'Accepted'].includes(data.status)) {
      return res.status(400).json({ error: `A ${data.status.toLowerCase()} task cannot be cancelled.` });
    }

    const now = new Date().toISOString();
    await db.collection('pickupRequests').doc(id).update({
      status: 'Pending',
      collectorUid: null,
      collectorName: null,
      updatedAt: now,
      statusHistory: admin.firestore.FieldValue.arrayUnion({ status: 'Pending', timestamp: now, by: req.user.uid }),
    });

    notifyUser(db, data.citizenUid, {
      title: '🔄 Collector Changed',
      body: `${data.collectorName || 'Your collector'} can no longer make your ${data.categoryName} pickup. We'll find another collector soon.`,
      type: 'status_update',
      data: { requestId: id },
    });

    res.json({ message: 'Task cancelled and returned to the open pool', status: 'Pending' });
  } catch (err) {
    console.error('[PickupRequest] Release error:', err.message);
    res.status(500).json({ error: 'Failed to cancel task' });
  }
});

/**
 * POST /api/pickup-requests/:id/assign
 * Admin assigns a collector to a request.
 */
router.post(
  '/:id/assign',
  requireRole('admin'),
  [body('collectorUid').notEmpty().withMessage('collectorUid is required')],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { collectorUid } = req.body;
    const { id } = req.params;

    try {
      const db = getDb();
      const [reqDoc, collectorDoc] = await Promise.all([
        db.collection('pickupRequests').doc(id).get(),
        db.collection('users').doc(collectorUid).get(),
      ]);

      if (!reqDoc.exists) return res.status(404).json({ error: 'Request not found' });
      if (!collectorDoc.exists) return res.status(404).json({ error: 'Collector not found' });

      const reqData = reqDoc.data();
      const collectorData = collectorDoc.data();
      const now = new Date().toISOString();

      await db.collection('pickupRequests').doc(id).update({
        collectorUid,
        collectorName: collectorData.displayName || 'Authorized Collector',
        status: 'Assigned',
        updatedAt: now,
        statusHistory: admin.firestore.FieldValue.arrayUnion({
          status: 'Assigned',
          timestamp: now,
          by: req.user.uid,
        }),
      });

      // Notify collector
      sendNotification({
        toUid: collectorUid,
        title: 'New Pickup Task Assigned',
        body: `You have been assigned a ${reqData.categoryName} pickup at ${reqData.address}.`,
        type: 'task_assigned',
        data: { requestId: id },
        fcmToken: collectorData.fcmToken,
      }).catch(() => {});

      // Notify citizen
      const citizenDoc = await db.collection('users').doc(reqData.citizenUid).get();
      const citizenData = citizenDoc.exists ? citizenDoc.data() : {};
      notifyStatusChange({
        requestId: id,
        citizenUid: reqData.citizenUid,
        citizenFcmToken: citizenData.fcmToken,
        newStatus: 'Assigned',
      }).catch(() => {});

      res.json({ message: 'Collector assigned successfully' });
    } catch (err) {
      console.error('[PickupRequest] Assign error:', err.message);
      res.status(500).json({ error: 'Failed to assign collector' });
    }
  }
);

module.exports = router;
