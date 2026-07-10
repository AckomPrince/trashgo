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

const RIDER = { id: 'rider-1', role: 'rider' };
const app = buildApp('/orders', ordersRouter);

describe('declineOrder (S3 #4)', () => {
  beforeEach(() => { mockCurrentUser = RIDER; });

  test('declines an outstanding offer and bumps the decline counter', async () => {
    db.query.mockImplementation((text) => {
      if (/UPDATE order_offers SET status='declined'/.test(text)) return Promise.resolve({ rows: [{ id: 'off-1' }] });
      return Promise.resolve({ rows: [] });
    });

    const res = await request(app).post('/orders/o1/decline').send({});

    expect(res.status).toBe(200);
    const bumped = db.query.mock.calls.find((c) => /UPDATE rider_profiles SET declined_count/.test(c[0]));
    expect(bumped).toBeTruthy();
    expect(bumped[1]).toEqual(['rider-1']);
  });

  test('no-op (still 200) when there is no outstanding offer, counter not bumped', async () => {
    db.query.mockResolvedValue({ rows: [] }); // no offer updated

    const res = await request(app).post('/orders/o1/decline').send({});

    expect(res.status).toBe(200);
    const bumped = db.query.mock.calls.find((c) => /UPDATE rider_profiles SET declined_count/.test(c[0]));
    expect(bumped).toBeFalsy();
  });
});
