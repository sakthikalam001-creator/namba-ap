const Order = require('../models/Order');
const User = require('../models/User');

// @desc    Get live heatmap data (orders and riders)
// @route   GET /api/v1/admin/heatmap
// @access  Public (for dev simplicity, restricted via middleware if needed)
exports.getLiveHeatmapData = async (req, res) => {
  try {
    // 1. Fetch active order locations (Pending, Accepted, Preparing, Ready)
    const activeOrders = await Order.find({
      status: { $in: ['Pending', 'Accepted', 'Preparing', 'Ready'] }
    }).select('deliveryCoordinates');

    const orderHeatmap = activeOrders.map(o => ({
      lat: o.deliveryCoordinates.coordinates[1],
      lng: o.deliveryCoordinates.coordinates[0],
      weight: 1.0
    }));

    // 2. Fetch online driver locations
    const onlineDrivers = await User.find({
      role: 'driver',
      isOnline: true
    }).select('lastLocation name');

    const riderHeatmap = onlineDrivers.map(d => ({
      lat: d.lastLocation.coordinates[1],
      lng: d.lastLocation.coordinates[0],
      name: d.name
    }));

    res.status(200).json({
      success: true,
      data: {
        orders: orderHeatmap,
        riders: riderHeatmap
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};
