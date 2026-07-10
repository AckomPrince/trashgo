const router = require('express').Router();
const ctrl   = require('../controllers/orderController');
const { auth } = require('../middleware/auth');

router.post('/',                   auth(['customer']),         ctrl.createOrder);
router.get('/',                    auth(),                      ctrl.listOrders);
router.get('/:id',                 auth(),                      ctrl.getOrder);
router.post('/:id/accept',         auth(['rider']),             ctrl.acceptOrder);
router.post('/:id/decline',        auth(['rider']),             ctrl.declineOrder);
router.patch('/:id/status',        auth(['rider']),             ctrl.updateStatus);
router.patch('/:id/approve-price', auth(['customer']),         ctrl.approvePrice);
router.patch('/:id/start',         auth(['rider']),             ctrl.startPickup);
router.patch('/:id/complete',      auth(['rider']),             ctrl.completeOrder);
router.patch('/:id/cancel',        auth(['customer']),         ctrl.cancelOrder);
router.post('/:id/rate',           auth(['customer']),         ctrl.rateOrder);
router.post('/:id/rate-rider',     auth(['customer']),         ctrl.rateRider);

module.exports = router;
