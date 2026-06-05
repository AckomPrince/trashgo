const router = require('express').Router();
const ctrl   = require('../controllers/riderController');
const { auth } = require('../middleware/auth');

router.patch('/availability', auth(['rider']), ctrl.setAvailability);
router.patch('/location',     auth(['rider']), ctrl.updateLocation);
router.get('/earnings',       auth(['rider']), ctrl.getEarnings);
router.get('/profile',        auth(['rider']), ctrl.getProfile);
router.patch('/documents',    auth(['rider']), ctrl.uploadDocument);
router.get('/nearby-orders',  auth(['rider']), ctrl.getNearbyOrders);

module.exports = router;
