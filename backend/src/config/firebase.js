require('dotenv').config();
const admin = require('firebase-admin');
const { inMemoryDbInstance } = require('./inMemoryDb');

let db;
let auth;

function initFirebase() {
  if (admin.apps.length > 0) return; // Already initialized

  if (process.env.NODE_ENV === 'test') {
    // In test mode, use a mock — actual mock is set up in tests/setup.js
    return;
  }

  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!serviceAccountPath) {
    console.warn('[Firebase] FIREBASE_SERVICE_ACCOUNT_PATH not set — running with in-memory database');
    return;
  }

  let serviceAccount;
  try {
    serviceAccount = require(require('path').resolve(serviceAccountPath));
  } catch (err) {
    console.warn(`[Firebase] Could not load service account from ${serviceAccountPath}: ${err.message}`);
    console.warn('[Firebase] Running with standalone in-memory database mode.');
    return;
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID,
  });

  console.log('[Firebase] Admin SDK initialized');
}

function getDb() {
  if (!db) {
    if (admin.apps.length === 0) {
      return inMemoryDbInstance;
    }
    db = admin.firestore();
  }
  return db;
}

function getAuth() {
  if (!auth) {
    if (admin.apps.length === 0) {
      return {
        verifyIdToken: async (token) => ({ uid: token, email: 'demo@waste.dev' }),
      };
    }
    auth = admin.auth();
  }
  return auth;
}

module.exports = { initFirebase, getDb, getAuth, admin };
