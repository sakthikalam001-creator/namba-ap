const express = require('express');
const {
  getActiveAds,
  getVendorAds,
  createAd,
  updateAd,
  deleteAd,
  trackAdClick,
  toggleVendorAdPermission,
} = require('../controllers/adController');

const router = express.Router();

router.get('/', getActiveAds);
router.get('/vendor/:vendorId', getVendorAds);
router.post('/', createAd);
router.put('/:id', updateAd);
router.delete('/:id', deleteAd);
router.post('/:id/click', trackAdClick);
router.put('/vendor/:id/permission', toggleVendorAdPermission);

module.exports = router;
