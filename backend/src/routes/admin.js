const express = require('express');
const { body, validationResult } = require('express-validator');
const { getDb, admin } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/role');
const { createUserAccount, publicUser } = require('../services/authService');

const router = express.Router();
router.use(authenticate, requireRole('admin'));

// ─── Users ────────────────────────────────────────────────────────────────────
/**
 * GET /api/admin/users
 * All user accounts (citizens, collectors, admins).
 */
router.get('/users', async (req, res) => {
  try {
    const db = getDb();
    const snap = await db.collection('users').get();
    const users = snap.docs
      .map((d) => publicUser({ id: d.id, ...d.data() }))
      .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    res.json({ users });
  } catch (err) {
    console.error('[Admin] Users list error:', err.message);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

/**
 * POST /api/admin/users
 * Admin manually creates an account with any role (citizen, collector, admin).
 * Body: { displayName, email, phone, password, role }
 */
router.post(
  '/users',
  [
    body('displayName').trim().notEmpty().withMessage('Name is required'),
    body('email').trim().isEmail().withMessage('A valid email is required'),
    body('phone')
      .trim()
      .notEmpty().withMessage('Phone number is required')
      .custom((v) => /^\d{10,13}$/.test(v.replace(/\D/g, ''))).withMessage('Enter a valid 10-digit phone number'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
    body('role').isIn(['citizen', 'collector', 'admin']).withMessage('Role must be citizen, collector or admin'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ error: errors.array()[0].msg, errors: errors.array() });

    try {
      const { displayName, email, phone, password, role } = req.body;
      const userData = await createUserAccount({ displayName, email, phone, password, role });
      res.status(201).json({ message: 'User account created', user: publicUser(userData) });
    } catch (err) {
      if (err.status) return res.status(err.status).json({ error: err.message });
      console.error('[Admin] Create user error:', err.message);
      res.status(500).json({ error: 'Failed to create user' });
    }
  }
);

/**
 * PATCH /api/admin/users/:uid
 * Update role / active status for any account (citizens, collectors, admins).
 */
router.patch(
  '/users/:uid',
  [
    body('role').optional().isIn(['citizen', 'collector', 'admin']),
    body('active').optional().isBoolean(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(422).json({ errors: errors.array() });

    const { uid } = req.params;
    if (uid === req.user.uid && req.body.role && req.body.role !== 'admin') {
      return res.status(400).json({ error: "You can't change your own role away from admin." });
    }
    if (uid === req.user.uid && req.body.active === false) {
      return res.status(400).json({ error: "You can't deactivate your own account." });
    }

    const updates = {};
    if (req.body.role !== undefined) updates.role = req.body.role;
    if (req.body.active !== undefined) updates.active = req.body.active;
    if (Object.keys(updates).length === 0) return res.status(400).json({ error: 'Nothing to update' });
    updates.updatedAt = new Date().toISOString();

    try {
      const db = getDb();
      const ref = db.collection('users').doc(uid);
      const doc = await ref.get();
      if (!doc.exists) return res.status(404).json({ error: 'User not found' });

      await ref.update(updates);
      res.json({ message: 'User updated', user: publicUser({ id: uid, ...doc.data(), ...updates }) });
    } catch (err) {
      console.error('[Admin] Update user error:', err.message);
      res.status(500).json({ error: 'Failed to update user' });
    }
  }
);

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
