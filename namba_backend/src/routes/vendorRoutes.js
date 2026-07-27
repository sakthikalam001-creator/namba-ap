const express = require('express');
const { getNearbyVendors, createVendor, updateVendorStatus, registerPushToken } = require('../controllers/vendorController');
const { protect } = require('../middlewares/auth');

const router = express.Router();

router.route('/nearby').get(getNearbyVendors);
router.route('/').post(protect, createVendor);
router.route('/:id/status').put(protect, updateVendorStatus);
router.route('/:id/push-token').put(protect, registerPushToken);

module.exports = router;
