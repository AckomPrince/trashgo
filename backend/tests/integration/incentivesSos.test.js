jest.mock('../../src/config/database');
jest.mock('../../src/services/notificationService');

let mockCurrentUser;
jest.mock('../../src/middleware/auth', () => ({
  auth: () => (req, res, next) => { req.user = mockCurrentUser; next(); },
  invalidateUserCache: jest.fn(),
}));

const request = require('supertest');
const db = require('../../src/config/database');
const { notify } = require('../../src/services/notificationService');
const { buildApp } = require('../helpers/testApp');
const ridersRouter = require('../../src/routes/riders');

const RIDER = { id: 'rider-1', role: 'rider' };
const app = buildApp('/riders', ridersRouter);

describe('rider engagement & safety (S6 #7)', () => {
  beforeEach(() => { mockCurrentUser = RIDER; });

  test('incentives include computed progress + achieved flags', async () => {
    db.query.mockImplementation((text) => {
      if (/FROM rider_incentives/.test(text)) {
        return Promise.resolve({ rows: [
          { id: 'i1', type: 'volume', title: 'Weekly Hustler', target: 10, period: 'weekly', reward_cash: '20.00', reward_points: 0, status: 'active' },
          { id: 'i2', type: 'streak', title: 'Daily Triple', target: 3, period: 'daily', reward_cash: '0', reward_points: 100, status: 'active' },
        ] });
      }
      if (/FROM rider_earnings/.test(text)) return Promise.resolve({ rows: [{ today: '1', week: '5', month: '12' }] });
      return Promise.resolve({ rows: [] });
    });

    const res = await request(app).get('/riders/incentives');

    expect(res.status).toBe(200);
    const weekly = res.body.incentives.find((i) => i.id === 'i1');
    const daily = res.body.incentives.find((i) => i.id === 'i2');
    expect(weekly.progress).toBe(5);        // week count
    expect(weekly.achieved).toBe(false);    // 5 < 10
    expect(daily.progress).toBe(1);         // today count
    expect(daily.achieved).toBe(false);     // 1 < 3
  });

  test('SOS logs an event and alerts every active admin', async () => {
    db.query.mockImplementation((text) => {
      if (/INSERT INTO rider_sos_events/.test(text)) return Promise.resolve({ rows: [{ id: 'sos-1', created_at: 'now' }] });
      if (/role='admin'/.test(text)) return Promise.resolve({ rows: [{ id: 'admin-1' }, { id: 'admin-2' }] });
      return Promise.resolve({ rows: [] });
    });

    const res = await request(app).post('/riders/sos').send({ lat: 5.6, lng: -0.18, note: 'help' });

    expect(res.status).toBe(201);
    expect(res.body.sos_id).toBe('sos-1');
    expect(notify).toHaveBeenCalledTimes(2); // both admins
    expect(notify).toHaveBeenCalledWith('admin-1', expect.objectContaining({ data: expect.objectContaining({ type: 'rider_sos' }) }));
  });
});
