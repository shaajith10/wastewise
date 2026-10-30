/**
 * Seed script — populates Firestore with:
 *  - 3 waste categories
 *  - 3 reward rules (one per category)
 *  - 1 admin user document (Firebase Auth account must already exist)
 *  - 1 collector user document
 *  - 1 citizen user document
 *
 * USAGE: npm run seed
 * NOTE: Run AFTER creating the three Firebase Auth accounts manually or via
 *       Firebase Console. Set uid values below to match the actual Firebase UIDs.
 *
 * Dev credentials (create these in Firebase Auth → Email/Password):
 *   admin@waste.dev     / Admin1234!
 *   collector@waste.dev / Collect1234!
 *   citizen@waste.dev   / Citizen1234!
 */
require('dotenv').config();
const { initFirebase, getDb, admin } = require('../config/firebase');

// ─── Seed UIDs (defaults to standalone / demo UIDs) ──────────────────────────
const ADMIN_UID = process.env.SEED_ADMIN_UID || 'seed-admin-uid';
const COLLECTOR_UID = process.env.SEED_COLLECTOR_UID || 'seed-collector-uid';
const CITIZEN_UID = process.env.SEED_CITIZEN_UID || 'seed-citizen-uid';
// ─────────────────────────────────────────────────────────────────────────────

async function seed() {
  initFirebase();
  const db = getDb();

  const ts = admin.firestore.FieldValue.serverTimestamp();

  console.log('Seeding waste categories...');
  const categories = [
    { id: 'cat_plastic', name: 'Plastic', description: 'Bottles, bags, packaging', iconName: 'local_drink' },
    { id: 'cat_paper', name: 'Paper & Cardboard', description: 'Newspapers, boxes, books', iconName: 'article' },
    { id: 'cat_organic', name: 'Organic Waste', description: 'Food scraps, garden waste', iconName: 'eco' },
    { id: 'cat_ewaste', name: 'E-Waste', description: 'Electronics, batteries, cables', iconName: 'devices' },
    { id: 'cat_glass', name: 'Glass', description: 'Bottles, jars', iconName: 'wine_bar' },
    { id: 'cat_metal', name: 'Metal & Cans', description: 'Tins, aluminium cans', iconName: 'hardware' },
  ];

  for (const cat of categories) {
    await db.collection('wasteCategories').doc(cat.id).set({ ...cat, active: true, createdAt: ts });
    console.log(`  ✔ Category: ${cat.name}`);
  }

  console.log('Seeding reward rules...');
  const rules = [
    { categoryId: 'cat_plastic', categoryName: 'Plastic', pointsPerKg: 15 },
    { categoryId: 'cat_paper', categoryName: 'Paper & Cardboard', pointsPerKg: 8 },
    { categoryId: 'cat_organic', categoryName: 'Organic Waste', pointsPerKg: 5 },
    { categoryId: 'cat_ewaste', categoryName: 'E-Waste', pointsPerKg: 25 },
    { categoryId: 'cat_glass', categoryName: 'Glass', pointsPerKg: 10 },
    { categoryId: 'cat_metal', categoryName: 'Metal & Cans', pointsPerKg: 12 },
  ];

  for (const rule of rules) {
    await db.collection('rewardRules').add({ ...rule, createdAt: ts });
    console.log(`  ✔ Rule: ${rule.categoryName} — ${rule.pointsPerKg} pts/kg`);
  }

  console.log('Seeding users...');
  const users = [
    { uid: ADMIN_UID, displayName: 'Admin User', email: 'admin@waste.dev', role: 'admin', phone: '', rewardBalance: 0, active: true, fcmToken: null },
    { uid: COLLECTOR_UID, displayName: 'Alex Collector', email: 'collector@waste.dev', role: 'collector', phone: '555-0100', rewardBalance: 0, active: true, fcmToken: null },
    { uid: CITIZEN_UID, displayName: 'Sam Citizen', email: 'citizen@waste.dev', role: 'citizen', phone: '555-0200', rewardBalance: 0, active: true, fcmToken: null },
  ];

  for (const user of users) {
    if (user.uid.startsWith('REPLACE')) {
      console.log(`  ⚠ Skipping ${user.role} — set ${user.role.toUpperCase()}_UID in .env or update SEED_*_UID`);
      continue;
    }
    await db.collection('users').doc(user.uid).set({ ...user, createdAt: ts, updatedAt: ts });
    console.log(`  ✔ User: ${user.email} (${user.role})`);
  }

  console.log('\n✅ Seeding complete!');
  console.log('\nDev login credentials (create these accounts in Firebase Auth first):');
  console.log('  Admin:     admin@waste.dev     / Admin1234!');
  console.log('  Collector: collector@waste.dev / Collect1234!');
  console.log('  Citizen:   citizen@waste.dev   / Citizen1234!');
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});
