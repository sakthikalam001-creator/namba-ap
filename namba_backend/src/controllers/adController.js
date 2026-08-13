const AdBanner = require('../models/AdBanner');
const Vendor = require('../models/Vendor');

// @desc    Get all active ad banners (Public for Customer App)
// @route   GET /api/v1/ads
// @access  Public
exports.getActiveAds = async (req, res, next) => {
  try {
    const { category } = req.query;
    let query = { status: 'Active' };

    if (category && category !== 'ALL') {
      query.$or = [{ targetCategory: 'ALL' }, { targetCategory: category }];
    }

    const ads = await AdBanner.find(query)
      .populate('vendor', 'storeName category logo address rating ratingCount')
      .sort('-createdAt')
      .lean();

    res.status(200).json({
      success: true,
      count: ads.length,
      data: ads,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Get ads for a specific vendor
// @route   GET /api/v1/ads/vendor/:vendorId
// @access  Public
exports.getVendorAds = async (req, res, next) => {
  try {
    const { vendorId } = req.params;
    const ads = await AdBanner.find({ vendor: vendorId }).sort('-createdAt');

    // Also get vendor permission status
    const vendor = await Vendor.findById(vendorId).select('canRunAds storeName');

    res.status(200).json({
      success: true,
      canRunAds: vendor ? (vendor.canRunAds || false) : false,
      count: ads.length,
      data: ads,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Create a new ad banner (Vendor App / Admin)
// @route   POST /api/v1/ads
// @access  Public / Private
exports.createAd = async (req, res, next) => {
  try {
    const { vendorId, title, subtitle, imageUrl, targetCategory, position } = req.body;

    if (!vendorId) {
      return res.status(400).json({ success: false, message: 'Vendor ID is required' });
    }

    const vendor = await Vendor.findById(vendorId);
    if (!vendor) {
      return res.status(404).json({ success: false, message: 'Vendor not found' });
    }

    // Verify vendor has permission to run ads
    if (!vendor.canRunAds) {
      return res.status(403).json({
        success: false,
        message: 'Your store does not have permission to run In-App Ads. Please contact Administration to enable Ad Campaigns.',
      });
    }

    const ad = await AdBanner.create({
      vendor: vendorId,
      vendorName: vendor.storeName || 'Featured Store',
      title: title || `${vendor.storeName} Special Banner`,
      subtitle: subtitle || 'Exclusive Deals & Discounts',
      imageUrl: imageUrl || vendor.banner || vendor.logo || '',
      targetCategory: targetCategory || vendor.category || 'ALL',
      position: position || 'HomeCarousel',
      status: 'Active',
      endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // Default 30 days
    });

    res.status(201).json({
      success: true,
      data: ad,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Update an ad banner
// @route   PUT /api/v1/ads/:id
// @access  Public / Private
exports.updateAd = async (req, res, next) => {
  try {
    const ad = await AdBanner.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!ad) {
      return res.status(404).json({ success: false, message: 'Ad banner not found' });
    }

    res.status(200).json({
      success: true,
      data: ad,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Delete an ad banner
// @route   DELETE /api/v1/ads/:id
// @access  Public / Private
exports.deleteAd = async (req, res, next) => {
  try {
    const ad = await AdBanner.findByIdAndDelete(req.params.id);

    if (!ad) {
      return res.status(404).json({ success: false, message: 'Ad banner not found' });
    }

    res.status(200).json({
      success: true,
      data: {},
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Track click on an ad
// @route   POST /api/v1/ads/:id/click
// @access  Public
exports.trackAdClick = async (req, res, next) => {
  try {
    const ad = await AdBanner.findByIdAndUpdate(req.params.id, {
      $inc: { clickCount: 1 },
    }, { new: true });

    res.status(200).json({
      success: true,
      data: ad,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Admin Toggle Vendor Ad Permission (canRunAds)
// @route   PUT /api/v1/vendors/:id/ads-permission
// @access  Admin
exports.toggleVendorAdPermission = async (req, res, next) => {
  try {
    const { canRunAds } = req.body;
    const { id } = req.params;

    const vendor = await Vendor.findByIdAndUpdate(id, {
      canRunAds: !!canRunAds,
    }, { new: true });

    if (!vendor) {
      return res.status(404).json({ success: false, message: 'Vendor not found' });
    }

    res.status(200).json({
      success: true,
      canRunAds: vendor.canRunAds,
      message: `In-App Ads permission ${vendor.canRunAds ? 'GRANTED' : 'REVOKED'} for ${vendor.storeName}`,
    });
  } catch (err) {
    next(err);
  }
};
