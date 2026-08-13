const express = require('express');
const {
  getOffers,
  getVendorOffers,
  createOffer,
  updateOffer,
  deleteOffer,
} = require('../controllers/offerController');

const router = express.Router();

router.get('/', getOffers);
router.get('/vendor/:vendorId', getVendorOffers);
router.post('/', createOffer);
router.put('/:id', updateOffer);
router.delete('/:id', deleteOffer);

module.exports = router;
