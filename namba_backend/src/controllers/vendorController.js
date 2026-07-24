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
