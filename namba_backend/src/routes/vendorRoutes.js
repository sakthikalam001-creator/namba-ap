const express = require('express');
const { getNearbyVendors, createVendor, updateVendorStatus } = require('../controllers/vendorController');
const { protect } = require('../middlewares/auth');

const router = express.Router();

router.route('/nearby').get(getNearbyVendors);
router.route('/').post(protect, createVendor);
router.route('/:id/status').put(protect, updateVendorStatus);

module.exports = router;
