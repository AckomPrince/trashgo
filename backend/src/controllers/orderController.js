const db = require('../config/database');
const { asyncHandler } = require('../middleware/errorHandler');
const { broadcastOrderToRiders } = require('../services/matchingService');
const { getPrice, calculatePoints } = require('../services/pricingService');
const { awardPoints } = require('../services/rewardsService');
const { notify } = require('../services/notificationService');
const { emitToUser } = require('../services/socketService');

// FIX: valid status transition map — prevents riders jumping steps
const VALID_TRANSITIONS = {
  accepted:       ['rider_en_route'],
  rider_en_route: ['rider_arrived'],
  rider_arrived:  ['size_confirmed'],
};

// ── Create order (customer) ────────────────────────────────────
exports.createOrder = asyncHandler(async (req, res) => {
  const { pickup_address, pickup_lat, pickup_lng, waste_type, waste_description } = req.body;

  if (!pickup_address || !pickup_lat || !pickup_lng)
    return res.status(400).json({ success: false, error: 'Pickup location required' });

  // Check no active order
  const { rows: active } = await db.query(
    `SELECT id FROM orders WHERE customer_id=$1 AND status NOT IN ('completed','cancelled') LIMIT 1`,
    [req.user.id]
  );
  if (active.length)
    return res.status(409).json({ success: false, error: 'You already have an active order', order_id: active[0].id });

  const { rows: [order] } = await db.query(
    `INSERT INTO orders (customer_id, pickup_address, pickup_lat, pickup_lng, waste_type, waste_description)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [req.user.id, pickup_address, pickup_lat, pickup_lng,
     waste_type || 'general', waste_description || null]
  );

  const riderCount = await broadcastOrderToRiders(order);
  res.status(201).json({ success: true, order, riders_notified: riderCount });
});

// ── Rider: accept order ────────────────────────────────────────
exports.acceptOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const riderId = req.user.id;

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const { rows } = await client.query(
      `SELECT * FROM orders WHERE id=$1 AND status='requested' FOR UPDATE`, [id]
    );
    if (!rows.length)
      return res.status(409).json({ success: false, error: 'Order no longer available' });

    const order = rows[0];
    await client.query(
      `UPDATE orders SET rider_id=$1, status='accepted', accepted_at=NOW() WHERE id=$2`,
      [riderId, id]
    );
    await client.query('COMMIT');

    await notify(order.customer_id, {
      title: '✅ Rider Accepted',
      body: 'A rider has accepted your pickup request and is on the way.',
      data: { type: 'order_accepted', order_id: id },
    });
    emitToUser(order.customer_id, 'order:update', { order_id: id, status: 'accepted', rider_id: riderId });

    res.json({ success: true, message: 'Order accepted', order_id: id });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

// ── Rider: update status (en_route → arrived → size_confirmed) ──
// FIX: parameterised queries (no more string interpolation = no SQL injection)
// FIX: state-machine transition validation
// FIX: single getPrice call (was called twice when status === size_confirmed)
exports.updateStatus = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { status, waste_size } = req.body;

  const allowed = ['rider_en_route', 'rider_arrived', 'size_confirmed'];
  if (!allowed.includes(status))
    return res.status(400).json({ success: false, error: 'Invalid status' });

  const { rows } = await db.query(
    `SELECT * FROM orders WHERE id=$1 AND rider_id=$2`, [id, req.user.id]
  );
  if (!rows.length)
    return res.status(404).json({ success: false, error: 'Order not found' });

  const order = rows[0];

  // FIX: enforce state-machine — no skipping steps
  const allowed_from = VALID_TRANSITIONS[order.status];
  if (!allowed_from || !allowed_from.includes(status))
    return res.status(400).json({
      success: false,
      error: `Cannot transition from '${order.status}' to '${status}'`,
    });

  let notifBody = '';

  if (status === 'rider_en_route') {
    // FIX: fully parameterised, no string concat
    await db.query(`UPDATE orders SET status=$1 WHERE id=$2`, [status, id]);
    notifBody = 'Your rider is on the way!';

  } else if (status === 'rider_arrived') {
    await db.query(`UPDATE orders SET status=$1, arrived_at=NOW() WHERE id=$2`, [status, id]);
    notifBody = 'Your rider has arrived at your location.';

  } else if (status === 'size_confirmed') {
    if (!waste_size)
      return res.status(400).json({ success: false, error: 'waste_size required' });

    const VALID_SIZES = ['small', 'medium', 'large'];
    if (!VALID_SIZES.includes(waste_size))
      return res.status(400).json({ success: false, error: 'waste_size must be small, medium, or large' });

    // FIX: getPrice called once, result reused for both DB update and notification
    const pricing = await getPrice(waste_size, order.waste_type);

    await db.query(
      `UPDATE orders
       SET status=$1, waste_size=$2, base_price=$3, final_price=$3,
           arrived_at=COALESCE(arrived_at, NOW())
       WHERE id=$4`,
      [status, waste_size, pricing.price, id]
    );

    notifBody = `Waste size confirmed. Price: GHS ${pricing.price}. Please review and approve.`;
  }

  await notify(order.customer_id, {
    title: '📦 Order Update',
    body: notifBody,
    data: { type: 'order_status', order_id: id, status },
  });
  emitToUser(order.customer_id, 'order:update', { order_id: id, status, waste_size });

  res.json({ success: true, status });
});

// ── Customer: approve price ────────────────────────────────────
exports.approvePrice = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { rows } = await db.query(
    `SELECT * FROM orders WHERE id=$1 AND customer_id=$2 AND status='size_confirmed'`,
    [id, req.user.id]
  );
  if (!rows.length)
    return res.status(404).json({ success: false, error: 'Order not found or price not yet set' });

  const order = rows[0];
  await db.query(`UPDATE orders SET status='price_approved' WHERE id=$1`, [id]);

  await notify(order.rider_id, {
    title: '💳 Price Approved',
    body: 'Customer approved the price. Proceed with the pickup.',
    data: { type: 'price_approved', order_id: id },
  });
  emitToUser(order.rider_id, 'order:update', { order_id: id, status: 'price_approved' });

  res.json({ success: true, message: 'Price approved', order });
});

// ── Customer: cancel order ─────────────────────────────────────
// FIX: added 'size_confirmed' and 'price_approved' as cancellable states
// (rider has arrived but no work done yet — fair to let customer cancel)
exports.cancelOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  const { rows } = await db.query(
    `SELECT * FROM orders WHERE id=$1 AND customer_id=$2`, [id, req.user.id]
  );
  if (!rows.length)
    return res.status(404).json({ success: false, error: 'Order not found' });

  const cancellable = ['requested', 'accepted', 'rider_en_route', 'rider_arrived', 'size_confirmed', 'price_approved'];
  if (!cancellable.includes(rows[0].status))
    return res.status(400).json({ success: false, error: 'Cannot cancel at this stage' });

  await db.query(
    `UPDATE orders SET status='cancelled', cancelled_at=NOW(), cancel_reason=$1 WHERE id=$2`,
    [reason || null, id]
  );

  if (rows[0].rider_id) {
    await notify(rows[0].rider_id, {
      title: 'Order Cancelled',
      body: 'The customer cancelled the pickup request.',
      data: { type: 'order_cancelled', order_id: id },
    });
    emitToUser(rows[0].rider_id, 'order:update', { order_id: id, status: 'cancelled' });
  }

  res.json({ success: true, message: 'Order cancelled' });
});

// ── Rider: complete order ──────────────────────────────────────
// S1 (#2): rider earnings + wallet credit happen in ONE transaction. The
// wallet is credited only when a NEW rider_earnings row is inserted (idempotent
// on order_id) so a retry can never double-credit. Customer points are awarded
// after commit (awardPoints runs its own transaction).
exports.completeOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const client = await db.getClient();
  let order;
  let net = 0;
  try {
    await client.query('BEGIN');

    const { rows } = await client.query(
      `SELECT * FROM orders WHERE id=$1 AND rider_id=$2 AND status='in_progress' FOR UPDATE`,
      [id, req.user.id]
    );
    if (!rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ success: false, error: 'Order not found or not in progress' });
    }
    order = rows[0];

    await client.query(`UPDATE orders SET status='completed', completed_at=NOW() WHERE id=$1`, [id]);

    const gross      = parseFloat(order.final_price || 0);
    const commission = Math.round(gross * parseFloat(process.env.PLATFORM_COMMISSION || '0.20') * 100) / 100;
    net              = Math.round((gross - commission) * 100) / 100;

    const earning = await client.query(
      `INSERT INTO rider_earnings (rider_id, order_id, gross, commission, net)
       VALUES ($1,$2,$3,$4,$5) ON CONFLICT (order_id) DO NOTHING RETURNING id`,
      [req.user.id, id, gross, commission, net]
    );

    // Credit the rider wallet only on the first (non-conflicting) earnings insert.
    if (earning.rows.length) {
      await client.query(
        `INSERT INTO rider_wallets (user_id, balance, total_earned)
         VALUES ($1,$2,$2)
         ON CONFLICT (user_id) DO UPDATE
           SET balance      = rider_wallets.balance + $2,
               total_earned = rider_wallets.total_earned + $2,
               updated_at   = NOW()`,
        [req.user.id, net]
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  const points = calculatePoints({ wasteType: order.waste_type, wasteSize: order.waste_size });
  await awardPoints(order.customer_id, id, points);

  await notify(order.customer_id, {
    title: '✅ Pickup Complete!',
    body: `Your waste was collected. You earned ${points} points!`,
    data: { type: 'order_completed', order_id: id, points: String(points) },
  });
  emitToUser(order.customer_id, 'order:update', { order_id: id, status: 'completed', points_awarded: points });

  res.json({ success: true, message: 'Order completed', points_awarded: points, rider_net_earning: net });
});

// ── Get single order ───────────────────────────────────────────
exports.getOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const user   = req.user;

  let condition = 'o.id=$1';
  let params    = [id];

  if (user.role === 'customer') { condition += ' AND o.customer_id=$2'; params.push(user.id); }
  if (user.role === 'rider')    { condition += ' AND o.rider_id=$2';    params.push(user.id); }

  const { rows } = await db.query(
    `SELECT o.*,
            u.full_name AS customer_name, u.phone AS customer_phone,
            r.full_name AS rider_name,    r.phone AS rider_phone,
            rp.vehicle_type, rp.current_lat AS rider_lat, rp.current_lng AS rider_lng
     FROM orders o
     JOIN users u ON u.id = o.customer_id
     LEFT JOIN users r ON r.id = o.rider_id
     LEFT JOIN rider_profiles rp ON rp.user_id = o.rider_id
     WHERE ${condition}`,
    params
  );

  if (!rows.length) return res.status(404).json({ success: false, error: 'Order not found' });
  res.json({ success: true, order: rows[0] });
});

// ── List orders ────────────────────────────────────────────────
exports.listOrders = asyncHandler(async (req, res) => {
  const user  = req.user;
  const { status, page = 1, limit = 20 } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);

  let where  = '';
  let params = [];

  if (user.role === 'customer') { where  = 'WHERE o.customer_id=$1'; params.push(user.id); }
  if (user.role === 'rider')    { where  = 'WHERE o.rider_id=$1';    params.push(user.id); }

  if (status) {
    params.push(status);
    where += (where ? ' AND' : 'WHERE') + ` o.status=$${params.length}`;
  }

  params.push(parseInt(limit));
  params.push(offset);

  const { rows } = await db.query(
    `SELECT o.*, u.full_name AS customer_name, r.full_name AS rider_name
     FROM orders o
     JOIN users u ON u.id = o.customer_id
     LEFT JOIN users r ON r.id = o.rider_id
     ${where}
     ORDER BY o.created_at DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  res.json({ success: true, orders: rows, page: parseInt(page), limit: parseInt(limit) });
});

// ── Customer: rate order ───────────────────────────────────────
exports.rateOrder = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { rating, review } = req.body;

  if (!rating || rating < 1 || rating > 5)
    return res.status(400).json({ success: false, error: 'Rating must be 1-5' });

  const { rows } = await db.query(
    `UPDATE orders SET customer_rating=$1, customer_review=$2
     WHERE id=$3 AND customer_id=$4 AND status='completed'
     RETURNING id`,
    [rating, review || null, id, req.user.id]
  );

  if (!rows.length)
    return res.status(404).json({ success: false, error: 'Order not found or not completed' });

  res.json({ success: true, message: 'Rating submitted' });
});

// ── Rider: start in-progress ───────────────────────────────────
exports.startPickup = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const { rows } = await db.query(
    `UPDATE orders SET status='in_progress'
     WHERE id=$1 AND rider_id=$2 AND status='payment_authorized'
     RETURNING *`,
    [id, req.user.id]
  );

  if (!rows.length)
    return res.status(404).json({ success: false, error: 'Order not found or payment not authorized' });

  await notify(rows[0].customer_id, {
    title: '🚛 Pickup In Progress',
    body: 'Your rider has started the pickup!',
    data: { type: 'order_in_progress', order_id: id },
  });
  emitToUser(rows[0].customer_id, 'order:update', { order_id: id, status: 'in_progress' });

  res.json({ success: true, message: 'Pickup started' });
});
