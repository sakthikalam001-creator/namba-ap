const Product = require('../models/Product');

// @desc    Get all products for a vendor
// @route   GET /api/v1/products/vendor/:vendorId
// @access  Public
exports.getVendorProducts = async (req, res, next) => {
  try {
    const products = await Product.find({ vendor: req.params.vendorId });
    res.status(200).json({
      success: true,
      count: products.length,
      data: products,
    });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};
const Vendor = require('../models/Vendor');

// @desc    Create a product
// @route   POST /api/v1/products
// @access  Private (Vendor)
exports.createProduct = async (req, res, next) => {
  try {
    const vendorObj = await Vendor.findById(req.body.vendor);
    if (vendorObj && vendorObj.isLocked) {
      return res.status(403).json({
        success: false,
        error: 'Account Locked: Please contact support.',
      });
    }

    const product = await Product.create(req.body);
    res.status(201).json({
      success: true,
      data: product,
    });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// @desc    Update a product
// @route   PUT /api/v1/products/:id
// @access  Private (Vendor)
exports.updateProduct = async (req, res, next) => {
  try {
    let product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    const vendorObj = await Vendor.findById(product.vendor);
    if (vendorObj && vendorObj.isLocked) {
      return res.status(403).json({
        success: false,
        error: 'Account Locked: Please contact support.',
      });
    }

    product = await Product.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    res.status(200).json({
      success: true,
      data: product,
    });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// @desc    Delete a product
// @route   DELETE /api/v1/products/:id
// @access  Private (Vendor)
exports.deleteProduct = async (req, res, next) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    const vendorObj = await Vendor.findById(product.vendor);
    if (vendorObj && vendorObj.isLocked) {
      return res.status(403).json({
        success: false,
        error: 'Account Locked: Please contact support.',
      });
    }

    await product.deleteOne();
    res.status(200).json({
      success: true,
      data: {},
    });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};
