const Offer = require('../models/Offer');

// @desc    Get all active offers (Public for Customer App)
// @route   GET /api/v1/offers
// @access  Public
exports.getOffers = async (req, res, next) => {
  try {
    const offers = await Offer.find({ isActive: true })
      .populate('vendor', 'storeName category logo')
      .sort('-createdAt');

    res.status(200).json({
      success: true,
      count: offers.length,
      data: offers,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Get offers for a specific vendor
// @route   GET /api/v1/offers/vendor/:vendorId
// @access  Public
exports.getVendorOffers = async (req, res, next) => {
  try {
    const { vendorId } = req.params;
    const offers = await Offer.find({ vendor: vendorId }).sort('-createdAt');

    res.status(200).json({
      success: true,
      count: offers.length,
      data: offers,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Create an offer / coupon
// @route   POST /api/v1/offers
// @access  Public / Private
exports.createOffer = async (req, res, next) => {
  try {
    const { code, title, description, discountType, discountValue, minOrderAmount, vendorId, expiresAt } = req.body;

    const offer = await Offer.create({
      vendor: vendorId || req.body.vendor,
      code: (code || title || 'OFFER').toUpperCase(),
      title: title || code || 'Special Offer',
      description: description || `Get ${discountValue || 10}% OFF`,
      discountType: discountType || 'Percentage',
      discountValue: parseFloat(discountValue) || 10,
      minOrderAmount: parseFloat(minOrderAmount) || 0,
      expiresAt: expiresAt || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // Default 30 days
      isActive: true,
    });

    res.status(201).json({
      success: true,
      data: offer,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Update / toggle an offer
// @route   PUT /api/v1/offers/:id
// @access  Public / Private
exports.updateOffer = async (req, res, next) => {
  try {
    const offer = await Offer.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!offer) {
      return res.status(404).json({ success: false, message: 'Offer not found' });
    }

    res.status(200).json({
      success: true,
      data: offer,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Delete an offer
// @route   DELETE /api/v1/offers/:id
// @access  Public / Private
exports.deleteOffer = async (req, res, next) => {
  try {
    const offer = await Offer.findByIdAndDelete(req.params.id);

    if (!offer) {
      return res.status(404).json({ success: false, message: 'Offer not found' });
    }

    res.status(200).json({
      success: true,
      data: {},
    });
  } catch (err) {
    next(err);
  }
};
