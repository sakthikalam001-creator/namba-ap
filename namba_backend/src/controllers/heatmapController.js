const Order = require('../models/Order');
const User = require('../models/User');
const Vendor = require('../models/Vendor');
const SystemSettings = require('../models/SystemSettings');

// Helper to extract locality from address string
function extractLocality(address, fallback = 'Central Hub') {
  if (!address || typeof address !== 'string') return fallback;
  const parts = address.split(',').map(s => s.trim()).filter(Boolean);
  if (parts.length >= 2) {
    return parts.slice(0, 2).join(', ');
  }
  return parts[0] || fallback;
}

// @desc    Get live heatmap data and predictive geographic intelligence
// @route   GET /api/v1/admin/heatmap
// @access  Public / Admin
exports.getLiveHeatmapData = async (req, res) => {
  try {
    // 1. Fetch system settings for service center coordinates
    let centerLat = 11.3410;
    let centerLng = 77.7172;
    try {
      const settings = await SystemSettings.findOne();
      if (settings && settings.serviceCenterLat && settings.serviceCenterLng) {
        centerLat = settings.serviceCenterLat;
        centerLng = settings.serviceCenterLng;
      }
    } catch (e) {}

    // 2. Fetch active orders AND recent orders (last 30 days) with vendor details
    const activeStatuses = ['Pending', 'Accepted', 'Confirmed', 'Preparing', 'Ready', 'Assigned', 'HandedOver', 'PickedUp', 'OutForDelivery', 'On The Way'];
    
    const orders = await Order.find({
      $or: [
        { status: { $in: activeStatuses } },
        { createdAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) } }
      ]
    })
    .populate('vendor', 'storeName category location address city')
    .populate('customer', 'name phone')
    .populate('driver', 'name phone vehicleType lastLocation')
    .select('displayId status totalAmount deliveryCoordinates pinnedLat pinnedLng actualPickupLat actualPickupLng deliveryAddress deliveryAddressFormatted createdAt orderType isCustomStore customStoreName vendor driver')
    .lean();

    const orderPoints = [];
    const localityStats = {};
    let sumLat = 0;
    let sumLng = 0;
    let validCoordCount = 0;

    orders.forEach(o => {
      let lat = null;
      let lng = null;

      if (o.deliveryCoordinates && Array.isArray(o.deliveryCoordinates.coordinates) && o.deliveryCoordinates.coordinates.length >= 2) {
        const cLng = Number(o.deliveryCoordinates.coordinates[0]);
        const cLat = Number(o.deliveryCoordinates.coordinates[1]);
        if (!isNaN(cLat) && !isNaN(cLng) && (cLat !== 0 || cLng !== 0)) {
          lat = cLat;
          lng = cLng;
        }
      }

      if (lat === null && o.pinnedLat && o.pinnedLng) {
        lat = Number(o.pinnedLat);
        lng = Number(o.pinnedLng);
      }

      if (lat === null && o.actualPickupLat && o.actualPickupLng) {
        lat = Number(o.actualPickupLat);
        lng = Number(o.actualPickupLng);
      }

      if (lat === null && o.vendor && o.vendor.location && Array.isArray(o.vendor.location.coordinates)) {
        const vLng = Number(o.vendor.location.coordinates[0]);
        const vLat = Number(o.vendor.location.coordinates[1]);
        if (!isNaN(vLat) && !isNaN(vLng) && (vLat !== 0 || vLng !== 0)) {
          lat = vLat;
          lng = vLng;
        }
      }

      const isActive = activeStatuses.includes(o.status);
      const weight = isActive ? 3.0 : 1.0;
      const locality = extractLocality(o.deliveryAddressFormatted || o.deliveryAddress || (o.vendor && o.vendor.address), 'Central Market Zone');

      if (lat !== null && lng !== null) {
        orderPoints.push({
          id: o._id,
          displayId: o.displayId || 'Order',
          lat,
          lng,
          weight,
          status: o.status,
          isActive,
          amount: o.totalAmount || 0,
          storeName: o.vendor ? o.vendor.storeName : (o.customStoreName || 'Local Store'),
          locality,
          createdAt: o.createdAt
        });

        sumLat += lat;
        sumLng += lng;
        validCoordCount++;
      }

      // Aggregate locality stats
      if (!localityStats[locality]) {
        localityStats[locality] = {
          name: locality,
          orderCount: 0,
          activeCount: 0,
          totalRevenue: 0,
          lat: lat || centerLat,
          lng: lng || centerLng,
        };
      }
      localityStats[locality].orderCount++;
      if (isActive) localityStats[locality].activeCount++;
      localityStats[locality].totalRevenue += (o.totalAmount || 0);
      if (lat !== null && lng !== null) {
        localityStats[locality].lat = lat;
        localityStats[locality].lng = lng;
      }
    });

    // 3. Fetch Online & Active Drivers
    const drivers = await User.find({
      role: 'driver',
      $or: [{ isOnline: true }, { driverApprovalStatus: 'approved' }]
    }).select('name phone vehicleType isOnline lastLocation').lean();

    // Check which drivers currently have assigned active orders
    const activeDriverIds = new Set(
      orders.filter(o => activeStatuses.includes(o.status) && o.driver).map(o => String(o.driver._id || o.driver))
    );

    const riderPoints = [];
    const idleRidersByLocality = {};

    drivers.forEach(d => {
      let lat = null;
      let lng = null;

      if (d.lastLocation && Array.isArray(d.lastLocation.coordinates) && d.lastLocation.coordinates.length >= 2) {
        const cLng = Number(d.lastLocation.coordinates[0]);
        const cLat = Number(d.lastLocation.coordinates[1]);
        if (!isNaN(cLat) && !isNaN(cLng) && (cLat !== 0 || cLng !== 0)) {
          lat = cLat;
          lng = cLng;
        }
      }

      // Default close to center if online without coordinates
      if (lat === null && d.isOnline) {
        lat = centerLat;
        lng = centerLng;
      }

      if (lat !== null && lng !== null) {
        const isAssigned = activeDriverIds.has(String(d._id));
        const status = !d.isOnline ? 'Offline' : (isAssigned ? 'On Delivery' : 'Idle / Available');
        
        riderPoints.push({
          id: d._id,
          name: d.name,
          phone: d.phone,
          vehicleType: d.vehicleType || 'bike',
          isOnline: d.isOnline || false,
          isIdle: d.isOnline && !isAssigned,
          status,
          lat,
          lng
        });

        if (d.isOnline) {
          sumLat += lat;
          sumLng += lng;
          validCoordCount++;

          if (!isAssigned) {
            const locKey = `${d.vehicleType ? d.vehicleType.toUpperCase() : 'BIKE'} Station (${lat.toFixed(2)}, ${lng.toFixed(2)})`;
            idleRidersByLocality[locKey] = (idleRidersByLocality[locKey] || 0) + 1;
          }
        }
      }
    });

    // 4. Fetch Vendors for Store Clusters
    const vendors = await Vendor.find({ approvalStatus: 'approved' })
      .select('storeName category location address city isOpen')
      .lean();

    const vendorPoints = [];
    vendors.forEach(v => {
      if (v.location && Array.isArray(v.location.coordinates) && v.location.coordinates.length >= 2) {
        const vLng = Number(v.location.coordinates[0]);
        const vLat = Number(v.location.coordinates[1]);
        if (!isNaN(vLat) && !isNaN(vLng) && (vLat !== 0 || vLng !== 0)) {
          vendorPoints.push({
            id: v._id,
            name: v.storeName,
            category: v.category,
            address: v.address || v.city || 'Store',
            isOpen: v.isOpen || false,
            lat: vLat,
            lng: vLng
          });
          sumLat += vLat;
          sumLng += vLng;
          validCoordCount++;
        }
      }
    });

    // Calculate actual center
    const dynamicCenter = validCoordCount > 0 
      ? { lat: sumLat / validCoordCount, lng: sumLng / validCoordCount }
      : { lat: centerLat, lng: centerLng };

    // 5. Calculate Real Predictive Zone Insights
    const sortedLocalities = Object.values(localityStats).sort((a, b) => b.orderCount - a.orderCount);
    
    // Top Growth Zone
    const topZone = sortedLocalities[0] || {
      name: 'Central Commercial Area',
      orderCount: orderPoints.length,
      activeCount: orderPoints.filter(p => p.isActive).length,
      totalRevenue: 0
    };

    // Idle Fleet Zone
    const idleEntries = Object.entries(idleRidersByLocality).sort((a, b) => b[1] - a[1]);
    const idleZoneName = idleEntries[0] ? idleEntries[0][0] : 'Central Rider Hub';
    const idleDriverCount = riderPoints.filter(r => r.isIdle).length;

    // Demand / Supply Ratio
    const activeOrdersCount = orderPoints.filter(p => p.isActive).length;
    const onlineDriversCount = riderPoints.filter(r => r.isOnline).length;
    const ratio = (activeOrdersCount / Math.max(onlineDriversCount, 1)).toFixed(1);
    
    let marketStatus = 'BALANCED OPERATIONS';
    if (activeOrdersCount > onlineDriversCount * 1.5) {
      marketStatus = 'HIGH SURGE DEMAND';
    } else if (onlineDriversCount > activeOrdersCount * 2) {
      marketStatus = 'EXCESS FLEET CAPACITY';
    }

    const surgeRate = topZone.orderCount > 0 ? `+${Math.min(topZone.orderCount * 8 + 14, 95)}% Surge` : 'Normal Flow';

    res.status(200).json({
      success: true,
      data: {
        orders: orderPoints,
        riders: riderPoints,
        vendors: vendorPoints,
        center: dynamicCenter,
        insights: {
          highGrowthZone: {
            name: topZone.name,
            surge: surgeRate,
            activeOrders: topZone.activeCount,
            totalOrders: topZone.orderCount,
            revenue: topZone.totalRevenue
          },
          idleZone: {
            name: idleZoneName,
            driverCount: idleDriverCount,
            detail: `${idleDriverCount} Drivers Available / Ready`
          },
          fleetHealth: {
            ratio: `${ratio}x`,
            marketStatus,
            activeOrdersCount,
            onlineDriversCount,
            idleDriversCount: idleDriverCount,
            totalHotspots: sortedLocalities.length || 1,
            totalVendors: vendorPoints.length
          },
          topLocalities: sortedLocalities.slice(0, 5)
        }
      }
    });
  } catch (error) {
    console.error('Heatmap Controller Error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};
