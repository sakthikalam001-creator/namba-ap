const express = require('express');
const { 
  getNearbyVendors, 
  createVendor, 
  updateVendorStatus, 
  registerPushToken, 
  updateOperatingHours, 
  updateVendorProfile, 
  getVendorAnalytics,
  getVendorPayouts,
  requestVendorPayout
} = require('../controllers/vendorController');
const { protect } = require('../middlewares/auth');
const { registerVendor } = require('../controllers/authController');

const router = express.Router();

router.post('/register', registerVendor);
router.route('/nearby').get(getNearbyVendors);
router.route('/').post(protect, createVendor);
router.route('/:id').put(updateVendorProfile);
router.route('/:id/analytics').get(getVendorAnalytics);
router.route('/:id/payouts').get(getVendorPayouts);
router.route('/:id/request-payout').post(requestVendorPayout);
router.route('/:id/status').put(updateVendorStatus);
router.route('/:id/operating-hours').put(updateOperatingHours);
router.route('/:id/push-token').post(registerPushToken).put(registerPushToken);

module.exports = router;

