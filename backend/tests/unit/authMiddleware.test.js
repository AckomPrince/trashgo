jest.mock('../../src/config/database');

const jwt = require('jsonwebtoken');
const db = require('../../src/config/database');
const { auth, invalidateUserCache } = require('../../src/middleware/auth');

const SECRET = process.env.JWT_SECRET;
const sign = (payload, opts = {}) => jwt.sign(payload, SECRET, { expiresIn: '7d', ...opts });

function mockRes() {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn(() => res);
  return res;
}

describe('auth middleware', () => {
  test('rejects a request with no Authorization header', async () => {
    const req = { headers: {} };
    const res = mockRes();
    const next = jest.fn();
    await auth()(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: 'No token provided' }));
    expect(next).not.toHaveBeenCalled();
  });

  test('rejects a malformed token', async () => {
    const req = { headers: { authorization: 'Bearer not-a-jwt' } };
    const res = mockRes();
    const next = jest.fn();
    await auth()(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: 'Invalid token' }));
  });

  test('reports an expired token distinctly', async () => {
    const token = sign({ userId: 'exp-1', role: 'customer' }, { expiresIn: '-1s' });
    const req = { headers: { authorization: `Bearer ${token}` } };
    const res = mockRes();
    await auth()(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: 'Token expired' }));
  });

  test('rejects when the user no longer exists', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    const token = sign({ userId: 'gone-1', role: 'customer' });
    const req = { headers: { authorization: `Bearer ${token}` } };
    const res = mockRes();
    await auth()(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: 'User not found or inactive' }));
  });

  test('rejects an inactive (suspended) user', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ id: 'susp-1', role: 'customer', is_active: false }] });
    const token = sign({ userId: 'susp-1', role: 'customer' });
    const req = { headers: { authorization: `Bearer ${token}` } };
    const res = mockRes();
    await auth()(req, res, jest.fn());
    expect(res.status).toHaveBeenCalledWith(401);
  });

  test('accepts a valid active user and attaches req.user', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ id: 'ok-1', role: 'customer', is_active: true, full_name: 'A' }] });
    const token = sign({ userId: 'ok-1', role: 'customer' });
    const req = { headers: { authorization: `Bearer ${token}` } };
    const res = mockRes();
    const next = jest.fn();
    await auth()(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
    expect(req.user).toMatchObject({ id: 'ok-1', role: 'customer' });
  });

  test('enforces role restrictions with 403', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ id: 'cust-role', role: 'customer', is_active: true }] });
    const token = sign({ userId: 'cust-role', role: 'customer' });
    const req = { headers: { authorization: `Bearer ${token}` } };
    const res = mockRes();
    const next = jest.fn();
    await auth(['admin'])(req, res, next);
    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: 'Access denied' }));
    expect(next).not.toHaveBeenCalled();
  });

  test('caches the user so a second request skips the DB (60s TTL)', async () => {
    db.query.mockResolvedValue({ rows: [{ id: 'cache-1', role: 'rider', is_active: true }] });
    const token = sign({ userId: 'cache-1', role: 'rider' });
    const make = () => ({ headers: { authorization: `Bearer ${token}` } });

    invalidateUserCache('cache-1'); // ensure clean slate
    await auth()(make(), mockRes(), jest.fn());
    await auth()(make(), mockRes(), jest.fn());

    expect(db.query).toHaveBeenCalledTimes(1); // second call served from cache
  });
});
