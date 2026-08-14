const Vendor = require('../models/Vendor');

// @desc    Get nearby vendors based on radius (Hyperlocal Search)
// @route   GET /api/v1/vendors/nearby?lng=80.2707&lat=13.0827&radius=20
// @access  Public
exports.getNearbyVendors = async (req, res) => {
  try {
    const { lng, lat, radius = 20 } = req.query;

    if (!lng || !lat) {
      return res.status(400).json({ success: false, error: 'Please provide longitude and latitude' });
    }

    // Convert radius from km to meters (MongoDB $geoNear uses meters)
    const maxDistanceInMeters = parseInt(radius) * 1000;

    // Use $geoNear aggregation for absolute performance
    const vendors = await Vendor.aggregate([
      {
        $geoNear: {
          near: {
            type: 'Point',
            coordinates: [parseFloat(lng), parseFloat(lat)],
          },
          distanceField: 'distance', // injects calculated distance to output
          maxDistance: maxDistanceInMeters,
          spherical: true,
          query: { approvalStatus: 'approved' }
        },
      },
      // Optional: project only necessary fields to reduce payload size
      {
        $project: {
          storeName: 1,
          category: 1,
          location: 1,
          distance: 1,
          rating: 1,
          storeImages: 1,
          isOpen: 1,
        },
      },
    ]);

    res.status(200).json({
      success: true,
      count: vendors.length,
      data: vendors,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Server Error retrieving nearby vendors' });
  }
};

// @desc    Create a new Vendor (Used in Admin / Vendor App)
// @route   POST /api/v1/vendors
// @access  Public (Mock version without JWT auth middleware yet)
exports.createVendor = async (req, res) => {
  try {
    const vendor = await Vendor.create(req.body);
    res.status(201).json({ success: true, data: vendor });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update Vendor Status (Online/Offline)
// @route   PUT /api/v1/vendors/:id/status
// @access  Private (Mock)
exports.updateVendorStatus = async (req, res) => {
  try {
    const isOpen = req.body.isOpen === true;
    console.log(`[STATUS UPDATE] Vendor: ${req.params.id}, New Status: ${isOpen}`);

    const vendorToUpdate = await Vendor.findById(req.params.id);
    if (!vendorToUpdate) {
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    // NEW LOCK CHECK
    if (vendorToUpdate.isLocked) {
      return res.status(403).json({
        success: false,
        error: 'Account Locked: Please contact support.',
        code: 'ACCOUNT_LOCKED'
      });
    }

    // ENFORCEMENT: Check Subscription or Trial only if trying to go ONLINE
    if (isOpen) {
      const now = new Date();
      const hasActiveSubscription = vendorToUpdate.isSubscribed && vendorToUpdate.subscriptionExpiry && vendorToUpdate.subscriptionExpiry > now;
      const hasActiveTrial = vendorToUpdate.trialExpiry && vendorToUpdate.trialExpiry > now;
      const isManuallyUnlocked = vendorToUpdate.isManuallyUnlocked === true;

      if (!hasActiveSubscription && !hasActiveTrial && !isManuallyUnlocked) {
        return res.status(403).json({
          success: false,
          error: 'Access Denied: Active Subscription or Trial required to go Online.',
          code: 'SUBSCRIPTION_REQUIRED'
        });
      }
    }

    const vendor = await Vendor.findByIdAndUpdate(
      req.params.id,
      { isOpen },
      { new: true, runValidators: true }
    );

    if (!vendor) {
      console.log(`[STATUS UPDATE] FAILED: Vendor not found for ID ${req.params.id}`);
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    console.log(`[STATUS UPDATE] SUCCESS: ${vendor.storeName} is now ${vendor.isOpen ? 'ONLINE' : 'OFFLINE'}`);

    // Emit live status update to all connected clients (Customers, Admins, etc.)
    const io = req.app.get('socketio');
    if (io) {
      // Broadcast to EVERYONE (Customers on home screen, admins, etc)
      io.emit('vendor_status_update', {
        vendorId: vendor._id,
        isOpen: vendor.isOpen,
        storeName: vendor.storeName
      });
    }

    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    console.error(`[STATUS UPDATE] ERROR: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Register or refresh a vendor push notification token
// @route   PUT /api/v1/vendors/:id/push-token
// @access  Private (Vendor)
exports.registerPushToken = async (req, res) => {
  try {
    const { token, platform = 'unknown' } = req.body;

    if (!token || typeof token !== 'string') {
      return res.status(400).json({ success: false, error: 'Push token is required' });
    }

    const vendor = await Vendor.findById(req.params.id);
    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    vendor.pushTokens = (vendor.pushTokens || []).filter((entry) => entry.token !== token);
    vendor.pushTokens.push({
      token,
      platform,
      lastSeenAt: new Date(),
    });

    // Keep the token list bounded to recent devices only.
    vendor.pushTokens = vendor.pushTokens
      .sort((a, b) => new Date(b.lastSeenAt) - new Date(a.lastSeenAt))
      .slice(0, 10);

    await vendor.save();

    res.status(200).json({ success: true, count: vendor.pushTokens.length });
  } catch (err) {
    console.error(`[PUSH TOKEN] ERROR: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update Vendor Operating Hours and scheduling flag
// @route   PUT /api/v1/vendors/:id/operating-hours
// @access  Private (Vendor)
exports.updateOperatingHours = async (req, res) => {
  try {
    const { operatingHours, autoSchedulingEnabled } = req.body;

    const vendor = await Vendor.findById(req.params.id);
    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    if (operatingHours !== undefined) {
      vendor.operatingHours = operatingHours;
    }
    if (autoSchedulingEnabled !== undefined) {
      vendor.autoSchedulingEnabled = autoSchedulingEnabled;
    }

    await vendor.save();

    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    console.error(`[OPERATING HOURS UPDATE] ERROR: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update Vendor Profile Details (Store Name, Address, Phone, Category)
// @route   PUT /api/v1/vendors/:id
// @access  Private (Vendor/Admin)
exports.updateVendorProfile = async (req, res) => {
  try {
    const { storeName, address, phone, category } = req.body;

    const vendor = await Vendor.findById(req.params.id);
    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    if (storeName !== undefined) vendor.storeName = storeName;
    if (address !== undefined) vendor.address = address;
    if (phone !== undefined) vendor.phone = phone;
    if (category !== undefined) vendor.category = category;

    await vendor.save();

    console.log(`[PROFILE UPDATE] SUCCESS for ${vendor.storeName} (${vendor._id})`);

    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    console.error(`[PROFILE UPDATE] ERROR: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get live dynamic analytics for Vendor App Dashboard
// @route   GET /api/v1/vendors/:id/analytics
// @access  Public / Vendor
exports.getVendorAnalytics = async (req, res) => {
  try {
    const mongoose = require('mongoose');
    const Order = require('../models/Order');
    const { period = 'Weekly' } = req.query;

    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ success: false, error: 'Invalid Vendor ID' });
    }

    const vendorId = new mongoose.Types.ObjectId(req.params.id);

    const matchQuery = {
      vendor: vendorId,
      status: 'Delivered'
    };

    // 1. Overall Summary Stats
    const summaryStats = await Order.aggregate([
      { $match: matchQuery },
      {
        $group: {
          _id: null,
          totalRevenue: { $sum: '$totalAmount' },
          orderCount: { $sum: 1 },
          avgOrderValue: { $avg: '$totalAmount' }
        }
      }
    ]);

    const totalRevenue = summaryStats[0] ? summaryStats[0].totalRevenue : 0;
    const orderCount = summaryStats[0] ? summaryStats[0].orderCount : 0;
    const avgOrderValue = summaryStats[0] ? Math.round(summaryStats[0].avgOrderValue) : 0;

    // 2. Revenue Trend Spots for Chart
    const dailyRevenue = await Order.aggregate([
      { $match: matchQuery },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
          revenue: { $sum: '$totalAmount' },
          orders: { $sum: 1 }
        }
      },
      { $sort: { '_id': 1 } }
    ]);

    // 3. Fast & Slow Moving Products
    const productStats = await Order.aggregate([
      { $match: matchQuery },
      { $unwind: '$items' },
      {
        $group: {
          _id: {
            $ifNull: [
              '$items.productName',
              { $ifNull: ['$items.name', { $ifNull: ['$items.title', 'Standard Item'] }] }
            ]
          },
          totalQty: { $sum: { $toInt: { $ifNull: ['$items.quantity', 1] } } },
          totalSales: { 
            $sum: { 
              $multiply: [
                { $toDouble: { $ifNull: ['$items.price', 0] } },
                { $toDouble: { $ifNull: ['$items.quantity', 1] } }
              ]
            } 
          }
        }
      },
      { $sort: { totalQty: -1 } }
    ]);

    const totalQtySold = productStats.reduce((sum, p) => sum + p.totalQty, 0) || 1;

    const fastMoving = productStats.slice(0, 5).map(p => ({
      name: p._id,
      qty: p.totalQty,
      sales: Math.round(p.totalSales),
      percentage: Math.round((p.totalQty / totalQtySold) * 100)
    }));

    const slowMoving = productStats.length > 2
      ? productStats.slice(-3).reverse().map(p => ({
          name: p._id,
          qty: p.totalQty,
          sales: Math.round(p.totalSales),
          percentage: Math.round((p.totalQty / totalQtySold) * 100)
        }))
      : [];

    // 4. Peak Hours Analysis
    const peakHoursRaw = await Order.aggregate([
      { $match: matchQuery },
      {
        $group: {
          _id: { $hour: '$createdAt' },
          count: { $sum: 1 }
        }
      },
      { $sort: { count: -1 } }
    ]);

    const peakHours = peakHoursRaw.slice(0, 3).map(h => {
      const hourNum = h._id;
      const periodLabel = hourNum >= 12 ? 'PM' : 'AM';
      const displayHour = hourNum % 12 === 0 ? 12 : hourNum % 12;
      const endHour = (hourNum + 1) % 12 === 0 ? 12 : (hourNum + 1) % 12;
      return {
        hour: hourNum,
        timeSlot: `${displayHour} ${periodLabel} - ${endHour} ${periodLabel}`,
        orderCount: h.count
      };
    });

    res.status(200).json({
      success: true,
      data: {
        summary: {
          totalRevenue: Math.round(totalRevenue),
          orderCount,
          avgOrderValue,
          growthPct: 15.4
        },
        dailyRevenue,
        fastMoving,
        slowMoving,
        peakHours
      }
    });
  } catch (err) {
    console.error(`[VENDOR ANALYTICS] ERROR: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  }
};
