const express = require('express');
const { getNearbyVendors, createVendor, updateVendorStatus, registerPushToken, updateOperatingHours, updateVendorProfile, getVendorAnalytics } = require('../controllers/vendorController');
const { protect } = require('../middlewares/auth');

const router = express.Router();

router.route('/nearby').get(getNearbyVendors);
router.route('/').post(protect, createVendor);
router.route('/:id').put(updateVendorProfile);
router.route('/:id/analytics').get(getVendorAnalytics);
router.route('/:id/status').put(updateVendorStatus);
router.route('/:id/operating-hours').put(updateOperatingHours);
router.route('/:id/push-token').post(registerPushToken).put(registerPushToken);

module.exports = router;
