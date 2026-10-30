const { getDb, admin } = require('../config/firebase');

const DEFAULT_POINTS_PER_KG = 15;

const REWARD_CATALOG = [
  {
    id: 'v_elec',
    title: '$10 Electricity / Utility Bill Credit',
    cost: 300,
    category: 'Utilities',
    icon: 'electric_bolt',
    perk: 'Direct discount credited towards your municipal electric bill',
  },
  {
    id: 'v_groc',
    title: '$5 Eco Grocery & Supermarket Voucher',
    cost: 150,
    category: 'Shopping',
    icon: 'shopping_bag',
    perk: 'Usable at participating organic and retail supermarkets',
  },
  {
    id: 'v_bus',
    title: 'Free City Transit 7-Day Bus Pass',
    cost: 250,
    category: 'Transport',
    icon: 'directions_bus',
    perk: 'Unlimited city bus rides for 7 days',
  },
  {
    id: 'v_tree',
    title: 'Plant a Community Tree Certificate',
    cost: 100,
    category: 'Eco Contribution',
    icon: 'park',
    perk: 'A real sapling planted and geo-tagged in your community in your honor',
  },
  {
    id: 'v_coffee',
    title: 'Free Artisan Coffee / Cafe Voucher',
    cost: 80,
    category: 'Food & Drink',
    icon: 'coffee',
    perk: 'Enjoy a free hot beverage in a reusable cup at partner cafes',
  },
];

/**
 * Award reward points to a citizen after verified recycling.
 * Idempotent: uses a transactionId derived from requestId to prevent double-award.
 */
async function awardRewardPoints({ citizenUid, requestId, categoryId, quantityKg, actualWeightKg }) {
  const db = getDb();
  const transactionId = `reward_${requestId}`;

  // 1. Check idempotency — if this reward was already awarded, return early
  const txRef = db.collection('rewardTransactions').doc(transactionId);
  const existing = await txRef.get();
  if (existing.exists) {
    return {
      points: existing.data().points,
      transactionId,
      alreadyAwarded: true,
      newBalance: null,
    };
  }

  // 2. Look up reward rules for the category
  let pointsPerKg = DEFAULT_POINTS_PER_KG;
  let categoryName = 'Recyclable Waste';
  try {
    const ruleSnap = await db
      .collection('rewardRules')
      .where('categoryId', '==', categoryId)
      .limit(1)
      .get();
    if (!ruleSnap.empty) {
      pointsPerKg = ruleSnap.docs[0].data().pointsPerKg || DEFAULT_POINTS_PER_KG;
      categoryName = ruleSnap.docs[0].data().categoryName || categoryName;
    } else {
      const catDoc = await db.collection('wasteCategories').doc(categoryId).get();
      if (catDoc.exists) {
        pointsPerKg = catDoc.data().pointsPerKg || DEFAULT_POINTS_PER_KG;
        categoryName = catDoc.data().name || categoryName;
      }
    }
  } catch (err) {
    console.warn('[Reward] Could not fetch reward rules, using default:', err.message);
  }

  const finalWeight = parseFloat(actualWeightKg) || parseFloat(quantityKg) || 1;
  const points = Math.round(pointsPerKg * finalWeight);

  // 3. Write reward transaction and update user balance atomically
  const userRef = db.collection('users').doc(citizenUid);
  let updatedBalance = 0;

  await db.runTransaction(async (t) => {
    const userSnap = await t.get(userRef);
    const currentBalance = userSnap.exists ? (userSnap.data().rewardBalance || 0) : 0;
    updatedBalance = currentBalance + points;

    const now = new Date().toISOString();
    t.set(txRef, {
      id: transactionId,
      transactionId,
      citizenUid,
      requestId,
      categoryId,
      categoryName,
      quantityKg: finalWeight,
      points,
      pointsPerKg,
      type: 'earned',
      description: `Earned ${points} points for recycling ${finalWeight} kg of ${categoryName}`,
      createdAt: now,
    });

    t.update(userRef, {
      rewardBalance: updatedBalance,
      updatedAt: now,
    });
  });

  return { points, transactionId, alreadyAwarded: false, newBalance: updatedBalance };
}

/**
 * Citizen redeems reward points for a voucher.
 */
async function redeemVoucher({ citizenUid, voucherId, title, cost, category }) {
  const db = getDb();
  const userRef = db.collection('users').doc(citizenUid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new Error('User profile not found');
  }

  const userData = userSnap.data();
  const currentBalance = userData.rewardBalance || 0;
  const pointsCost = parseInt(cost, 10);

  if (currentBalance < pointsCost) {
    throw new Error(`Insufficient points. You have ${currentBalance} points, but ${pointsCost} are required.`);
  }

  const newBalance = currentBalance - pointsCost;
  const now = new Date().toISOString();
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
  const code = `ECO-${randomSuffix}-${Date.now().toString().slice(-4)}`;

  const voucherDocRef = db.collection('userVouchers').doc();
  const voucher = {
    id: voucherDocRef.id,
    citizenUid,
    voucherId,
    title,
    cost: pointsCost,
    category: category || 'Reward',
    code,
    status: 'Active',
    expiresAt,
    createdAt: now,
  };

  await voucherDocRef.set(voucher);

  // Record negative transaction in transaction history
  const txId = `redeem_${voucherDocRef.id}`;
  await db.collection('rewardTransactions').doc(txId).set({
    id: txId,
    transactionId: txId,
    citizenUid,
    points: -pointsCost,
    type: 'redeemed',
    categoryName: `Redeemed: ${title}`,
    voucherCode: code,
    quantityKg: 0,
    description: `Redeemed ${pointsCost} points for ${title} (Voucher Code: ${code})`,
    createdAt: now,
  });

  // Update user balance in Firestore / InMemoryDb
  await userRef.update({
    rewardBalance: newBalance,
    updatedAt: now,
  });

  return { voucher, newBalance };
}

/**
 * Get all vouchers redeemed by a citizen.
 */
async function getUserVouchers(citizenUid) {
  const db = getDb();
  const snap = await db.collection('userVouchers').where('citizenUid', '==', citizenUid).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

function getRewardsCatalog() {
  return REWARD_CATALOG;
}

module.exports = {
  awardRewardPoints,
  redeemVoucher,
  getUserVouchers,
  getRewardsCatalog,
};
