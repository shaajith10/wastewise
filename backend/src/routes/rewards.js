const express = require('express');
const { body, validationResult } = require('express-validator');
const { getDb } = require('../config/firebase');
const { authenticate } = require('../middleware/auth');
const {
  awardRewardPoints,
  redeemVoucher,
  getUserVouchers,
  getRewardsCatalog,
} = require('../services/rewardService');

const router = express.Router();
router.use(authenticate);

/**
 * GET /api/rewards/balance
 * Citizen: own balance. Admin: any uid via ?uid=.
 */
router.get('/balance', async (req, res) => {
  const targetUid = req.user.role === 'admin' && req.query.uid ? req.query.uid : req.user.uid;

  try {
    const db = getDb();
    const doc = await db.collection('users').doc(targetUid).get();
    if (!doc.exists) return res.status(404).json({ error: 'User not found' });
    const rewardBalance = doc.data().rewardBalance !== undefined ? doc.data().rewardBalance : 0;
    res.json({ uid: targetUid, rewardBalance });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch balance' });
  }
});

/**
 * GET /api/rewards/transactions
 * Citizen: own transactions. Admin: all (or filter by ?uid=).
 */
router.get('/transactions', async (req, res) => {
  try {
    const db = getDb();
    let query = db.collection('rewardTransactions');

    if (req.user.role === 'citizen') {
      query = query.where('citizenUid', '==', req.user.uid);
    } else if (req.user.role === 'admin' && req.query.uid) {
      query = query.where('citizenUid', '==', req.query.uid);
    }

    query = query.orderBy('createdAt', 'desc').limit(100);
    const snapshot = await query.get();
    const transactions = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));

    // Sort descending by createdAt
    transactions.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    res.json({ transactions });
  } catch (err) {
    console.error('[Rewards] Transactions error:', err.message);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

/**
 * GET /api/rewards/catalog
 * Available incentive vouchers for redemption.
 */
router.get('/catalog', (_req, res) => {
  res.json({ catalog: getRewardsCatalog() });
});

/**
 * GET /api/rewards/my-vouchers
 * Vouchers redeemed by the logged-in citizen.
 */
router.get('/my-vouchers', async (req, res) => {
  try {
    const vouchers = await getUserVouchers(req.user.uid);
    vouchers.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    res.json({ vouchers });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch redeemed vouchers' });
  }
});

/**
 * POST /api/rewards/redeem
 * Citizen redeems points for a voucher.
 */
router.post(
  '/redeem',
  async (req, res) => {
    let { voucherId, title, cost, category } = req.body;
    if (!voucherId) {
      return res.status(422).json({ error: 'voucherId is required' });
    }

    if (!cost || !title) {
      const catalog = getRewardsCatalog();
      const item = catalog.find((v) => v.id === voucherId);
      if (item) {
        title = title || item.title;
        cost = cost || item.cost;
        category = category || item.category;
      }
    }

    if (!title || !cost || isNaN(cost) || cost <= 0) {
      return res.status(422).json({ error: 'Invalid voucher or missing cost/title' });
    }

    try {
      const result = await redeemVoucher({
        citizenUid: req.user.uid,
        voucherId,
        title,
        cost: parseInt(cost, 10),
        category,
      });

      res.status(201).json({
        message: '🎉 Voucher redeemed successfully!',
        voucher: result.voucher,
        newBalance: result.newBalance,
      });
    } catch (err) {
      console.error('[Rewards] Redeem error:', err.message);
      res.status(400).json({ error: err.message });
    }
  }
);

/**
 * GET /api/rewards/rules
 * Points per kg configuration for all waste categories.
 */
router.get('/rules', async (_req, res) => {
  try {
    const db = getDb();
    const snap = await db.collection('rewardRules').get();
    res.json({ rules: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch reward rules' });
  }
});

/**
 * POST /api/rewards/bonus
 * Claims daily recycling login bonus (+50 points)
 */
router.post('/bonus', async (req, res) => {
  try {
    const db = getDb();
    const userRef = db.collection('users').doc(req.user.uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return res.status(404).json({ error: 'User not found' });

    const currentBal = userSnap.data().rewardBalance || 0;
    const bonus = 50;
    const newBal = currentBal + bonus;
    const now = new Date().toISOString();

    await userRef.update({
      rewardBalance: newBal,
      updatedAt: now,
    });

    const txId = `bonus_${Date.now()}`;
    await db.collection('rewardTransactions').doc(txId).set({
      id: txId,
      transactionId: txId,
      citizenUid: req.user.uid,
      points: bonus,
      type: 'earned',
      categoryName: 'Daily Eco Check-in',
      quantityKg: 0,
      description: 'Daily Eco Check-in Reward (+50 pts)',
      createdAt: now,
    });

    res.json({
      message: '🎉 Daily Eco Bonus claimed! (+50 pts)',
      bonus,
      newBalance: newBal,
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to claim bonus' });
  }
});

module.exports = router;
