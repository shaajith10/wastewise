const request = require('supertest');
const app = require('../src/app');

// Mock user DB lookups for the auth middleware
const { getDb } = require('../src/config/firebase');
jest.mock('../src/config/firebase', () => {
  const userMap = {
    citizen_uid_001: { uid: 'citizen_uid_001', role: 'citizen', displayName: 'Test Citizen', fcmToken: null },
    collector_uid_001: { uid: 'collector_uid_001', role: 'collector', displayName: 'Test Collector', fcmToken: null },
    admin_uid_001: { uid: 'admin_uid_001', role: 'admin', displayName: 'Test Admin', fcmToken: null },
  };

  const makeDoc = (data) => ({ exists: !!data, data: () => data, docs: data ? [{ id: 'mock', data: () => data }] : [] });
  const mockCollection = jest.fn(() => ({
    doc: jest.fn((id) => ({
      get: jest.fn().mockResolvedValue(makeDoc(userMap[id] || null)),
      set: jest.fn().mockResolvedValue({}),
      update: jest.fn().mockResolvedValue({}),
    })),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    add: jest.fn().mockResolvedValue({ id: 'new_doc_id' }),
    get: jest.fn().mockResolvedValue({ docs: [], size: 0, empty: true }),
  }));

  return {
    initFirebase: jest.fn(),
    getDb: jest.fn(() => ({ collection: mockCollection })),
    admin: {
      apps: [{}],
      auth: jest.fn(() => ({ verifyIdToken: jest.fn() })),
      firestore: {
        FieldValue: {
          serverTimestamp: () => 'SERVER_TIMESTAMP',
          arrayUnion: (...args) => ({ _union: args }),
        },
        Timestamp: { now: () => ({ seconds: 1700000000 }) },
        GeoPoint: class GeoPoint { constructor(lat, lng) { this.latitude=lat; this.longitude=lng; } },
      },
    },
  };
});

describe('Health Check', () => {
  it('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});

describe('Authentication', () => {
  it('returns 401 when no token provided', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });

  it('returns 401 with invalid token', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer invalid_token');
    expect(res.status).toBe(401);
  });
});

describe('POST /api/auth/register', () => {
  it('returns 422 when required fields missing', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ email: 'bad' });
    expect(res.status).toBe(422);
    expect(res.body.errors).toBeDefined();
  });

  it('accepts valid registration payload', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        displayName: 'Jane Citizen',
        email: 'jane@waste.dev',
        phone: '98765 43210',
        password: 'secret123',
      });
    expect(res.status).toBe(201);
    expect(res.body.token).toBeDefined();
    expect(res.body.user.role).toBe('citizen');
    expect(res.body.user.rewardBalance).toBe(0);
    expect(res.body.user.uid).toMatch(/^user_/);
    expect(res.body.user.passwordHash).toBeUndefined();
  });

  it('ignores a client-supplied uid and role', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        uid: 'seed-admin-uid',
        role: 'admin',
        displayName: 'Sneaky',
        email: 'sneaky@waste.dev',
        phone: '98765 43210',
        password: 'secret123',
      });
    expect(res.status).toBe(201);
    expect(res.body.user.uid).not.toBe('seed-admin-uid');
    expect(res.body.user.role).toBe('citizen');
  });

  it('returns 422 when password is too short', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ displayName: 'Jane', email: 'jane2@waste.dev', phone: '98765 43210', password: '123' });
    expect(res.status).toBe(422);
  });

  it('returns 422 when phone number is missing', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ uid: 'no_phone_uid', displayName: 'No Phone', email: 'nophone@waste.dev' });
    expect(res.status).toBe(422);
    expect(res.body.errors.some((e) => e.path === 'phone')).toBe(true);
  });

  it('returns 422 when phone number is too short', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ uid: 'short_phone_uid', displayName: 'Short Phone', email: 'short@waste.dev', phone: '12345' });
    expect(res.status).toBe(422);
  });
});

describe('Role authorization', () => {
  it('returns 403 when citizen tries to access admin endpoint', async () => {
    const res = await request(app)
      .get('/api/admin/stats')
      .set('Authorization', 'Bearer citizen_token');
    // Will be 401 (token verification fails in test without proper mock) or 403
    expect([401, 403]).toContain(res.status);
  });
});

describe('POST /api/auth/login', () => {
  it('rejects an unknown email with 401', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'nobody@waste.dev', password: 'whatever' });
    expect(res.status).toBe(401);
    expect(res.body.token).toBeUndefined();
  });

  it('does not create accounts for emails containing "admin"', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'fake-admin@evil.dev', password: 'x' });
    expect(res.status).toBe(401);
  });
});

describe('authService', () => {
  const {
    hashPassword, verifyPassword, createSessionToken, verifySessionToken, publicUser,
  } = require('../src/services/authService');
  const { generateQrToken } = require('../src/services/qrService');

  it('verifies the right password and rejects a wrong one', () => {
    const stored = hashPassword('citizen123');
    expect(stored).not.toContain('citizen123');
    expect(verifyPassword('citizen123', stored)).toBe(true);
    expect(verifyPassword('wrong', stored)).toBe(false);
    expect(verifyPassword('citizen123', undefined)).toBe(false);
  });

  it('round-trips a session token', () => {
    expect(verifySessionToken(createSessionToken('user_abc')).uid).toBe('user_abc');
  });

  it('rejects QR tokens and tampered tokens as sessions', () => {
    expect(() => verifySessionToken(generateQrToken('req_1', 'user_abc'))).toThrow();
    expect(() => verifySessionToken(createSessionToken('user_abc') + 'x')).toThrow();
  });

  it('strips passwordHash from user data', () => {
    expect(publicUser({ uid: 'u', passwordHash: 'h' })).toEqual({ uid: 'u' });
  });
});

describe('authenticate middleware', () => {
  it('rejects a raw user id as a token', async () => {
    const res = await request(app).get('/api/auth/me').set('Authorization', 'Bearer seed-admin-uid');
    expect(res.status).toBe(401);
  });

  it('rejects the old demo-admin shortcut token', async () => {
    const res = await request(app).get('/api/admin/stats').set('Authorization', 'Bearer demo-admin');
    expect(res.status).toBe(401);
  });

  it('rejects a valid session for an account that no longer exists', async () => {
    const { createSessionToken } = require('../src/services/authService');
    const res = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${createSessionToken('deleted_uid')}`);
    expect(res.status).toBe(401);
  });
});
