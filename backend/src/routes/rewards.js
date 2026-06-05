const router = require('express').Router();
const db     = require('../config/database');
const { auth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errorHandler');
const { requestRedemption } = require('../services/rewardsService');

router.get('/wallet', auth(['customer']), asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    'SELECT * FROM points_wallets WHERE user_id=$1', [req.user.id]
  );
  res.json({ success: true, wallet: rows[0] || { balance: 0, total_earned: 0, total_redeemed: 0 } });
}));

router.get('/transactions', auth(['customer']), asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    `SELECT pt.*, o.pickup_address, o.waste_type
     FROM points_transactions pt
     LEFT JOIN orders o ON o.id=pt.order_id
     WHERE pt.user_id=$1 ORDER BY pt.created_at DESC LIMIT 50`,
    [req.user.id]
  );
  res.json({ success: true, transactions: rows });
}));

router.post('/redeem', auth(['customer']), asyncHandler(async (req, res) => {
  const { points, payout_method, payout_account } = req.body;
  if (!points || !payout_method || !payout_account)
    return res.status(400).json({ success: false, error: 'points, payout_method, payout_account required' });

  const result = await requestRedemption(req.user.id, {
    points: parseInt(points), payoutMethod: payout_method, payoutAccount: payout_account,
  });
  res.json({ success: true, ...result });
}));

router.get('/redemptions', auth(['customer']), asyncHandler(async (req, res) => {
  const { rows } = await db.query(
    'SELECT * FROM redemptions WHERE user_id=$1 ORDER BY requested_at DESC',
    [req.user.id]
  );
  res.json({ success: true, redemptions: rows });
}));

module.exports = router;
