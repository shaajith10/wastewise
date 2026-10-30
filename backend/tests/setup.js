// Test setup: mock Firebase Admin SDK so tests run without real Firebase credentials
const admin = require('firebase-admin');

// Mock admin.apps to appear initialized
if (!admin.apps.length) {
  jest.mock('firebase-admin', () => {
    const mockTimestamp = { now: () => ({ seconds: 1700000000, nanoseconds: 0 }) };
    const mockFieldValue = {
      serverTimestamp: () => 'SERVER_TIMESTAMP',
      arrayUnion: (...items) => ({ _type: 'arrayUnion', items }),
    };
    const mockGeoPoint = class GeoPoint { constructor(lat, lng) { this.latitude = lat; this.longitude = lng; } };

    const mockDb = {
      collection: jest.fn().mockReturnThis(),
      doc: jest.fn().mockReturnThis(),
      add: jest.fn().mockResolvedValue({ id: 'mock_doc_id' }),
      set: jest.fn().mockResolvedValue({}),
      update: jest.fn().mockResolvedValue({}),
      get: jest.fn().mockResolvedValue({ exists: false, empty: true, data: () => ({}), docs: [] }),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      batch: jest.fn().mockReturnValue({
        update: jest.fn(),
        commit: jest.fn().mockResolvedValue({}),
      }),
      runTransaction: jest.fn(async (fn) => fn({
        get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ rewardBalance: 0 }) }),
        set: jest.fn(),
        update: jest.fn(),
      })),
    };

    return {
      apps: [{}],
      initializeApp: jest.fn(),
      credential: { cert: jest.fn() },
      auth: jest.fn(() => ({
        verifyIdToken: jest.fn(),
      })),
      firestore: jest.fn(() => mockDb),
      messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue('message_id') })),
    };
  });
}

// Mock auth token verifier for middleware tests
global.__mockAuthVerify = (token) => {
  const map = {
    'citizen_token': { uid: 'citizen_uid_001', email: 'citizen@waste.dev' },
    'collector_token': { uid: 'collector_uid_001', email: 'collector@waste.dev' },
    'admin_token': { uid: 'admin_uid_001', email: 'admin@waste.dev' },
  };
  if (map[token]) return map[token];
  throw new Error('Invalid token');
};

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_for_jest_only';
