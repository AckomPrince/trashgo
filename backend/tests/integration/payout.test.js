process.env.PAYMENTS_MOCK = 'true';

jest.mock('../../src/config/database');
jest.mock('../../src/services/notificationService');
jest.mock('../../src/services/socketService');

let mockCurrentUser;
jest.mock('../../src/middleware/auth', () => ({
  auth: () => (req, res, next) => { req.user = mockCurrentUser; next(); },
  invalidateUserCache: jest.fn(),
}));

const request = require('supertest');
const crypto = require('crypto');
const db = require('../../src/config/database');
const payout = require('../../src/controllers/payoutController');
const { buildApp } = require('../helpers/testApp');
const ridersRouter = require('../../src/routes/riders');

const RIDER = { id: 'rider-1', role: 'rider' };
const app = buildApp('/riders', ridersRouter);

beforeEach(() => {
  mockCurrentUser = RIDER;
  process.env.PAYMENTS_MOCK = 'true';
  process.env.MIN_PAYOUT = '5';
  db.query.mockResolvedValue({ rows: [] });
});

function scripted(map) {
  const calls = [];
  const client = {
    _calls: calls,
    query: jest.fn((text) => {
      calls.push(text);
      for (const [re, val] of map) if (re.test(text)) return Promise.resolve(val);
      return Promise.resolve({ rows: [] });
    }),
    release: jest.fn(),
  };
  return client;
}

describe('payouts — recipients & withdrawal (P #8)', () => {
  test('saves a MoMo recipient (mock Paystack)', async () => {
    const client = scripted([[/INSERT INTO payout_recipients/, { rows: [{ id: 'rec-1', type: 'mobile_money', is_default: true }] }]]);
    db.getClient.mockResolvedValue(client);

    const res = await request(app).post('/riders/payout-recipients')
      .send({ type: 'mobile_money', provider: 'MTN', account_number: '0241234602', account_name: 'Kofi', is_default: true });

    expect(res.status).toBe(201);
    expect(res.body.recipient.id).toBe('rec-1');
    expect(client._calls).toContain('COMMIT');
  });

  test('withdraws: debits wallet, records payout, initiates transfer', async () => {
    const client = scripted([
      [/SELECT balance FROM rider_wallets/, { rows: [{ balance: '8.00' }] }],
      [/FROM payout_recipients/, { rows: [{ id: 'rec-1', paystack_recipient_code: 'MOCK-RCP' }] }],
      [/INSERT INTO payouts/, { rows: [{ id: 'po-1', amount: '5.00', status: 'pending', reference: 'PO-x' }] }],
    ]);
    db.getClient.mockResolvedValue(client);

    const res = await request(app).post('/riders/payout').send({ amount: 5 });

    expect(res.status).toBe(201);
    expect(res.body.payout.status).toBe('processing');
    expect(res.body.payout.paystack_transfer_code).toMatch(/MOCK-TRF/);
    expect(client._calls.find((c) => /SET balance=balance-\$1/.test(c))).toBeTruthy();
    expect(client._calls).toContain('COMMIT');
  });

  test('rejects withdrawal above wallet balance', async () => {
    const client = scripted([[/SELECT balance FROM rider_wallets/, { rows: [{ balance: '2.00' }] }]]);
    db.getClient.mockResolvedValue(client);
    const res = await request(app).post('/riders/payout').send({ amount: 5 });
    expect(res.status).toBe(400);
    expect(client._calls).toContain('ROLLBACK');
  });

  test('rejects withdrawal below the minimum without touching the DB', async () => {
    const res = await request(app).post('/riders/payout').send({ amount: 1 }); // < MIN_PAYOUT 5
    expect(res.status).toBe(400);
    expect(db.getClient).not.toHaveBeenCalled();
  });
});

describe('transfer webhook (P #8)', () => {
  const sign = (body) => crypto.createHmac('sha512', process.env.PAYSTACK_SECRET_KEY).update(body).digest('hex');
  const resMock = () => {
    const r = {};
    r.statusCode = null;
    r.sendStatus = jest.fn((s) => { r.statusCode = s; return r; });
    r.status = jest.fn((s) => { r.statusCode = s; return r; });
    r.json = jest.fn(() => r);
    return r;
  };

  test('settles a payout to paid on transfer.success', async () => {
    db.query.mockImplementation((t) =>
      /SELECT \* FROM payouts/.test(t)
        ? Promise.resolve({ rows: [{ id: 'po-1', rider_id: 'rider-1', amount: '5.00', status: 'processing' }] })
        : Promise.resolve({ rows: [] }));

    const body = JSON.stringify({ event: 'transfer.success', data: { transfer_code: 'MOCK-TRF-1' } });
    const req = { body: Buffer.from(body), headers: { 'x-paystack-signature': sign(body) } };
    const res = resMock();
    await payout.transferWebhook(req, res, (e) => { throw e; });

    expect(res.statusCode).toBe(200);
    expect(db.query.mock.calls.find((c) => /UPDATE payouts SET status='paid'/.test(c[0]))).toBeTruthy();
  });

  test('rejects a bad signature', async () => {
    const body = JSON.stringify({ event: 'transfer.success', data: { transfer_code: 'x' } });
    const req = { body: Buffer.from(body), headers: { 'x-paystack-signature': 'bad' } };
    const res = resMock();
    await payout.transferWebhook(req, res, (e) => { throw e; });
    expect(res.statusCode).toBe(400);
  });

  test('refunds the wallet on transfer.failed', async () => {
    db.query.mockImplementation((t) =>
      /SELECT \* FROM payouts/.test(t)
        ? Promise.resolve({ rows: [{ id: 'po-1', rider_id: 'rider-1', amount: '5.00', status: 'processing' }] })
        : Promise.resolve({ rows: [] }));

    const body = JSON.stringify({ event: 'transfer.failed', data: { transfer_code: 'MOCK-TRF-1' } });
    const req = { body: Buffer.from(body), headers: { 'x-paystack-signature': sign(body) } };
    const res = resMock();
    await payout.transferWebhook(req, res, (e) => { throw e; });

    expect(res.statusCode).toBe(200);
    expect(db.query.mock.calls.find((c) => /SET balance=balance\+\$1/.test(c[0]))).toBeTruthy();
  });
});
