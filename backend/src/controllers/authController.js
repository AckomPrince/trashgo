const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const crypto  = require('crypto');
const db      = require('../config/database');
const { asyncHandler } = require('../middleware/errorHandler');

// ── helpers ───────────────────────────────────────────────────
const REFRESH_EXPIRES_MS = () => {
  const days = parseInt(process.env.JWT_REFRESH_EXPIRES_DAYS || '30', 10);
  return days * 24 * 60 * 60 * 1000;
};

const signToken = (userId, role) =>
  jwt.sign({ userId, role }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });

const signRefresh = (userId) =>
  jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  });

/** SHA-256 hex of the raw refresh JWT — what we store in the DB. */
const hashToken = (raw) =>
  crypto.createHash('sha256').update(raw).digest('hex');

/** Persist a new refresh token and return the raw JWT. */
async function issueRefreshToken(userId, client) {
  const raw = signRefresh(userId);
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_MS());
  const q = 'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1,$2,$3)';
  if (client) {
    await client.query(q, [userId, hashToken(raw), expiresAt]);
  } else {
    await db.query(q, [userId, hashToken(raw), expiresAt]);
  }
  return raw;
}

const safe = (user) => {
  const { password_hash, ...rest } = user;
  return rest;
};

// ── register customer ─────────────────────────────────────────
exports.registerCustomer = asyncHandler(async (req, res) => {
  const { full_name, email, phone, password } = req.body;
  if (!full_name || !email || !phone || !password)
    return res.status(400).json({ success: false, error: 'All fields required' });

  // FIX: lowercase email before duplicate check to avoid case-sensitivity bypass
  // FIX: scope duplicate check to the same role so a customer and rider can share contact info
  const normalEmail = email.toLowerCase().trim();

  const exists = await db.query(
    'SELECT id FROM users WHERE role=$3 AND (LOWER(email)=$1 OR phone=$2)',
    [normalEmail, phone, 'customer']
  );
  if (exists.rows.length)
    return res.status(409).json({ success: false, error: 'Email or phone already registered for a customer account' });

  const hash = await bcrypt.hash(password, 12);
  const { rows } = await db.query(
    `INSERT INTO users (full_name, email, phone, password_hash, role)
     VALUES ($1,$2,$3,$4,'customer') RETURNING *`,
    [full_name, normalEmail, phone, hash]
  );

  // create points wallet
  await db.query(
    'INSERT INTO points_wallets (user_id) VALUES ($1) ON CONFLICT DO NOTHING',
    [rows[0].id]
  );

  const token   = signToken(rows[0].id, 'customer');
  const refresh = await issueRefreshToken(rows[0].id);
  res.status(201).json({ success: true, token, refresh_token: refresh, user: safe(rows[0]) });
});

// ── register rider ────────────────────────────────────────────
exports.registerRider = asyncHandler(async (req, res) => {
  const { full_name, email, phone, password, vehicle_type, vehicle_plate } = req.body;
  if (!full_name || !email || !phone || !password)
    return res.status(400).json({ success: false, error: 'All fields required' });

  const normalEmail = email.toLowerCase().trim();

  // FIX: lowercase email in duplicate check
  // FIX: scope duplicate check to the same role so a customer and rider can share contact info
  const exists = await db.query(
    'SELECT id FROM users WHERE role=$3 AND (LOWER(email)=$1 OR phone=$2)',
    [normalEmail, phone, 'rider']
  );
  if (exists.rows.length)
    return res.status(409).json({ success: false, error: 'Email or phone already registered for a rider account' });

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const hash = await bcrypt.hash(password, 12);
    const { rows: [user] } = await client.query(
      `INSERT INTO users (full_name, email, phone, password_hash, role)
       VALUES ($1,$2,$3,$4,'rider') RETURNING *`,
      [full_name, normalEmail, phone, hash]
    );

    await client.query(
      `INSERT INTO rider_profiles (user_id, vehicle_type, vehicle_plate)
       VALUES ($1,$2,$3)`,
      [user.id, vehicle_type || null, vehicle_plate || null]
    );

    const token   = signToken(user.id, 'rider');
    const refresh = await issueRefreshToken(user.id, client);

    await client.query('COMMIT');

    res.status(201).json({
      success: true, token, refresh_token: refresh, user: safe(user),
      message: 'Registration successful. Pending admin approval.',
    });
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
});

