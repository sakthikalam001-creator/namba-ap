const Offer = require('../models/Offer');

// @desc    Get all active offers
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

// @desc    Create an offer (Internal/Mock for now)
// @route   POST /api/v1/offers
// @access  Private
exports.createOffer = async (req, res, next) => {
  try {
    const offer = await Offer.create(req.body);

    res.status(201).json({
      success: true,
      data: offer,
    });
  } catch (err) {
    next(err);
  }
};
