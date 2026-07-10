const express = require('express');
const router  = express.Router();
const ctrl    = require('../controllers/paymentController');
const payout  = require('../controllers/payoutController');
const { auth } = require('../middleware/auth');

// Raw body needed for Paystack webhook signature check.
// FIX: keep req.body as the raw Buffer and let the controller verify the
// signature against the exact bytes before parsing. The previous inline
// JSON.parse ran against an already-parsed object (global json parser),
// producing JSON.parse("[object Object]") and a 500 on every webhook.
router.post('/webhook', express.raw({ type: 'application/json' }), ctrl.paystackWebhook);
// Transfer (payout) webhook — same raw-body + HMAC pattern. Epic P (#8).
router.post('/transfer-webhook', express.raw({ type: 'application/json' }), payout.transferWebhook);
router.post('/initialize',    auth(['customer']), ctrl.initializePayment);
router.get('/verify/:reference', auth(),          ctrl.verifyPayment);

module.exports = router;