// ── login ─────────────────────────────────────────────────────
exports.login = asyncHandler(async (req, res) => {
  const { email, phone, password, fcm_token, role } = req.body;
  if ((!email && !phone) || !password)
    return res.status(400).json({ success: false, error: 'Credentials required' });

  // FIX: when role is supplied, match only users with that role so customers and
  // riders can share an email/phone.
  const roleFilter = role ? 'AND role=$3' : '';
  const params = [email?.toLowerCase().trim() || '', phone || ''];
  if (role) params.push(role);

  const { rows } = await db.query(
    `SELECT * FROM users WHERE (LOWER(email)=$1 OR phone=$2) ${roleFilter}`,
    params
  );
  if (!rows.length)
    return res.status(401).json({ success: false, error: 'Invalid credentials' });

  const user  = rows[0];
  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid)
    return res.status(401).json({ success: false, error: 'Invalid credentials' });

  if (!user.is_active)
    return res.status(403).json({ success: false, error: 'Account suspended' });

  if (fcm_token) {
    await db.query('UPDATE users SET fcm_token=$1 WHERE id=$2', [fcm_token, user.id]);
  }

  let riderProfile = null;
  if (user.role === 'rider') {
    const { rows: rp } = await db.query('SELECT * FROM rider_profiles WHERE user_id=$1', [user.id]);
    riderProfile = rp[0] || null;
    if (riderProfile?.status === 'pending')
      return res.status(403).json({ success: false, error: 'Account pending admin approval', rider_status: 'pending' });
    if (riderProfile?.status === 'rejected')
      return res.status(403).json({ success: false, error: 'Account rejected. Contact support.', rider_status: 'rejected' });
  }

  const token   = signToken(user.id, user.role);
  const refresh = await issueRefreshToken(user.id);

  res.json({
    success: true,
    token,
    refresh_token: refresh,
    user: { ...safe(user), rider_profile: riderProfile },
  });
});

// ── refresh token ─────────────────────────────────────────────
// FIX: validate token exists in DB (revocable) + handle bad JWT with 401 not 500
exports.refreshToken = asyncHandler(async (req, res) => {
  const { refresh_token } = req.body;
  if (!refresh_token)
    return res.status(400).json({ success: false, error: 'Refresh token required' });

  // Decode — return 401 for any JWT error (expired, malformed, wrong secret)
  let decoded;
  try {
    decoded = jwt.verify(refresh_token, process.env.JWT_REFRESH_SECRET);
  } catch {
    return res.status(401).json({ success: false, error: 'Invalid or expired refresh token' });
  }

  const hash = hashToken(refresh_token);

  // Validate token exists and is not expired
  const { rows: stored } = await db.query(
    `SELECT id FROM refresh_tokens
     WHERE token_hash=$1 AND user_id=$2 AND expires_at > NOW()`,
    [hash, decoded.userId]
  );
  if (!stored.length)
    return res.status(401).json({ success: false, error: 'Refresh token revoked or expired' });

  // Rotate: delete old, issue new (prevents replay attacks)
  await db.query('DELETE FROM refresh_tokens WHERE token_hash=$1', [hash]);

  const { rows } = await db.query('SELECT id, role, is_active FROM users WHERE id=$1', [decoded.userId]);
  if (!rows.length || !rows[0].is_active)
    return res.status(401).json({ success: false, error: 'User not found or inactive' });

  const newAccess  = signToken(rows[0].id, rows[0].role);
  const newRefresh = await issueRefreshToken(rows[0].id);

  res.json({ success: true, token: newAccess, refresh_token: newRefresh });
});

// ── logout ────────────────────────────────────────────────────
// Revoke the supplied refresh token so it can never be replayed.
exports.logout = asyncHandler(async (req, res) => {
  const { refresh_token } = req.body;
  if (refresh_token) {
    await db.query(
      'DELETE FROM refresh_tokens WHERE token_hash=$1',
      [hashToken(refresh_token)]
    );
  }
  res.json({ success: true, message: 'Logged out' });
});

// ── get me ────────────────────────────────────────────────────
exports.getMe = asyncHandler(async (req, res) => {
  const { rows } = await db.query('SELECT * FROM users WHERE id=$1', [req.user.id]);
  const user = rows[0];

  let extra = {};
  if (user.role === 'rider') {
    const { rows: rp } = await db.query('SELECT * FROM rider_profiles WHERE user_id=$1', [user.id]);
    extra.rider_profile = rp[0] || null;
  }
  if (user.role === 'customer') {
    const { rows: w } = await db.query('SELECT * FROM points_wallets WHERE user_id=$1', [user.id]);
    extra.wallet = w[0] || { balance: 0 };
  }

  res.json({ success: true, user: { ...safe(user), ...extra } });
});

// ── update FCM token ──────────────────────────────────────────
exports.updateFcmToken = asyncHandler(async (req, res) => {
  const { fcm_token } = req.body;
  await db.query('UPDATE users SET fcm_token=$1 WHERE id=$2', [fcm_token, req.user.id]);
  res.json({ success: true, message: 'FCM token updated' });
});

// ── update profile ────────────────────────────────────────────
exports.updateProfile = asyncHandler(async (req, res) => {
  const { full_name, phone } = req.body;
  const { rows } = await db.query(
    `UPDATE users SET full_name=COALESCE($1,full_name), phone=COALESCE($2,phone)
     WHERE id=$3 RETURNING *`,
    [full_name || null, phone || null, req.user.id]
  );
  res.json({ success: true, user: safe(rows[0]) });
});
