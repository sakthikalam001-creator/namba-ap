const express = require('express');
const { getVendorReviews, getDriverReviews, createReview } = require('../controllers/reviewController');

const router = express.Router();

router.get('/vendor/:vendorId', getVendorReviews);
router.get('/driver/:driverId', getDriverReviews);
router.post('/', createReview);

module.exports = router;
