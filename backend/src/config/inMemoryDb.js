const fs = require('fs');
const path = require('path');

/**
 * Smart Persistent In-Memory Database Engine
 * Features:
 * 1. Automatically persists to backend/data/database.json on disk.
 * 2. Reloads on server startup so no data is lost across restarts.
 * 3. Gracefully handles Firebase serverTimestamp & Timestamp transforms to ISO strings.
 * 4. Provides full Firestore-like API (collection, doc, set, update, get, where, orderBy, limit, runTransaction).
 */

const DATA_DIR = path.resolve(__dirname, '../../data');
const DATA_FILE = path.join(DATA_DIR, 'database.json');

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function cleanData(val) {
  if (val === null || val === undefined) return val;
  if (val instanceof Date) return val.toISOString();
  if (typeof val === 'object') {
    // Check if it's a Firestore FieldValue serverTimestamp transform
    if (val.constructor && val.constructor.name === 'ServerTimestampTransform') {
      return new Date().toISOString();
    }
    // Check if it's a Firestore Timestamp with toDate or seconds
    if (typeof val.toDate === 'function') {
      return val.toDate().toISOString();
    }
    if (val.seconds !== undefined) {
      return new Date(val.seconds * 1000).toISOString();
    }
    if (Array.isArray(val)) {
      return val.map(cleanData);
    }
    const res = {};
    for (const [k, v] of Object.entries(val)) {
      res[k] = cleanData(v);
    }
    return res;
  }
  return val;
}

class InMemoryDocRef {
  constructor(collection, id) {
    this.collection = collection;
    this.id = id;
  }

  async get() {
    const data = this.collection.store.get(this.id);
    return {
      id: this.id,
      exists: !!data,
      data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined),
    };
  }

  async set(data, options = {}) {
    const existing = this.collection.store.get(this.id) || {};
    const sanitized = cleanData(data);
    const newData = options.merge ? { ...existing, ...sanitized } : { ...sanitized };
    newData.id = this.id;
    this.collection.store.set(this.id, newData);
    this.collection.db.saveToDisk();
    return {};
  }

  async update(data) {
    const existing = this.collection.store.get(this.id) || {};
    const sanitized = cleanData(data);
    for (const [key, value] of Object.entries(sanitized)) {
      if (value && typeof value === 'object' && value._type === 'arrayUnion') {
        const arr = Array.isArray(existing[key]) ? existing[key] : [];
        existing[key] = [...arr, ...cleanData(value.items)];
      } else {
        existing[key] = value;
      }
    }
    this.collection.store.set(this.id, existing);
    this.collection.db.saveToDisk();
    return {};
  }

  async delete() {
    this.collection.store.delete(this.id);
    this.collection.db.saveToDisk();
    return {};
  }
}

class InMemoryCollectionRef {
  constructor(db, name, initialData = []) {
    this.db = db;
    this.name = name;
    this.store = new Map();
    this.whereFilters = [];
    this.limitCount = null;

    for (const item of initialData) {
      if (item.id) {
        this.store.set(item.id, cleanData(item));
      }
    }
  }

  doc(id) {
    const docId = id || `doc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return new InMemoryDocRef(this, docId);
  }

  where(field, op, value) {
    const filtered = new InMemoryCollectionRef(this.db, this.name);
    filtered.store = new Map(this.store);
    filtered.whereFilters = [...this.whereFilters, { field, op, value }];
    filtered.limitCount = this.limitCount;
    return filtered;
  }

  orderBy(field, direction = 'asc') {
    return this;
  }

  limit(count) {
    this.limitCount = count;
    return this;
  }

  async get() {
    let docsData = Array.from(this.store.values());

    for (const filter of this.whereFilters) {
      const { field, op, value } = filter;
      docsData = docsData.filter((d) => {
        if (op === '==') return d[field] === value;
        if (op === '!=') return d[field] !== value;
        if (op === '>=') return d[field] >= value;
        if (op === '<=') return d[field] <= value;
        return true;
      });
    }

    if (this.limitCount && docsData.length > this.limitCount) {
      docsData = docsData.slice(0, this.limitCount);
    }

    const docs = docsData.map((d) => ({
      id: d.id,
      exists: true,
      data: () => JSON.parse(JSON.stringify(d)),
    }));

    return {
      docs,
      empty: docs.length === 0,
      size: docs.length,
    };
  }

  async add(data) {
    const id = `doc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const docRef = this.doc(id);
    await docRef.set(data);
    return docRef;
  }
}

class InMemoryDb {
  constructor() {
    this.collections = new Map();
    this._saveTimeout = null;
    this._loadOrSeed();
  }

