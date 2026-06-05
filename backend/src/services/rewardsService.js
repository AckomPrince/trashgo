const cron = require('node-cron');
const db   = require('../config/database');
const { notify } = require('./notificationService');
const logger = require('../config/logger');

/**
 * Award points to a customer after a completed order.
 */
async function awardPoints(customerId, orderId, points) {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    // Upsert wallet
    await client.query(
      `INSERT INTO points_wallets (user_id, balance, total_earned)
       VALUES ($1, $2, $2)
       ON CONFLICT (user_id) DO UPDATE
         SET balance = points_wallets.balance + $2,
             total_earned = points_wallets.total_earned + $2,
             updated_at = NOW()`,
      [customerId, points]
    );

    const { rows: w } = await client.query(
      'SELECT balance FROM points_wallets WHERE user_id=$1', [customerId]
    );

    await client.query(
      `INSERT INTO points_transactions (user_id, order_id, type, amount, balance_after, note)
       VALUES ($1,$2,'earned',$3,$4,'Pickup completed')`,
      [customerId, orderId, points, w[0].balance]
    );

    await client.query(
      `UPDATE orders SET points_awarded=$1, points_finalized=TRUE WHERE id=$2`,
      [points, orderId]
    );

    await client.query('COMMIT');

    await notify(customerId, {
      title: '🎉 Points Earned!',
      body: `You earned ${points} points for your pickup. Keep it up!`,
      data: { type: 'points_earned', points: String(points) },
    });

    return w[0].balance;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Process a cash redemption request.
 */
async function requestRedemption(userId, { points, payoutMethod, payoutAccount }) {
  const minPoints = parseInt(process.env.MIN_REDEMPTION_POINTS || '500');
  if (points < minPoints) throw new Error(`Minimum redemption is ${minPoints} points`);

  const { rows: w } = await db.query('SELECT balance FROM points_wallets WHERE user_id=$1', [userId]);
  if (!w.length || w[0].balance < points)
    throw new Error('Insufficient points balance');

  const rate     = parseInt(process.env.REDEMPTION_RATE || '100');
  const cashValue = parseFloat((points / rate).toFixed(2));

  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    // Deduct points
    await client.query(
      `UPDATE points_wallets
       SET balance = balance - $1, total_redeemed = total_redeemed + $1, updated_at=NOW()
       WHERE user_id=$2`,
      [points, userId]
    );

    const { rows: w2 } = await client.query('SELECT balance FROM points_wallets WHERE user_id=$1', [userId]);

    await client.query(
      `INSERT INTO points_transactions (user_id, type, amount, balance_after, note)
       VALUES ($1,'redeemed',$2,$3,'Cash redemption request')`,
      [userId, -points, w2[0].balance]
    );

    const { rows: [redemption] } = await client.query(
      `INSERT INTO redemptions (user_id, points_redeemed, cash_value, payout_method, payout_account)
       VALUES ($1,$2,$3,$4,$5) RETURNING id`,
      [userId, points, cashValue, payoutMethod, payoutAccount]
    );

    await client.query('COMMIT');

    await notify(userId, {
      title: '💵 Redemption Requested',
      body: `Your ${points} pts = GHS ${cashValue} will be processed within 3 business days.`,
      data: { type: 'redemption_requested' },
    });

    return { redemption_id: redemption.id, cash_value: cashValue };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Cron: expire points for inactive accounts (12 months).
 * Runs every day at 02:00.
 */
function scheduleRewardExpiry() {
  cron.schedule('0 2 * * *', async () => {
    try {
      logger.info('Running points expiry cron...');
      const { rows } = await db.query(
        `SELECT pw.user_id, pw.balance
         FROM points_wallets pw
         JOIN users u ON u.id = pw.user_id
         WHERE pw.balance > 0
           AND u.updated_at < NOW() - INTERVAL '12 months'`
      );

      for (const row of rows) {
        await db.query(
          `UPDATE points_wallets SET balance=0, updated_at=NOW() WHERE user_id=$1`,
          [row.user_id]
        );
        await db.query(
          `INSERT INTO points_transactions (user_id, type, amount, balance_after, note)
           VALUES ($1,'expired',$2,0,'12 months inactivity')`,
          [row.user_id, -row.balance]
        );
      }
      logger.info(`Points expired for ${rows.length} accounts`);
    } catch (err) {
      logger.error('Points expiry cron error:', err.message);
    }
  });
}

module.exports = { awardPoints, requestRedemption, scheduleRewardExpiry };
