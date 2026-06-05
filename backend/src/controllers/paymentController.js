// FIX: require('crypto') moved to top of file — not inside the handler
const https  = require('https');
const crypto = require('crypto');
const db     = require('../config/database');
const { asyncHandler } = require('../middleware/errorHandler');
const { notify }       = require('../services/notificationService');
const { emitToUser }   = require('../services/socketService');

const PAYSTACK_TIMEOUT_MS = 10_000; // 10 seconds

// ── Paystack helper ───────────────────────────────────────────
function paystackRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const req = https.request(
      {
        hostname: 'api.paystack.co',
        port: 443,
        path,
        method,
        headers: {
          Authorization: `Bearer ${process.env.PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
          ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        },
      },
      (res) => {
        let str = '';
        res.on('data', (chunk) => (str += chunk));
        res.on('end', () => {
          try { resolve(JSON.parse(str)); }
          catch { reject(new Error('Invalid JSON from Paystack')); }
        });
      }
    );

    // FIX: add request timeout so a slow Paystack API never hangs indefinitely
    req.setTimeout(PAYSTACK_TIMEOUT_MS, () => {
      req.destroy(new Error(`Paystack request timed out after ${PAYSTACK_TIMEOUT_MS}ms`));
    });

    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

// ── Initialize payment ────────────────────────────────────────
exports.initializePayment = asyncHandler(async (req, res) => {
  const { order_id } = req.body;

  const { rows } = await db.query(
    `SELECT o.*, u.email AS customer_email
     FROM orders o JOIN users u ON u.id=o.customer_id
     WHERE o.id=$1 AND o.customer_id=$2 AND o.status='price_approved'`,
    [order_id, req.user.id]
  );
  if (!rows.length)
    return res.status(404).json({ success: false, error: 'Order not found or price not approved' });

  const order     = rows[0];
  const amount    = Math.round(parseFloat(order.final_price) * 100); // pesewas
  const reference = `TG-${order.id.replace(/-/g, '').slice(0, 16).toUpperCase()}-${Date.now()}`;

  const psRes = await paystackRequest('POST', '/transaction/initialize', {
    email:    order.customer_email,
    amount,
    currency: order.currency || 'GHS',
    reference,
    channels: ['mobile_money', 'card'],
    metadata: {
      order_id: order.id,
      custom_fields: [
        { display_name: 'Order ID',   variable_name: 'order_id',   value: order.id },
        { display_name: 'Waste Type', variable_name: 'waste_type', value: order.waste_type },
      ],
    },
  });

  if (!psRes.status)
    return res.status(502).json({ success: false, error: psRes.message || 'Paystack error' });

  await db.query(
    `UPDATE orders SET payment_reference=$1, payment_access_code=$2, status='payment_authorized'
     WHERE id=$3`,
    [reference, psRes.data.access_code, order.id]
  );

  res.json({
    success:           true,
    authorization_url: psRes.data.authorization_url,
    access_code:       psRes.data.access_code,
    reference,
  });
});

// ── Paystack webhook ───────────────────────────────────────────
// FIX 1: All DB writes happen BEFORE sending the 200 response so that if
//         any write fails Paystack will retry (it only marks delivery as
//         succeeded when it receives a 200).
// FIX 2: Idempotency guard — if we already marked the order 'paid' we skip
//         processing and still return 200 (safe to retry).
exports.paystackWebhook = asyncHandler(async (req, res) => {
  // Verify HMAC-SHA512 signature
  const hash = crypto
    .createHmac('sha512', process.env.PAYSTACK_SECRET_KEY)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (hash !== req.headers['x-paystack-signature'])
    return res.status(400).json({ error: 'Invalid signature' });

  const { event, data } = req.body;

  if (event === 'charge.success') {
    // FIX: idempotency — fetch current state before doing anything
    const { rows } = await db.query(
      `SELECT * FROM orders WHERE payment_reference=$1`, [data.reference]
    );
    if (!rows.length) return res.sendStatus(200); // unknown reference, ignore

    const order = rows[0];

    // Skip if already processed (Paystack retry)
    if (order.payment_status === 'paid') return res.sendStatus(200);

    // All DB work runs before the 200
    await db.query(
      `UPDATE orders SET payment_status='paid', paid_at=NOW() WHERE id=$1`, [order.id]
    );

    await notify(order.customer_id, {
      title: '💳 Payment Confirmed',
      body: `Payment of GHS ${order.final_price} confirmed. Pickup in progress.`,
      data: { type: 'payment_success', order_id: order.id },
    });
    emitToUser(order.customer_id, 'payment:success', { order_id: order.id });

    if (order.rider_id) {
      await notify(order.rider_id, {
        title: '💰 Payment Received',
        body: 'Customer payment confirmed. Please complete the pickup.',
        data: { type: 'payment_success', order_id: order.id },
      });
      emitToUser(order.rider_id, 'payment:success', { order_id: order.id });
    }

    return res.sendStatus(200);
  }

  if (event === 'charge.failed') {
    // Idempotency: only update if currently not in a success state
    const { rows } = await db.query(
      `UPDATE orders
       SET payment_status='failed', status='price_approved'
       WHERE payment_reference=$1 AND payment_status != 'paid'
       RETURNING *`,
      [data.reference]
    );

    if (rows.length) {
      await notify(rows[0].customer_id, {
        title: '❌ Payment Failed',
        body: 'Your payment failed. Please try again.',
        data: { type: 'payment_failed', order_id: rows[0].id },
      });
    }

    return res.sendStatus(200);
  }

  // Unknown event — acknowledge without processing
  res.sendStatus(200);
});

// ── Verify payment (manual check) ────────────────────────────
exports.verifyPayment = asyncHandler(async (req, res) => {
  const { reference } = req.params;
  const psRes = await paystackRequest('GET', `/transaction/verify/${reference}`);
  res.json({ success: psRes.status, data: psRes.data });
});
