const express = require('express');
const { getVendorReviews, createReview } = require('../controllers/reviewController');

const router = express.Router();

router.get('/vendor/:vendorId', getVendorReviews);
router.post('/', createReview);

module.exports = router;
