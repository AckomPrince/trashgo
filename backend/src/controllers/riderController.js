const db = require('../config/database');
const { asyncHandler } = require('../middleware/errorHandler');

// ── Toggle online/offline ──────────────────────────────────────
exports.setAvailability = asyncHandler(async (req, res) => {
  const { online } = req.body;
  await db.query(
    `UPDATE rider_profiles SET is_online=$1, last_seen_at=NOW() WHERE user_id=$2`,
    [!!online, req.user.id]
  );
  res.json({ success: true, online: !!online });
});

// ── Update current location ────────────────────────────────────
exports.updateLocation = asyncHandler(async (req, res) => {
  const { lat, lng } = req.body;
  if (!lat || !lng) return res.status(400).json({ success: false, error: 'lat and lng required' });
  await db.query(
    `UPDATE rider_profiles SET current_lat=$1, current_lng=$2, last_seen_at=NOW() WHERE user_id=$3`,
    [lat, lng, req.user.id]
  );
  res.json({ success: true });
});

// ── Get rider wallet (S1 #2) ───────────────────────────────────
exports.getWallet = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    'SELECT user_id, balance, total_earned, total_withdrawn, currency, updated_at FROM rider_wallets WHERE user_id=$1',
    [req.user.id]
  );
  const wallet = rows[0] || {
    user_id: req.user.id, balance: 0, total_earned: 0, total_withdrawn: 0, currency: 'GHS',
  };
  res.json({ success: true, wallet });
});

// ── Get rider earnings ─────────────────────────────────────────
exports.getEarnings = asyncHandler(async (req, res) => {
  const riderId = req.user.id;
  const { period = 'all' } = req.query;

  let dateFilter = '';
  if (period === 'today')  dateFilter = `AND re.created_at >= CURRENT_DATE`;
  if (period === 'week')   dateFilter = `AND re.created_at >= NOW() - INTERVAL '7 days'`;
  if (period === 'month')  dateFilter = `AND re.created_at >= NOW() - INTERVAL '30 days'`;

  const { rows } = await db.query(
    `SELECT
       COUNT(*)::int             AS total_jobs,
       COALESCE(SUM(re.gross),0)  AS total_gross,
       COALESCE(SUM(re.net),0)    AS total_net,
       COALESCE(SUM(re.commission),0) AS total_commission
     FROM rider_earnings re
     WHERE re.rider_id=$1 ${dateFilter}`,
    [riderId]
  );

  const { rows: recent } = await db.query(
    `SELECT re.*, o.pickup_address, o.waste_type, o.completed_at
     FROM rider_earnings re JOIN orders o ON o.id=re.order_id
     WHERE re.rider_id=$1
     ORDER BY re.created_at DESC LIMIT 20`,
    [riderId]
  );

  res.json({ success: true, summary: rows[0], recent_earnings: recent });
});

// ── Get rider profile ──────────────────────────────────────────
exports.getProfile = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT u.full_name, u.email, u.phone, u.profile_photo,
            rp.*
     FROM users u JOIN rider_profiles rp ON rp.user_id=u.id
     WHERE u.id=$1`,
    [req.user.id]
  );
  if (!rows.length) return res.status(404).json({ success: false, error: 'Profile not found' });
  res.json({ success: true, profile: rows[0] });
});

// ── Upload ID / license docs (base64 or URL) ──────────────────
exports.uploadDocument = asyncHandler(async (req, res) => {
  const { doc_type, url } = req.body;
  const validTypes = ['id_document_url', 'license_url'];
  if (!validTypes.includes(doc_type))
    return res.status(400).json({ success: false, error: 'Invalid doc_type' });

  await db.query(
    `UPDATE rider_profiles SET ${doc_type}=$1, updated_at=NOW() WHERE user_id=$2`,
    [url, req.user.id]
  );
  res.json({ success: true, message: 'Document updated' });
});

// ── Get nearby orders (for rider to see what's available) ─────
exports.getNearbyOrders = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 10 } = req.query;

  let rows;
  if (lat == null || lng == null) {
    // FIX/MVP: return all unassigned requested orders without distance filtering.
    // GPS-based matching will be added in a future update.
    const result = await db.query(
      `SELECT o.id, o.pickup_address, o.pickup_lat, o.pickup_lng, o.waste_type, o.requested_at
       FROM orders o
       WHERE o.status='requested' AND o.rider_id IS NULL
       ORDER BY o.requested_at DESC
       LIMIT 20`
    );
    rows = result.rows;
  } else {
    // FIX: use a subquery so the calculated distance can be filtered in the outer WHERE
    // without requiring a GROUP BY clause.
    const result = await db.query(
      `SELECT * FROM (
         SELECT o.id, o.pickup_address, o.pickup_lat, o.pickup_lng, o.waste_type, o.requested_at,
                ROUND(
                  6371 * acos(
                    cos(radians($1)) * cos(radians(o.pickup_lat)) *
                    cos(radians(o.pickup_lng) - radians($2)) +
                    sin(radians($1)) * sin(radians(o.pickup_lat))
                  )::numeric, 2
                ) AS distance_km
         FROM orders o
         WHERE o.status='requested' AND o.rider_id IS NULL
       ) sub
       WHERE distance_km <= $3
       ORDER BY distance_km
       LIMIT 20`,
      [parseFloat(lat), parseFloat(lng), parseFloat(radius)]
    );
    rows = result.rows;
  }

  res.json({ success: true, orders: rows });
});
