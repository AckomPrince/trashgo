jest.mock('../../src/config/database');
jest.mock('../../src/services/matchingService');
jest.mock('../../src/services/pricingService');
jest.mock('../../src/services/rewardsService');
jest.mock('../../src/services/notificationService');
jest.mock('../../src/services/socketService');

// Auth mock: inject a configurable rider user, bypassing JWT/DB.
let mockCurrentUser;
jest.mock('../../src/middleware/auth', () => ({
  auth: () => (req, res, next) => { req.user = mockCurrentUser; next(); },
  invalidateUserCache: jest.fn(),
}));

const request = require('supertest');
const db = require('../../src/config/database');
const { calculatePoints } = require('../../src/services/pricingService');
const { awardPoints } = require('../../src/services/rewardsService');
const { buildApp } = require('../helpers/testApp');
const ordersRouter = require('../../src/routes/orders');

const RIDER = { id: 'rider-1', role: 'rider' };
const app = buildApp('/orders', ordersRouter);

function scriptedClient(order, { earningInserted = true } = {}) {
  const calls = [];
  const client = {
    query: jest.fn((text) => {
      calls.push(text);
      if (/SELECT \* FROM orders/.test(text)) return Promise.resolve({ rows: order ? [order] : [] });
      if (/INSERT INTO rider_earnings/.test(text)) return Promise.resolve({ rows: earningInserted ? [{ id: 'e1' }] : [] });
      return Promise.resolve({ rows: [] });
    }),
    release: jest.fn(),
    _calls: calls,
  };
  return client;
}

describe('completeOrder — wallet accrual (S1 #2)', () => {
  beforeEach(() => {
    mockCurrentUser = RIDER;
    calculatePoints.mockReturnValue(70);
    awardPoints.mockResolvedValue(70);
  });

  test('credits the wallet with net earning inside the transaction and awards points', async () => {
    const order = { id: 'o1', rider_id: 'rider-1', customer_id: 'cust-1', status: 'in_progress', final_price: '10.00', waste_type: 'general', waste_size: 'medium' };
    const client = scriptedClient(order);
    db.getClient.mockResolvedValue(client);

    const res = await request(app).patch('/orders/o1/complete').send({});

    expect(res.status).toBe(200);
    expect(res.body.rider_net_earning).toBe(8); // 10 - 20%
    expect(res.body.points_awarded).toBe(70);

    const walletInsert = client._calls.find((c) => /INSERT INTO rider_wallets/.test(c));
    expect(walletInsert).toBeTruthy();
    // net (8) passed as the credit amount
    const walletCall = client.query.mock.calls.find((c) => /INSERT INTO rider_wallets/.test(c[0]));
    expect(walletCall[1]).toEqual(['rider-1', 8]);

    expect(client._calls).toContain('COMMIT');
    expect(client._calls).not.toContain('ROLLBACK');
    expect(awardPoints).toHaveBeenCalledWith('cust-1', 'o1', 70);
  });

  test('does NOT credit the wallet again when earnings row already exists (idempotent)', async () => {
    const order = { id: 'o1', rider_id: 'rider-1', customer_id: 'cust-1', status: 'in_progress', final_price: '10.00', waste_type: 'general', waste_size: 'medium' };
    const client = scriptedClient(order, { earningInserted: false }); // ON CONFLICT -> no row
    db.getClient.mockResolvedValue(client);

    const res = await request(app).patch('/orders/o1/complete').send({});

    expect(res.status).toBe(200);
    const walletInsert = client._calls.find((c) => /INSERT INTO rider_wallets/.test(c));
    expect(walletInsert).toBeFalsy(); // wallet not touched on retry
    expect(client._calls).toContain('COMMIT');
  });

  test('rolls back and 404s when the order is not in progress', async () => {
    const client = scriptedClient(null); // SELECT returns no row
    db.getClient.mockResolvedValue(client);

    const res = await request(app).patch('/orders/o1/complete').send({});

    expect(res.status).toBe(404);
    expect(client._calls).toContain('ROLLBACK');
    expect(client._calls).not.toContain('COMMIT');
    expect(awardPoints).not.toHaveBeenCalled();
  });
});
