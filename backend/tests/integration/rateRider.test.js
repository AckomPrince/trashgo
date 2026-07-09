jest.mock('../../src/config/database');
jest.mock('../../src/services/matchingService');
jest.mock('../../src/services/pricingService');
jest.mock('../../src/services/rewardsService');
jest.mock('../../src/services/notificationService');
jest.mock('../../src/services/socketService');

let mockCurrentUser;
jest.mock('../../src/middleware/auth', () => ({
  auth: () => (req, res, next) => { req.user = mockCurrentUser; next(); },
  invalidateUserCache: jest.fn(),
}));

const request = require('supertest');
const db = require('../../src/config/database');
const { buildApp } = require('../helpers/testApp');
const ordersRouter = require('../../src/routes/orders');

const CUSTOMER = { id: 'cust-1', role: 'customer' };
const app = buildApp('/orders', ordersRouter);

function client(riderIdOrNull) {
  const calls = [];
  return {
    _calls: calls,
    query: jest.fn((text) => {
      calls.push(text);
      if (/UPDATE orders SET rider_rating/.test(text)) {
        return Promise.resolve({ rows: riderIdOrNull ? [{ rider_id: riderIdOrNull }] : [] });
      }
      return Promise.resolve({ rows: [] });
    }),
    release: jest.fn(),
  };
}

describe('rateRider (S2 #3)', () => {
  beforeEach(() => { mockCurrentUser = CUSTOMER; });

  test('rates a completed order and recomputes the rider average', async () => {
    const c = client('rider-1');
    db.getClient.mockResolvedValue(c);

    const res = await request(app).post('/orders/o1/rate-rider').send({ rating: 4, review: 'polite' });

    expect(res.status).toBe(200);
    const agg = c.query.mock.calls.find((x) => /UPDATE rider_profiles/.test(x[0]));
    expect(agg).toBeTruthy();
    expect(agg[1]).toEqual([4, 'rider-1']); // rating + rider id
    expect(c._calls).toContain('COMMIT');
  });

  test('rejects an out-of-range rating without opening a transaction', async () => {
    const res = await request(app).post('/orders/o1/rate-rider').send({ rating: 6 });
    expect(res.status).toBe(400);
    expect(db.getClient).not.toHaveBeenCalled();
  });

  test('404 + rollback when order is missing / not completed / already rated', async () => {
    const c = client(null);
    db.getClient.mockResolvedValue(c);

    const res = await request(app).post('/orders/o1/rate-rider').send({ rating: 5 });

    expect(res.status).toBe(404);
    expect(c._calls).toContain('ROLLBACK');
    expect(c._calls).not.toContain('COMMIT');
  });
});
