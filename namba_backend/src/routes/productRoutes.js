const express = require('express');
const { 
  getVendorProducts, 
  createProduct, 
  updateProduct, 
  deleteProduct 
} = require('../controllers/productController');
const { protect } = require('../middlewares/auth');

const router = express.Router();

// ✅ Specific routes FIRST (before /:id which is a catch-all)
router.route('/vendor/:vendorId')
  .get(getVendorProducts);

router.route('/')
  .post(protect, createProduct);

router.route('/:id')
  .put(protect, updateProduct)
  .delete(protect, deleteProduct);

module.exports = router;
