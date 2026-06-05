const express = require('express');
const router  = express.Router();
const ctrl    = require('../controllers/paymentController');
const { auth } = require('../middleware/auth');

// Raw body needed for Paystack webhook signature check
router.post('/webhook', express.raw({ type: 'application/json' }),
  (req, res, next) => { req.body = JSON.parse(req.body); next(); },
  ctrl.paystackWebhook
);
router.post('/initialize',    auth(['customer']), ctrl.initializePayment);
router.get('/verify/:reference', auth(),          ctrl.verifyPayment);

module.exports = router;
