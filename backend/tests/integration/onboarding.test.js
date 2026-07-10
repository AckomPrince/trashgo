jest.mock('../../src/config/database');

let mockCurrentUser;
jest.mock('../../src/middleware/auth', () => ({
  auth: () => (req, res, next) => { req.user = mockCurrentUser; next(); },
  invalidateUserCache: jest.fn(),
}));

const request = require('supertest');
const db = require('../../src/config/database');
const { buildApp } = require('../helpers/testApp');
const ridersRouter = require('../../src/routes/riders');

const RIDER = { id: 'rider-1', role: 'rider' };
const app = buildApp('/riders', ridersRouter);

describe('rider onboarding & documents (S4 #5)', () => {
  beforeEach(() => { mockCurrentUser = RIDER; });

  test('uploads Ghana Card with number in one update', async () => {
    db.query.mockResolvedValue({ rows: [] });
    const res = await request(app).patch('/riders/documents')
      .send({ doc_type: 'ghana_card_url', url: 'https://cdn/card.jpg', ghana_card_number: 'GHA-123456789-0' });

    expect(res.status).toBe(200);
    const call = db.query.mock.calls[0];
    expect(call[0]).toMatch(/ghana_card_url=\$1, ghana_card_number=\$2/);
    expect(call[1]).toEqual(['https://cdn/card.jpg', 'GHA-123456789-0', 'rider-1']);
  });

  test('rejects an invalid doc_type', async () => {
    const res = await request(app).patch('/riders/documents').send({ doc_type: 'passport_url', url: 'x' });
    expect(res.status).toBe(400);
    expect(db.query).not.toHaveBeenCalled();
  });

  test('onboarding reports complete when all docs present', async () => {
    db.query.mockResolvedValue({ rows: [{
      ghana_card_number: 'GHA-1', ghana_card_url: 'a', vehicle_photo_url: 'b', license_url: 'c', id_document_url: 'd', status: 'approved',
    }] });
    const res = await request(app).get('/riders/onboarding');
    expect(res.status).toBe(200);
    expect(res.body.onboarding.complete).toBe(true);
    expect(res.body.onboarding.next_step).toBeNull();
  });

  test('onboarding points to the next missing step', async () => {
    db.query.mockResolvedValue({ rows: [{
      ghana_card_number: 'GHA-1', ghana_card_url: 'a', vehicle_photo_url: null, license_url: null, id_document_url: null, status: 'pending',
    }] });
    const res = await request(app).get('/riders/onboarding');
    expect(res.body.onboarding.complete).toBe(false);
    expect(res.body.onboarding.next_step).toBe('vehicle_photo');
  });
});
