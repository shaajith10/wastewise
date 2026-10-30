const express = require('express');
const { body, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { awardRewardPoints } = require('../services/rewardService');
const { sendNotification } = require('../services/notificationService');

const router = express.Router();
router.use(authenticate);

/**
 * GET /api/recycling-records
 * The single source of truth behind both the citizen's "Recycling History"
 * screen and the admin "Reports" screen, so they can never drift apart.
 * - Citizen: only their own verified recycling.
 * - Collector: only the pickups they personally verified.
 * - Admin: everyone's, optionally filtered by ?citizenUid= or ?categoryId=.
 */
router.get('/', async (req, res) => {
  try {
    const db = getDb();
    let query = db.collection('recyclingRecords');

    if (req.user.role === 'citizen') {
      query = query.where('citizenUid', '==', req.user.uid);
    } else if (req.user.role === 'collector') {
      query = query.where('collectorUid', '==', req.user.uid);
    } else if (req.user.role === 'admin') {
      if (req.query.citizenUid) query = query.where('citizenUid', '==', req.query.citizenUid);
      if (req.query.categoryId) query = query.where('categoryId', '==', req.query.categoryId);
    }

    query = query.orderBy('verifiedAt', 'desc').limit(parseInt(req.query.limit || '200', 10));
    const snapshot = await query.get();
    const records = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));
    records.sort((a, b) => new Date(b.verifiedAt || 0) - new Date(a.verifiedAt || 0));

    res.json({ records });
  } catch (err) {
    console.error('[RecyclingRecords] List error:', err.message);
    res.status(500).json({ error: 'Failed to fetch recycling records' });
  }
});

/**
 * POST /api/recycling-records
 * Admin-only: manually logs a recycling event for a citizen — same path a real
 * QR verification takes (reward points calculated from the category's rate and
 * credited to the citizen's wallet), for backfilling history or demo data
 * without needing a real pickup request and collector scan.
 * Body: { citizenUid, categoryId, categoryName, quantityKg, verifiedAt? }
 */
router.post(
  '/',
  requireRole('admin'),
  [
    body('citizenUid').trim().notEmpty().withMessage('Select a citizen'),
    body('categoryId').trim().notEmpty().withMessage('Select a waste category'),
    body('categoryName').trim().notEmpty(),
    body('quantityKg').isFloat({ gt: 0 }).withMessage('Weight must be greater than 0'),
    body('verifiedAt').optional({ checkFalsy: true }).isISO8601().withMessage('Invalid date'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg, errors: errors.array() });

    const { citizenUid, categoryId, categoryName, quantityKg, verifiedAt } = req.body;

    try {
      const db = getDb();
      const citizenDoc = await db.collection('users').doc(citizenUid).get();
      if (!citizenDoc.exists) return res.status(404).json({ error: 'Citizen not found' });
      const citizenData = citizenDoc.data();
      if (citizenData.role !== 'citizen') {
        return res.status(400).json({ error: `${citizenData.displayName || 'That user'} is not a citizen account.` });
      }

      // A synthetic, always-unique requestId — reuses the same idempotent,
      // rate-looked-up crediting logic the real QR flow uses, just not tied
      // to a real pickup request.
      const requestId = `manual_${uuidv4()}`;
      const { points, newBalance } = await awardRewardPoints({
        citizenUid, requestId, categoryId, quantityKg, actualWeightKg: quantityKg,
      });

      const recordRef = await db.collection('recyclingRecords').add({
        requestId,
        citizenUid,
        citizenName: citizenData.displayName || 'Citizen',
        collectorUid: null,
        collectorName: `Added by ${req.user.displayName || 'Admin'}`,
        categoryId,
        categoryName,
        quantityKg: parseFloat(quantityKg),
        points,
        verifiedAt: verifiedAt || new Date().toISOString(),
        source: 'manual',
        addedByUid: req.user.uid,
      });

      sendNotification({
        toUid: citizenUid,
        title: '🎉 Recycling Added to Your History',
        body: `An admin logged ${quantityKg} kg of ${categoryName} for you. You earned ${points} reward points!`,
        type: 'verified',
        data: { requestId, points: String(points) },
        fcmToken: citizenData.fcmToken,
      }).catch(() => {});

      res.status(201).json({ message: 'Recycling record added', id: recordRef.id, points, newBalance });
    } catch (err) {
      console.error('[RecyclingRecords] Manual add error:', err.message);
      res.status(500).json({ error: 'Failed to add recycling record' });
    }
  }
);

/**
 * DELETE /api/recycling-records/:id
 * Admin-only: removes a record from the report (e.g. a data-entry mistake).
 * Does NOT reverse the reward points already credited for it — those are a
 * separate ledger (rewardTransactions) and stay untouched, so a citizen's
 * wallet is never silently changed by a report cleanup.
 */
router.delete('/:id', requireRole('admin'), async (req, res) => {
  try {
    const db = getDb();
    const ref = db.collection('recyclingRecords').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ error: 'Record not found' });

    await ref.delete();
    res.json({ message: 'Record removed from the report' });
  } catch (err) {
    console.error('[RecyclingRecords] Delete error:', err.message);
    res.status(500).json({ error: 'Failed to remove record' });
  }
});

module.exports = router;
