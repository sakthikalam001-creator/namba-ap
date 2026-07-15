const express = require('express');
const { getOffers, createOffer } = require('../controllers/offerController');

const router = express.Router();

router.get('/', getOffers);
router.post('/', createOffer);

module.exports = router;
