const router = require('express').Router();
const ctrl   = require('../controllers/adminController');
const { auth } = require('../middleware/auth');

const adminOnly = auth(['admin']);

router.get('/health',                    adminOnly, ctrl.getHealth);
router.get('/dashboard',                 adminOnly, ctrl.getDashboard);
router.get('/riders',                    adminOnly, ctrl.listRiders);
router.patch('/riders/:rider_id/review', adminOnly, ctrl.reviewRider);
router.get('/orders',                    adminOnly, ctrl.listOrders);
router.get('/disputes',                  adminOnly, ctrl.listDisputes);
router.patch('/disputes/:dispute_id',    adminOnly, ctrl.resolveDispute);
router.get('/analytics',                 adminOnly, ctrl.getAnalytics);
router.get('/pricing',                   adminOnly, ctrl.getPricing);
router.patch('/pricing',                 adminOnly, ctrl.updatePricing);

module.exports = router;
