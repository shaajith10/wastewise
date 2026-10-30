const express = require('express');
const { getDb } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

/**
 * GET /api/categories
 * Returns all active waste categories with reward points per kg.
 * Accessible to Citizens, Collectors, and Admins.
 */
router.get('/', async (_req, res) => {
  try {
    const db = getDb();
    const snap = await db.collection('wasteCategories').get();
    let categories = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    // Filter to active ones if active flag exists
    categories = categories.filter((c) => c.active !== false);

    // Sort by name
    categories.sort((a, b) => (a.name || '').localeCompare(b.name || ''));

    res.json({ categories });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

module.exports = router;
