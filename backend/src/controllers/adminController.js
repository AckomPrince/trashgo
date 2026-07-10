const db = require('../config/database');
const { asyncHandler } = require('../middleware/errorHandler');
const { notify } = require('../services/notificationService');

// ── Health check ──────────────────────────────────────────────
// FIX: provides a real /admin/health endpoint instead of hardcoded "ONLINE"
exports.getHealth = asyncHandler(async (req, res) => {
  const checks = {};

  // Database
  try {
    await db.query('SELECT 1');
    checks.database = 'online';
  } catch {
    checks.database = 'offline';
  }

  // Firebase / FCM — just check the env var is set (SDK init throws at startup if bad)
  checks.firebase = process.env.FIREBASE_PROJECT_ID ? 'online' : 'unconfigured';

  // Paystack — check env var is set
  checks.paystack = process.env.PAYSTACK_SECRET_KEY ? 'online' : 'unconfigured';

  const allOk = Object.values(checks).every((v) => v === 'online');
  res.status(allOk ? 200 : 503).json({ success: allOk, checks });
});

// ── Dashboard stats ────────────────────────────────────────────
exports.getDashboard = asyncHandler(async (req, res) => {
  const [users, orders, revenue, riders] = await Promise.all([
    db.query(`SELECT
                COUNT(*) FILTER (WHERE role='customer') AS total_customers,
                COUNT(*) FILTER (WHERE role='rider')    AS total_riders
              FROM users`),
    db.query(`SELECT
                COUNT(*)                                         AS total_orders,
                COUNT(*) FILTER (WHERE status='completed')       AS completed,
                COUNT(*) FILTER (WHERE status='cancelled')       AS cancelled,
                COUNT(*) FILTER (WHERE status NOT IN ('completed','cancelled')) AS active
              FROM orders`),
    db.query(`SELECT COALESCE(SUM(final_price),0) AS total_revenue
              FROM orders WHERE status='completed' AND paid_at IS NOT NULL`),
    db.query(`SELECT COUNT(*) FILTER (WHERE status='pending') AS pending_approvals
              FROM rider_profiles`),
  ]);

  res.json({
    success: true,
    stats: {
      ...users.rows[0],
      ...orders.rows[0],
      total_revenue: revenue.rows[0].total_revenue,
      pending_rider_approvals: riders.rows[0].pending_approvals,
    },
  });
});

// ── List riders ────────────────────────────────────────────────
exports.listRiders = asyncHandler(async (req, res) => {
  const { status = 'pending', page = 1, limit = 20 } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);

  const [{ rows }, { rows: countRows }] = await Promise.all([
    db.query(
      `SELECT u.id, u.full_name, u.email, u.phone, u.created_at,
              rp.vehicle_type, rp.vehicle_plate, rp.id_document_url,
              rp.license_url, rp.ghana_card_number, rp.ghana_card_url, rp.vehicle_photo_url,
              rp.status, rp.is_online, rp.approved_at, rp.admin_note
       FROM users u JOIN rider_profiles rp ON rp.user_id=u.id
       WHERE rp.status=$1
       ORDER BY u.created_at DESC
       LIMIT $2 OFFSET $3`,
      [status, parseInt(limit), offset]
    ),
    db.query(
      'SELECT COUNT(*) AS total FROM rider_profiles WHERE status=$1', [status]
    ),
  ]);

  res.json({
    success: true,
    riders:  rows,
    total:   parseInt(countRows[0].total),
    page:    parseInt(page),
  });
});

// ── Approve / reject rider ─────────────────────────────────────
exports.reviewRider = asyncHandler(async (req, res) => {
  const { rider_id } = req.params;
  const { action, note } = req.body;

  const valid = ['approved', 'rejected', 'suspended'];
  if (!valid.includes(action))
    return res.status(400).json({ success: false, error: 'Invalid action' });

  // FIX: cast $1 explicitly to the enum on assignment. Without the cast $1 is
  // deduced as rider_status in `status=$1` but as text in `$1='approved'`,
  // which Postgres rejects ("inconsistent types deduced for parameter $1").
  // Casting only the assignment keeps $1 a plain text parameter everywhere.
  await db.query(
    `UPDATE rider_profiles
     SET status=$1::rider_status, admin_note=$2, approved_by=$3,
         approved_at=CASE WHEN $1='approved' THEN NOW() ELSE approved_at END
     WHERE user_id=$4`,
    [action, note || null, req.user.id, rider_id]
  );

  const { rows } = await db.query('SELECT full_name FROM users WHERE id=$1', [rider_id]);

  const msgMap = {
    approved:  { title: '✅ Account Approved', body: 'Your rider account has been approved. You can now go online and accept pickups!' },
    rejected:  { title: '❌ Account Rejected',  body: note || 'Your application was rejected. Contact support for more info.' },
    suspended: { title: '⚠️ Account Suspended',  body: note || 'Your account has been suspended. Contact support.' },
  };

  await notify(rider_id, { ...msgMap[action], data: { type: 'account_status', status: action } });

  res.json({ success: true, message: `Rider ${action}`, rider: rows[0] });
});

