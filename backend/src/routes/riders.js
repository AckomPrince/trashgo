const router = require('express').Router();
const ctrl   = require('../controllers/riderController');
const { auth } = require('../middleware/auth');

router.patch('/availability', auth(['rider']), ctrl.setAvailability);
router.patch('/location',     auth(['rider']), ctrl.updateLocation);
router.get('/wallet',         auth(['rider']), ctrl.getWallet);
router.get('/earnings',       auth(['rider']), ctrl.getEarnings);
router.get('/profile',        auth(['rider']), ctrl.getProfile);
router.get('/onboarding',     auth(['rider']), ctrl.getOnboarding);
router.patch('/documents',    auth(['rider']), ctrl.uploadDocument);
router.get('/nearby-orders',  auth(['rider']), ctrl.getNearbyOrders);
router.get('/incentives',     auth(['rider']), ctrl.getIncentives);
router.post('/sos',           auth(['rider']), ctrl.sos);

module.exports = router;
