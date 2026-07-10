const db = require('../config/database');
const { asyncHandler } = require('../middleware/errorHandler');
const { notify } = require('../services/notificationService');

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
  const profile = rows[0];
  // S2 (#3): reliability = completed / accepted (null until the rider has accepted a job)
  profile.reliability = profile.accepted_count > 0
    ? Math.round((profile.completed_count / profile.accepted_count) * 100) / 100
    : null;
  res.json({ success: true, profile });
});

// ── Upload ID / license / Ghana Card / vehicle docs (S4 #5) ───
exports.uploadDocument = asyncHandler(async (req, res) => {
  const { doc_type, url, ghana_card_number } = req.body;
  const validTypes = ['id_document_url', 'license_url', 'ghana_card_url', 'vehicle_photo_url'];
  if (!validTypes.includes(doc_type))
    return res.status(400).json({ success: false, error: 'Invalid doc_type' });

  // doc_type is allow-listed above, so interpolation here is safe.
  if (doc_type === 'ghana_card_url' && ghana_card_number) {
    await db.query(
      `UPDATE rider_profiles SET ghana_card_url=$1, ghana_card_number=$2, updated_at=NOW() WHERE user_id=$3`,
      [url, ghana_card_number, req.user.id]
    );
  } else {
    await db.query(
      `UPDATE rider_profiles SET ${doc_type}=$1, updated_at=NOW() WHERE user_id=$2`,
      [url, req.user.id]
    );
  }
  res.json({ success: true, message: 'Document updated' });
});

// ── Onboarding progress (S4 #5) ────────────────────────────────
exports.getOnboarding = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT ghana_card_number, ghana_card_url, vehicle_photo_url, license_url, id_document_url, status
     FROM rider_profiles WHERE user_id=$1`,
    [req.user.id]
  );
  if (!rows.length) return res.status(404).json({ success: false, error: 'Profile not found' });

  const p = rows[0];
  const steps = [
    { key: 'ghana_card',    label: 'Ghana Card',        done: !!(p.ghana_card_url && p.ghana_card_number) },
    { key: 'vehicle_photo', label: 'Vehicle Photo',     done: !!p.vehicle_photo_url },
    { key: 'license',       label: "Driver's License",  done: !!p.license_url },
  ];
  const next = steps.find((s) => !s.done);

  res.json({
    success: true,
    onboarding: {
      steps,
      next_step: next ? next.key : null,
      complete: steps.every((s) => s.done),
      approval_status: p.status,
    },
  });
});

// ── Rider incentives + progress (S6 #7) ────────────────────────
exports.getIncentives = asyncHandler(async (req, res) => {
  const { rows: incentives } = await db.query(
    `SELECT id, type, title, description, target, reward_cash, reward_points, period, status
     FROM rider_incentives
     WHERE status='active' AND (rider_id IS NULL OR rider_id=$1)
     ORDER BY created_at`,
    [req.user.id]
  );

  const { rows: c } = await db.query(
    `SELECT COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE)               AS today,
            COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days')  AS week,
            COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') AS month
     FROM rider_earnings WHERE rider_id=$1`,
    [req.user.id]
  );
  const counts = c[0] || { today: 0, week: 0, month: 0 };
  const periodKey = { daily: 'today', weekly: 'week', monthly: 'month' };

  const withProgress = incentives.map((i) => {
    const progress = parseInt(counts[periodKey[i.period] || 'week'] || 0, 10);
    return { ...i, progress, achieved: progress >= i.target };
  });

  res.json({ success: true, incentives: withProgress });
});

// ── Rider SOS (S6 #7) ──────────────────────────────────────────
exports.sos = asyncHandler(async (req, res) => {
  const { order_id, lat, lng, note } = req.body;

  const { rows } = await db.query(
    `INSERT INTO rider_sos_events (rider_id, order_id, lat, lng, note)
     VALUES ($1,$2,$3,$4,$5) RETURNING id, created_at`,
    [req.user.id, order_id || null, lat || null, lng || null, note || null]
  );

  // Alert every active admin.
  const { rows: admins } = await db.query(`SELECT id FROM users WHERE role='admin' AND is_active=TRUE`);
  for (const a of admins) {
    await notify(a.id, {
      title: '🆘 Rider SOS',
      body: `A rider triggered SOS${note ? ': ' + note : ''}.`,
      data: { type: 'rider_sos', rider_id: req.user.id, sos_id: rows[0].id },
    });
  }

  res.status(201).json({ success: true, sos_id: rows[0].id, created_at: rows[0].created_at });
});

// ── Get nearby orders (for rider to see what's available) ─────
// S3 (#4): includes estimated_earning (medium-size price for the waste type,
// minus platform commission) and excludes orders this rider already declined.
exports.getNearbyOrders = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 10 } = req.query;
  const commission = parseFloat(process.env.PLATFORM_COMMISSION || '0.20');

  const EST_PRICE_SUBQ = `(SELECT pc.price FROM pricing_config pc
       WHERE pc.waste_type=o.waste_type AND pc.waste_size='medium' AND pc.is_active LIMIT 1)`;
  const NOT_DECLINED = `NOT EXISTS (SELECT 1 FROM order_offers oo
       WHERE oo.order_id=o.id AND oo.rider_id=$RIDER AND oo.status='declined')`;

  let rows;
  if (lat == null || lng == null) {
    const result = await db.query(
      `SELECT o.id, o.pickup_address, o.pickup_lat, o.pickup_lng, o.waste_type, o.requested_at,
              ${EST_PRICE_SUBQ} AS est_price
       FROM orders o
       WHERE o.status='requested' AND o.rider_id IS NULL
         AND ${NOT_DECLINED.replace('$RIDER', '$1')}
       ORDER BY o.requested_at DESC
       LIMIT 20`,
      [req.user.id]
    );
    rows = result.rows;
  } else {
    const result = await db.query(
      `SELECT * FROM (
         SELECT o.id, o.pickup_address, o.pickup_lat, o.pickup_lng, o.waste_type, o.requested_at,
                ${EST_PRICE_SUBQ} AS est_price,
                ROUND(
                  6371 * acos(
                    cos(radians($1)) * cos(radians(o.pickup_lat)) *
                    cos(radians(o.pickup_lng) - radians($2)) +
                    sin(radians($1)) * sin(radians(o.pickup_lat))
                  )::numeric, 2
                ) AS distance_km
         FROM orders o
         WHERE o.status='requested' AND o.rider_id IS NULL
           AND ${NOT_DECLINED.replace('$RIDER', '$4')}
       ) sub
       WHERE distance_km <= $3
       ORDER BY distance_km
       LIMIT 20`,
      [parseFloat(lat), parseFloat(lng), parseFloat(radius), req.user.id]
    );
    rows = result.rows;
  }

  const orders = rows.map(({ est_price, ...o }) => ({
    ...o,
    estimated_earning: est_price != null
      ? Math.round(parseFloat(est_price) * (1 - commission) * 100) / 100
      : null,
  }));

  res.json({ success: true, orders });
});