// ── List all orders (admin) ────────────────────────────────────
// FIX: returns total count so the frontend can display "Page X of Y"
exports.listOrders = asyncHandler(async (req, res) => {
  const { status, page = 1, limit = 30, from, to } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);
  let conditions = [];
  let params = [];

  if (status) { params.push(status); conditions.push(`o.status=$${params.length}`); }
  if (from)   { params.push(from);   conditions.push(`o.created_at >= $${params.length}`); }
  if (to)     { params.push(to);     conditions.push(`o.created_at <= $${params.length}`); }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  // Run data query and count query in parallel
  const countParams = [...params]; // same filter params, no limit/offset
  params.push(parseInt(limit));
  params.push(offset);

  const [{ rows }, { rows: countRows }] = await Promise.all([
    db.query(
      `SELECT o.*, c.full_name AS customer_name, c.phone AS customer_phone,
              r.full_name AS rider_name
       FROM orders o
       JOIN users c ON c.id=o.customer_id
       LEFT JOIN users r ON r.id=o.rider_id
       ${where}
       ORDER BY o.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    ),
    db.query(
      `SELECT COUNT(*) AS total FROM orders o ${where}`,
      countParams
    ),
  ]);

  res.json({
    success: true,
    orders:  rows,
    total:   parseInt(countRows[0].total),
    page:    parseInt(page),
    limit:   parseInt(limit),
  });
});

// ── Handle dispute ─────────────────────────────────────────────
exports.resolveDispute = asyncHandler(async (req, res) => {
  const { dispute_id } = req.params;
  const { resolution, status = 'resolved' } = req.body;

  const { rows } = await db.query(
    `UPDATE disputes SET status=$1, resolution=$2, resolved_by=$3, updated_at=NOW()
     WHERE id=$4 RETURNING *`,
    [status, resolution, req.user.id, dispute_id]
  );

  if (!rows.length)
    return res.status(404).json({ success: false, error: 'Dispute not found' });

  res.json({ success: true, dispute: rows[0] });
});

// ── List disputes ──────────────────────────────────────────────
exports.listDisputes = asyncHandler(async (req, res) => {
  const { status = 'open' } = req.query;
  const { rows } = await db.query(
    `SELECT d.*, o.pickup_address, o.waste_type, o.final_price,
            u.full_name AS raised_by_name
     FROM disputes d
     JOIN orders o ON o.id=d.order_id
     JOIN users u ON u.id=d.raised_by
     WHERE d.status=$1
     ORDER BY d.created_at DESC`,
    [status]
  );
  res.json({ success: true, disputes: rows });
});

// ── Analytics ──────────────────────────────────────────────────
// FIX: INTERVAL string was previously interpolated with `${parseInt(period)} days`
// which, while parseInt strips non-digits, is still poor practice and breaks
// if period is NaN. Use a proper parameterised cast instead.
exports.getAnalytics = asyncHandler(async (req, res) => {
  const period = Math.max(1, parseInt(req.query.period || '30', 10) || 30);

  const [daily, byType, byStatus, topRiders] = await Promise.all([
    db.query(
      `SELECT DATE(created_at) AS date, COUNT(*) AS orders, COALESCE(SUM(final_price),0) AS revenue
       FROM orders
       WHERE created_at >= NOW() - ($1 * INTERVAL '1 day')
       GROUP BY DATE(created_at) ORDER BY date`,
      [period]
    ),
    db.query(
      `SELECT waste_type, COUNT(*) AS count FROM orders
       WHERE created_at >= NOW() - ($1 * INTERVAL '1 day')
       GROUP BY waste_type`,
      [period]
    ),
    db.query(
      `SELECT status, COUNT(*) AS count FROM orders
       WHERE created_at >= NOW() - ($1 * INTERVAL '1 day')
       GROUP BY status`,
      [period]
    ),
    db.query(
      `SELECT u.full_name, COUNT(re.id) AS jobs, COALESCE(SUM(re.net),0) AS earnings
       FROM rider_earnings re JOIN users u ON u.id=re.rider_id
       WHERE re.created_at >= NOW() - ($1 * INTERVAL '1 day')
       GROUP BY u.id, u.full_name
       ORDER BY earnings DESC LIMIT 10`,
      [period]
    ),
  ]);

  res.json({
    success:      true,
    daily_trend:  daily.rows,
    by_waste_type: byType.rows,
    by_status:    byStatus.rows,
    top_riders:   topRiders.rows,
  });
});

// ── Update pricing config ──────────────────────────────────────
exports.updatePricing = asyncHandler(async (req, res) => {
  const { waste_size, waste_type, price } = req.body;
  await db.query(
    `UPDATE pricing_config SET price=$1, updated_at=NOW()
     WHERE waste_size=$2 AND waste_type=$3`,
    [price, waste_size, waste_type]
  );
  res.json({ success: true, message: 'Pricing updated' });
});

exports.getPricing = asyncHandler(async (req, res) => {
  const { rows } = await db.query('SELECT * FROM pricing_config ORDER BY waste_type, waste_size');
  res.json({ success: true, pricing: rows });
});
