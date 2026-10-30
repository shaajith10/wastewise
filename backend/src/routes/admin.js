const express = require('express');
const { body, validationResult } = require('express-validator');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');

const router = express.Router();
router.use(authenticate, requireRole('admin'));

// ─── Stats ────────────────────────────────────────────────────────────────────
/**
 * GET /api/admin/stats
 */
router.get('/stats', async (req, res) => {
  try {
    const db = getDb();
    const [
      usersSnap, collectorsSnap, requestsSnap, recyclingSnap, rewardsSnap,
    ] = await Promise.all([
      db.collection('users').where('role', '==', 'citizen').get(),
      db.collection('users').where('role', '==', 'collector').get(),
      db.collection('pickupRequests').get(),
      db.collection('recyclingRecords').get(),
      db.collection('rewardTransactions').get(),
    ]);

    const statusCounts = {};
    requestsSnap.docs.forEach(d => {
      const s = d.data().status;
      statusCounts[s] = (statusCounts[s] || 0) + 1;
    });

    const totalRewardsIssued = rewardsSnap.docs.reduce(
      (sum, d) => sum + (d.data().points || 0), 0
    );
    const totalKgRecycled = recyclingSnap.docs.reduce(
      (sum, d) => sum + (d.data().quantityKg || 0), 0
    );

    res.json({
      stats: {
        totalCitizens: usersSnap.size,
        totalCollectors: collectorsSnap.size,
        totalRequests: requestsSnap.size,
        requestsByStatus: statusCounts,
        totalKgRecycled: Math.round(totalKgRecycled * 100) / 100,
        totalRewardsIssued,
        totalRecyclingRecords: recyclingSnap.size,
      },
    });
  } catch (err) {
    console.error('[Admin] Stats error:', err.message);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// ─── Recent Activity ──────────────────────────────────────────────────────────
/**
 * GET /api/admin/activity
 */
router.get('/activity', async (req, res) => {
  try {
    const db = getDb();
    const snapshot = await db
      .collection('notifications')
      .orderBy('createdAt', 'desc')
      .limit(30)
      .get();
    const activity = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));
    res.json({ activity });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch activity' });
  }
});

// ─── Waste Categories ─────────────────────────────────────────────────────────
router.get('/categories', async (req, res) => {
  try {
    const db = getDb();
    const snap = await db.collection('wasteCategories').orderBy('name').get();
    res.json({ categories: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

router.post(
  '/categories',
  [body('name').notEmpty().trim(), body('description').optional().trim()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });
    try {
      const db = getDb();
      const ref = await db.collection('wasteCategories').add({
        name: req.body.name,
        description: req.body.description || '',
        iconName: req.body.iconName || 'delete',
        active: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(201).json({ id: ref.id, message: 'Category created' });
    } catch (err) {
      res.status(500).json({ error: 'Failed to create category' });
    }
  }
);

router.patch('/categories/:id', async (req, res) => {
  const { name, description, iconName, active } = req.body;
  const updates = {};
  if (name) updates.name = name;
  if (description !== undefined) updates.description = description;
  if (iconName) updates.iconName = iconName;
  if (active !== undefined) updates.active = active;
  try {
    const db = getDb();
    await db.collection('wasteCategories').doc(req.params.id).update(updates);
    res.json({ message: 'Category updated' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update category' });
  }
});

router.delete('/categories/:id', async (req, res) => {
  try {
    const db = getDb();
    await db.collection('wasteCategories').doc(req.params.id).update({ active: false });
    res.json({ message: 'Category deactivated' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to deactivate category' });
  }
});

// ─── Reward Rules ─────────────────────────────────────────────────────────────
router.get('/reward-rules', async (req, res) => {
  try {
    const db = getDb();
    const snap = await db.collection('rewardRules').get();
    res.json({ rules: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch reward rules' });
  }
});

router.post(
  '/reward-rules',
  [
    body('categoryId').notEmpty(),
    body('categoryName').notEmpty(),
    body('pointsPerKg').isFloat({ min: 0 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });
    try {
      const db = getDb();
      const ref = await db.collection('rewardRules').add({
        categoryId: req.body.categoryId,
        categoryName: req.body.categoryName,
        pointsPerKg: parseFloat(req.body.pointsPerKg),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(201).json({ id: ref.id, message: 'Reward rule created' });
    } catch (err) {
      res.status(500).json({ error: 'Failed to create reward rule' });
    }
  }
);

router.patch('/reward-rules/:id', async (req, res) => {
  const { pointsPerKg } = req.body;
  if (pointsPerKg === undefined) return res.status(400).json({ error: 'pointsPerKg is required' });
  try {
    const db = getDb();
    await db.collection('rewardRules').doc(req.params.id).update({
      pointsPerKg: parseFloat(pointsPerKg),
    });
    res.json({ message: 'Reward rule updated' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update reward rule' });
  }
});

// ─── Reports ──────────────────────────────────────────────────────────────────
/**
 * GET /api/admin/reports/recycling
 */
router.get('/reports/recycling', async (req, res) => {
  try {
    const db = getDb();
    const snap = await db
      .collection('recyclingRecords')
      .orderBy('verifiedAt', 'desc')
      .limit(200)
      .get();
    res.json({ records: snap.docs.map(d => ({ id: d.id, ...d.data() })) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch recycling records' });
  }
});

module.exports = router;
