const express = require('express');
const { getDb } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');

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
