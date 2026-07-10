// Payments — Epic P (issue #8): rider payouts to MoMo / bank.
// A thin adapter over the S1 rider_wallets balance. Flexible (MoMo + bank),
// quick (Paystack Transfers), seamless (saved recipients, one-tap withdraw).
//
// PAYMENTS_MOCK=true simulates Paystack transfer calls so the whole flow can be
// exercised end-to-end locally without live Paystack credentials. NEVER enable
// PAYMENTS_MOCK in production.

const crypto = require('crypto');
const db = require('../config/database');
const { asyncHandler } = require('../middleware/errorHandler');
const { notify } = require('../services/notificationService');
const { emitToUser } = require('../services/socketService');
const { paystackRequest } = require('./paymentController');

const isMock = () => process.env.PAYMENTS_MOCK === 'true';

async function createTransferRecipient({ type, name, account_number, bank_code }) {
  if (isMock()) return { status: true, data: { recipient_code: `MOCK-RCP-${Date.now()}` } };
  return paystackRequest('POST', '/transferrecipient', {
    type: type === 'bank' ? 'nuban' : 'mobile_money',
    name,
    account_number,
    bank_code,
    currency: 'GHS',
  });
}

async function initiateTransfer({ amount, recipient_code, reason, reference }) {
  if (isMock()) return { status: true, data: { transfer_code: `MOCK-TRF-${Date.now()}`, status: 'pending' } };
  return paystackRequest('POST', '/transfer', {
    source: 'balance',
    amount: Math.round(amount * 100), // pesewas
    recipient: recipient_code,
    reason,
    reference,
  });
}

// ── Save a payout recipient (MoMo or bank) ─────────────────────
exports.createRecipient = asyncHandler(async (req, res) => {
  const { type, account_number, bank_code, account_name, provider, is_default } = req.body;
  if (!['mobile_money', 'bank'].includes(type))
    return res.status(400).json({ success: false, error: 'type must be mobile_money or bank' });
  if (!account_number)
    return res.status(400).json({ success: false, error: 'account_number required' });

  const ps = await createTransferRecipient({
    type, name: account_name || 'TrashGo Rider', account_number, bank_code,
  });
  if (!ps.status)
    return res.status(502).json({ success: false, error: ps.message || 'Paystack recipient error' });

  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    if (is_default)
      await client.query(`UPDATE payout_recipients SET is_default=FALSE WHERE rider_id=$1`, [req.user.id]);
    const { rows } = await client.query(
      `INSERT INTO payout_recipients
         (rider_id, type, provider, account_number, account_name, bank_code, paystack_recipient_code, is_default)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.user.id, type, provider || null, account_number, account_name || null,
       bank_code || null, ps.data.recipient_code, !!is_default]
    );
    await client.query('COMMIT');
    res.status(201).json({ success: true, recipient: rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

exports.listRecipients = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT * FROM payout_recipients WHERE rider_id=$1 ORDER BY is_default DESC, created_at DESC`,
    [req.user.id]
  );
  res.json({ success: true, recipients: rows });
});

// ── Withdraw from wallet to a recipient ────────────────────────
exports.initiatePayout = asyncHandler(async (req, res) => {
  const amt = parseFloat(req.body.amount);
  const min = parseFloat(process.env.MIN_PAYOUT || '10');
  if (!amt || amt <= 0)
    return res.status(400).json({ success: false, error: 'amount required' });
  if (amt < min)
    return res.status(400).json({ success: false, error: `Minimum payout is GHS ${min}` });

  const reference = `PO-${req.user.id.replace(/-/g, '').slice(0, 12)}-${Date.now()}`;
  const client = await db.getClient();
  let payout;
  let recipient;
  try {
    await client.query('BEGIN');

    const { rows: w } = await client.query(
      `SELECT balance FROM rider_wallets WHERE user_id=$1 FOR UPDATE`, [req.user.id]
    );
    const balance = w.length ? parseFloat(w[0].balance) : 0;
    if (balance < amt) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'Insufficient wallet balance' });
    }

    const recRows = req.body.recipient_id
      ? await client.query(`SELECT * FROM payout_recipients WHERE id=$1 AND rider_id=$2`, [req.body.recipient_id, req.user.id])
      : await client.query(`SELECT * FROM payout_recipients WHERE rider_id=$1 AND is_default=TRUE ORDER BY created_at DESC LIMIT 1`, [req.user.id]);
    if (!recRows.rows.length) {
      await client.query('ROLLBACK');
      return res.status(400).json({ success: false, error: 'No payout recipient found' });
    }
    recipient = recRows.rows[0];

    // Debit the wallet and record a pending payout atomically.
    await client.query(
      `UPDATE rider_wallets SET balance=balance-$1, total_withdrawn=total_withdrawn+$1, updated_at=NOW() WHERE user_id=$2`,
      [amt, req.user.id]
    );
    const { rows: p } = await client.query(
      `INSERT INTO payouts (rider_id, recipient_id, amount, status, reference)
       VALUES ($1,$2,$3,'pending',$4) RETURNING *`,
      [req.user.id, recipient.id, amt, reference]
    );
    payout = p[0];

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  // Initiate the transfer AFTER commit; compensate (refund) if it fails.
  let ps;
  try {
    ps = await initiateTransfer({
      amount: amt, recipient_code: recipient.paystack_recipient_code,
      reason: 'TrashGo rider payout', reference,
    });
  } catch (err) {
    ps = { status: false, message: err.message };
  }

  if (!ps.status) {
    await db.query(
      `UPDATE rider_wallets SET balance=balance+$1, total_withdrawn=total_withdrawn-$1, updated_at=NOW() WHERE user_id=$2`,
      [amt, req.user.id]
    );
    await db.query(`UPDATE payouts SET status='failed', failure_reason=$1 WHERE id=$2`,
      [ps.message || 'transfer failed', payout.id]);
    return res.status(502).json({ success: false, error: ps.message || 'Payout transfer failed' });
  }

  await db.query(`UPDATE payouts SET status='processing', paystack_transfer_code=$1 WHERE id=$2`,
    [ps.data.transfer_code, payout.id]);

  res.status(201).json({
    success: true,
    payout: { ...payout, status: 'processing', paystack_transfer_code: ps.data.transfer_code },
  });
});