  _loadOrSeed() {
    ensureDataDir();
    if (fs.existsSync(DATA_FILE)) {
      try {
        const raw = fs.readFileSync(DATA_FILE, 'utf8');
        const parsed = JSON.parse(raw);
        for (const [colName, items] of Object.entries(parsed)) {
          this.collections.set(colName, new InMemoryCollectionRef(this, colName, items));
        }
        console.log(`[InMemoryDb] Successfully restored persistent database from ${DATA_FILE}`);
        return;
      } catch (err) {
        console.warn(`[InMemoryDb] Error reading ${DATA_FILE}, reseeding:`, err.message);
      }
    }
    this._seedInitialData();
    this.saveToDiskNow();
  }

  _seedInitialData() {
    // Seed Users
    const users = [
      {
        id: 'seed-citizen-uid',
        uid: 'seed-citizen-uid',
        displayName: 'Demo Citizen',
        email: 'citizen@waste.dev',
        role: 'citizen',
        rewardBalance: 350,
        active: true,
        createdAt: new Date().toISOString(),
      },
      {
        id: 'seed-collector-uid',
        uid: 'seed-collector-uid',
        displayName: 'Authorized Collector',
        email: 'collector@waste.dev',
        role: 'collector',
        vehicleNumber: 'WM-8849',
        active: true,
        createdAt: new Date().toISOString(),
      },
      {
        id: 'seed-admin-uid',
        uid: 'seed-admin-uid',
        displayName: 'Admin Manager',
        email: 'admin@waste.dev',
        role: 'admin',
        active: true,
        createdAt: new Date().toISOString(),
      },
    ];
    this.collections.set('users', new InMemoryCollectionRef(this, 'users', users));

    // Seed Categories with Real-World Recycling Points per KG
    const categories = [
      { id: 'cat_plastic', name: 'Plastic', pointsPerKg: 50, description: 'PET bottles, milk containers, HDPE packaging' },
      { id: 'cat_paper', name: 'Paper & Cardboard', pointsPerKg: 30, description: 'Newspapers, boxes, cartons, magazines' },
      { id: 'cat_metal', name: 'Metals & Aluminum', pointsPerKg: 80, description: 'Aluminum beverage cans, tin containers, scrap metal' },
      { id: 'cat_glass', name: 'Glass Bottles', pointsPerKg: 40, description: 'Bottles, beverage jars, glassware' },
      { id: 'cat_ewaste', name: 'E-Waste', pointsPerKg: 150, description: 'Old electronics, chargers, batteries, gadgets' },
      { id: 'cat_organic', name: 'Organic Waste', pointsPerKg: 15, description: 'Food scraps, compostable kitchen waste' },
    ];
    this.collections.set('wasteCategories', new InMemoryCollectionRef(this, 'wasteCategories', categories));

    // Seed Reward Rules
    const rewardRules = [
      { id: 'rule_plastic', categoryId: 'cat_plastic', categoryName: 'Plastic', pointsPerKg: 50 },
      { id: 'rule_paper', categoryId: 'cat_paper', categoryName: 'Paper & Cardboard', pointsPerKg: 30 },
      { id: 'rule_metal', categoryId: 'cat_metal', categoryName: 'Metals & Aluminum', pointsPerKg: 80 },
      { id: 'rule_glass', categoryId: 'cat_glass', categoryName: 'Glass Bottles', pointsPerKg: 40 },
      { id: 'rule_ewaste', categoryId: 'cat_ewaste', categoryName: 'E-Waste', pointsPerKg: 150 },
      { id: 'rule_organic', categoryId: 'cat_organic', categoryName: 'Organic Waste', pointsPerKg: 15 },
    ];
    this.collections.set('rewardRules', new InMemoryCollectionRef(this, 'rewardRules', rewardRules));

    // Seed Pickup Requests
    const pickupRequests = [
      {
        id: 'req_001',
        citizenUid: 'seed-citizen-uid',
        citizenName: 'Demo Citizen',
        citizenEmail: 'citizen@waste.dev',
        categoryId: 'cat_plastic',
        categoryName: 'Plastic',
        quantityKg: 4.5,
        description: 'Clean plastic bottles and packaging containers',
        address: '123 Eco Green Street, Block B, Cityville',
        latitude: 12.9716,
        longitude: 77.5946,
        status: 'Pending',
        qrToken: 'QR-DEMO-REQ-001',
        collectorUid: null,
        collectorName: null,
        qrVerified: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: 'req_002',
        citizenUid: 'seed-citizen-uid',
        citizenName: 'Demo Citizen',
        citizenEmail: 'citizen@waste.dev',
        categoryId: 'cat_paper',
        categoryName: 'Paper & Cardboard',
        quantityKg: 10.0,
        description: 'Flattened shipping boxes and newspapers',
        address: '45 Green Park Avenue, Cityville',
        latitude: 12.9750,
        longitude: 77.5980,
        status: 'Assigned',
        qrToken: 'QR-DEMO-REQ-002',
        collectorUid: 'seed-collector-uid',
        collectorName: 'Authorized Collector',
        qrVerified: false,
        createdAt: new Date(Date.now() - 3600000).toISOString(),
        updatedAt: new Date(Date.now() - 3600000).toISOString(),
      },
      {
        id: 'req_003',
        citizenUid: 'seed-citizen-uid',
        citizenName: 'Demo Citizen',
        citizenEmail: 'citizen@waste.dev',
        categoryId: 'cat_metal',
        categoryName: 'Metals & Aluminum',
        quantityKg: 3.0,
        description: 'Empty beverage cans and tin boxes',
        address: '77 Sustainability Boulevard, Cityville',
        latitude: 12.9800,
        longitude: 77.6000,
        status: 'Completed',
        qrToken: 'QR-DEMO-REQ-003',
        collectorUid: 'seed-collector-uid',
        collectorName: 'Authorized Collector',
        qrVerified: true,
        createdAt: new Date(Date.now() - 86400000).toISOString(),
        updatedAt: new Date(Date.now() - 86400000).toISOString(),
      },
    ];
    this.collections.set('pickupRequests', new InMemoryCollectionRef(this, 'pickupRequests', pickupRequests));

    // Seed Reward Transactions
    const rewardTransactions = [
      {
        id: 'reward_req_003',
        transactionId: 'reward_req_003',
        citizenUid: 'seed-citizen-uid',
        requestId: 'req_003',
        categoryName: 'Metals & Aluminum',
        quantityKg: 3.0,
        points: 240,
        pointsPerKg: 80,
        type: 'earned',
        description: 'Earned 240 points for recycling 3.0 kg of Metals & Aluminum',
        createdAt: new Date(Date.now() - 86400000).toISOString(),
      },
      {
        id: 'tx_seed_bonus',
        transactionId: 'tx_seed_bonus',
        citizenUid: 'seed-citizen-uid',
        requestId: 'welcome_bonus',
        categoryName: 'Eco Starter Bonus',
        quantityKg: 0,
        points: 110,
        type: 'earned',
        description: 'Welcome bonus for joining WasteWise Community',
        createdAt: new Date(Date.now() - 172800000).toISOString(),
      },
    ];
    this.collections.set('rewardTransactions', new InMemoryCollectionRef(this, 'rewardTransactions', rewardTransactions));

    // Seed User Vouchers
    const userVouchers = [
      {
        id: 'vouch_001',
        citizenUid: 'seed-citizen-uid',
        voucherId: 'v1',
        title: '$5 Grocery Store Discount',
        cost: 150,
        category: 'Shopping',
        code: 'ECO-GROC-8921',
        status: 'Active',
        expiresAt: new Date(Date.now() + 25 * 86400000).toISOString(),
        createdAt: new Date(Date.now() - 43200000).toISOString(),
      },
    ];
    this.collections.set('userVouchers', new InMemoryCollectionRef(this, 'userVouchers', userVouchers));

    // Seed Notifications
    const notifications = [
      {
        id: 'notif_001',
        toUid: 'seed-citizen-uid',
        title: 'Task Assigned',
        body: 'Collector Authorized Collector has been assigned to pickup req_002.',
        type: 'task_assigned',
        read: false,
        createdAt: new Date().toISOString(),
      },
      {
        id: 'notif_002',
        toUid: 'seed-citizen-uid',
        title: '♻️ Points Credited!',
        body: 'You earned 240 reward points for your verified Metals recycling.',
        type: 'verified',
        read: true,
        createdAt: new Date(Date.now() - 86400000).toISOString(),
      },
    ];
    this.collections.set('notifications', new InMemoryCollectionRef(this, 'notifications', notifications));
  }

  saveToDisk() {
    if (this._saveTimeout) clearTimeout(this._saveTimeout);
    this._saveTimeout = setTimeout(() => this.saveToDiskNow(), 200);
  }

  saveToDiskNow() {
    try {
      ensureDataDir();
      const exportData = {};
      for (const [colName, colRef] of this.collections.entries()) {
        exportData[colName] = Array.from(colRef.store.values());
      }
      fs.writeFileSync(DATA_FILE, JSON.stringify(exportData, null, 2), 'utf8');
    } catch (err) {
      console.error('[InMemoryDb] Save to disk error:', err.message);
    }
  }

  collection(name) {
    if (!this.collections.has(name)) {
      this.collections.set(name, new InMemoryCollectionRef(this, name));
    }
    return this.collections.get(name);
  }

  async runTransaction(updateFn) {
    const transaction = {
      get: async (docRef) => await docRef.get(),
      set: async (docRef, data, options) => await docRef.set(data, options),
      update: async (docRef, data) => await docRef.update(data),
      delete: async (docRef) => await docRef.delete(),
    };
    return await updateFn(transaction);
  }
}

const inMemoryDbInstance = new InMemoryDb();

module.exports = {
  inMemoryDbInstance,
};
