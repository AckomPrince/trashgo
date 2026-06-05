const router = require('express').Router();
const ctrl   = require('../controllers/authController');
const { auth } = require('../middleware/auth');

router.post('/register/customer', ctrl.registerCustomer);
router.post('/register/rider',    ctrl.registerRider);
router.post('/login',             ctrl.login);
router.post('/refresh',           ctrl.refreshToken);
router.post('/logout',            ctrl.logout);           // revokes refresh token
router.get( '/me',                auth(), ctrl.getMe);
router.patch('/profile',          auth(), ctrl.updateProfile);
router.patch('/fcm-token',        auth(), ctrl.updateFcmToken);

module.exports = router;