exports.listPayouts = asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT * FROM payouts WHERE rider_id=$1 ORDER BY created_at DESC LIMIT 50`, [req.user.id]
  );
  res.json({ success: true, payouts: rows });
});

// ── Paystack transfer webhook (raw body + HMAC, idempotent) ────
exports.transferWebhook = asyncHandler(async (req, res) => {
  const raw = Buffer.isBuffer(req.body)
    ? req.body.toString('utf8')
    : (typeof req.body === 'string' ? req.body : JSON.stringify(req.body));

  const hash = crypto.createHmac('sha512', process.env.PAYSTACK_SECRET_KEY).update(raw).digest('hex');
  if (hash !== req.headers['x-paystack-signature'])
    return res.status(400).json({ error: 'Invalid signature' });

  let parsed;
  try { parsed = JSON.parse(raw); } catch { return res.status(400).json({ error: 'Invalid JSON payload' }); }

  const { event, data } = parsed;
  const code = data && data.transfer_code;
  if (!code) return res.sendStatus(200);

  if (event === 'transfer.success') {
    const { rows } = await db.query(`SELECT * FROM payouts WHERE paystack_transfer_code=$1`, [code]);
    if (!rows.length) return res.sendStatus(200);
    if (rows[0].status === 'paid') return res.sendStatus(200); // idempotent

    await db.query(`UPDATE payouts SET status='paid', settled_at=NOW() WHERE id=$1`, [rows[0].id]);
    await notify(rows[0].rider_id, {
      title: '💸 Payout Sent',
      body: `Your GHS ${rows[0].amount} payout has been sent.`,
      data: { type: 'payout_paid', payout_id: rows[0].id },
    });
    emitToUser(rows[0].rider_id, 'payout:update', { payout_id: rows[0].id, status: 'paid' });
    return res.sendStatus(200);
  }

  if (event === 'transfer.failed' || event === 'transfer.reversed') {
    const newStatus = event === 'transfer.failed' ? 'failed' : 'reversed';
    const { rows } = await db.query(`SELECT * FROM payouts WHERE paystack_transfer_code=$1`, [code]);
    if (!rows.length) return res.sendStatus(200);
    if (['failed', 'reversed'].includes(rows[0].status)) return res.sendStatus(200); // idempotent

    // Refund the debited amount back to the wallet.
    await db.query(
      `UPDATE rider_wallets SET balance=balance+$1, total_withdrawn=total_withdrawn-$1, updated_at=NOW() WHERE user_id=$2`,
      [rows[0].amount, rows[0].rider_id]
    );
    await db.query(`UPDATE payouts SET status=$1, failure_reason=$2 WHERE id=$3`, [newStatus, event, rows[0].id]);
    await notify(rows[0].rider_id, {
      title: '⚠️ Payout Failed',
      body: `Your GHS ${rows[0].amount} payout failed and was refunded to your wallet.`,
      data: { type: 'payout_failed', payout_id: rows[0].id },
    });
    emitToUser(rows[0].rider_id, 'payout:update', { payout_id: rows[0].id, status: newStatus });
    return res.sendStatus(200);
  }

  res.sendStatus(200);
});
