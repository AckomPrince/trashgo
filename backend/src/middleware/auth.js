const jwt = require('jsonwebtoken');
const db  = require('../config/database');

// FIX: short-lived in-process cache so we don't hit the DB on every request.
// Key = userId, value = { user, expiresAt }. TTL is 60 s — stale enough to
// be safe under a compromise (token revocation via is_active=false propagates
// within 60 s) and fast enough for practical purposes.
const USER_CACHE_TTL_MS = 60_000;
const userCache = new Map();

function getCachedUser(userId) {
  const entry = userCache.get(userId);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) { userCache.delete(userId); return null; }
  return entry.user;
}

function setCachedUser(userId, user) {
  userCache.set(userId, { user, expiresAt: Date.now() + USER_CACHE_TTL_MS });
}

/** Call this whenever a user's status changes (suspension, role change, etc.)
 *  so the stale cached record is evicted immediately. */
function invalidateUserCache(userId) {
  userCache.delete(userId);
}

const auth = (roles = []) => async (req, res, next) => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer '))
      return res.status(401).json({ success: false, error: 'No token provided' });

    const token   = header.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Try cache first; fall back to DB
    let user = getCachedUser(decoded.userId);
    if (!user) {
      const { rows } = await db.query(
        'SELECT id, role, full_name, email, phone, is_active FROM users WHERE id = $1',
        [decoded.userId]
      );
      if (!rows.length || !rows[0].is_active)
        return res.status(401).json({ success: false, error: 'User not found or inactive' });

      user = rows[0];
      setCachedUser(decoded.userId, user);
    } else if (!user.is_active) {
      // Cache may have stale is_active — evict and reject
      invalidateUserCache(decoded.userId);
      return res.status(401).json({ success: false, error: 'User not found or inactive' });
    }

    req.user = user;

    if (roles.length && !roles.includes(req.user.role))
      return res.status(403).json({ success: false, error: 'Access denied' });

    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError')
      return res.status(401).json({ success: false, error: 'Token expired' });
    return res.status(401).json({ success: false, error: 'Invalid token' });
  }
};

module.exports = { auth, invalidateUserCache };
