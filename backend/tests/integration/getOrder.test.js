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

const baseOrder = (status) => ({
  id: 'o1', status, customer_id: 'cust-1', rider_id: 'rider-1',
  pickup_lat: '5.6037', pickup_lng: '-0.1870',
  customer_phone: '+233241234602', rider_phone: '+233209876543',
});

describe('getOrder — maps link + contact masking (S5 #6)', () => {
  beforeEach(() => { mockCurrentUser = CUSTOMER; });

  test('active order exposes full phones + maps link', async () => {
    db.query.mockResolvedValue({ rows: [baseOrder('accepted')] });
    const res = await request(app).get('/orders/o1');
    expect(res.status).toBe(200);
    expect(res.body.order.maps_link).toContain('destination=5.6037,-0.1870');
    expect(res.body.order.customer_phone).toBe('+233241234602'); // not masked
    expect(res.body.order.rider_phone).toBe('+233209876543');
  });

  test('completed order masks both phones but keeps maps link', async () => {
    db.query.mockResolvedValue({ rows: [baseOrder('completed')] });
    const res = await request(app).get('/orders/o1');
    expect(res.status).toBe(200);
    expect(res.body.order.maps_link).toContain('destination=');
    expect(res.body.order.customer_phone).toMatch(/^\*+602$/); // masked, last 3 kept
    expect(res.body.order.rider_phone).toMatch(/^\*+543$/);
  });
});
