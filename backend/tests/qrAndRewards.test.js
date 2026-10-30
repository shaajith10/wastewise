const { generateQrToken, verifyQrToken } = require('../src/services/qrService');
const { awardRewardPoints } = require('../src/services/rewardService');

jest.mock('../src/config/firebase', () => {
  let balance = 0;
  const mockTx = {
    get: jest.fn().mockResolvedValue({ exists: false }),
    set: jest.fn(),
    update: jest.fn(),
  };
  const existingTx = {
    exists: true,
    data: () => ({ points: 50, transactionId: 'reward_req_001' }),
  };
  let callCount = 0;

  return {
    getDb: jest.fn(() => ({
      collection: jest.fn((name) => ({
        doc: jest.fn((id) => ({
          get: jest.fn().mockImplementation(() => {
            if (name === 'rewardTransactions') {
              callCount++;
              // Second call simulates already awarded
              return Promise.resolve(callCount > 1 ? existingTx : { exists: false });
            }
            return Promise.resolve({ exists: true, data: () => ({ rewardBalance: balance }) });
          }),
          set: jest.fn().mockResolvedValue({}),
          update: jest.fn().mockResolvedValue({}),
        })),
        where: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        get: jest.fn().mockResolvedValue({ empty: true, docs: [] }),
      })),
      runTransaction: jest.fn(async (fn) => fn({
        get: jest.fn().mockResolvedValue({ exists: true, data: () => ({ rewardBalance: balance }) }),
        set: jest.fn((ref, data) => { /* simulate set */ }),
        update: jest.fn((ref, data) => { if (data.rewardBalance !== undefined) balance = data.rewardBalance; }),
      })),
    })),
    admin: {
      firestore: {
        FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
        Timestamp: { now: () => ({ seconds: 1700000000 }) },
      },
    },
  };
});

describe('QR Service', () => {
  it('generates a valid JWT token', () => {
    const token = generateQrToken('req_001', 'citizen_uid_001');
    expect(typeof token).toBe('string');
    expect(token.split('.').length).toBe(3); // JWT format
  });

  it('verifies a valid token and returns payload', () => {
    const token = generateQrToken('req_001', 'citizen_uid_001');
    const payload = verifyQrToken(token);
    expect(payload.requestId).toBe('req_001');
    expect(payload.citizenUid).toBe('citizen_uid_001');
  });

  it('throws on tampered token', () => {
    const token = generateQrToken('req_001', 'citizen_uid_001') + 'tampered';
    expect(() => verifyQrToken(token)).toThrow();
  });

  it('generates unique nonces for each QR (prevents replay)', () => {
    const t1 = generateQrToken('req_001', 'uid_001');
    const t2 = generateQrToken('req_001', 'uid_001');
    const p1 = verifyQrToken(t1);
    const p2 = verifyQrToken(t2);
    expect(p1.nonce).not.toBe(p2.nonce);
  });
});

describe('Reward Service', () => {
  it('awards points for a new request', async () => {
    const result = await awardRewardPoints({
      citizenUid: 'citizen_uid_001',
      requestId: 'req_fresh',
      categoryId: 'cat_plastic',
      quantityKg: 2,
    });
    expect(result.points).toBeGreaterThan(0);
    expect(result.alreadyAwarded).toBe(false);
  });

  it('detects already-awarded transaction (idempotency)', async () => {
    const result = await awardRewardPoints({
      citizenUid: 'citizen_uid_001',
      requestId: 'req_001', // same requestId triggers second call which returns existingTx
      categoryId: 'cat_plastic',
      quantityKg: 2,
    });
    expect(result.alreadyAwarded).toBe(true);
    expect(result.points).toBe(50);
  });
});
