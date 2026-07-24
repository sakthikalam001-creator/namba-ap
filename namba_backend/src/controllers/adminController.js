const Vendor = require('../models/Vendor');
const User = require('../models/User');
const Order = require('../models/Order');
const Settings = require('../models/Settings');
const ServiceZone = require('../models/ServiceZone');
const fs = require('fs');
const path = require('path');



// @desc    Get all pending vendors awaiting approval
// @route   GET /api/v1/admin/vendors/pending
// @access  Super Admin
exports.getPendingVendors = async (req, res) => {
  try {
    const vendors = await Vendor.find({ approvalStatus: 'pending' })
      .populate('user', 'name phone email')
      .sort({ createdAt: -1 });

    res.status(200).json({ success: true, count: vendors.length, data: vendors });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get all vendors (all statuses) for admin overview with dynamic analytics
// @route   GET /api/v1/admin/vendors
// @access  Super Admin
exports.getAllVendors = async (req, res) => {
  try {
    console.log('[API Debug] getAllVendors called by User ID:', req.user?._id, 'Role:', req.user?.role);
    const vendors = await Vendor.aggregate([
      {
        $lookup: {
          from: 'users',
          localField: 'user',
          foreignField: '_id',
          as: 'userDetails',
        },
      },
      {
        $unwind: { path: '$userDetails', preserveNullAndEmptyArrays: true },
      },
      {
        $lookup: {
          from: 'orders',
          localField: '_id',
          foreignField: 'vendor',
          as: 'allOrders',
        },
      },
      {
        $addFields: {
          user: '$userDetails', // map back to 'user' field for frontend compatibility
          orders: {
            $size: {
              $filter: {
                input: '$allOrders',
                as: 'o',
                cond: { $eq: ['$$o.status', 'Delivered'] },
              },
            },
          },
          revenue: {
            $sum: {
              $map: {
                input: {
                  $filter: {
                    input: '$allOrders',
                    as: 'o',
                    cond: { $eq: ['$$o.status', 'Delivered'] },
                  },
                },
                as: 'o',
                in: '$$o.totalAmount',
              },
            },
          },
        },
      },
      {
        $project: {
          allOrders: 0,
          userDetails: 0,
        },
      },
      { $sort: { createdAt: -1 } },
    ]);

    res.status(200).json({ success: true, count: vendors.length, data: vendors });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Approve a vendor
// @route   PUT /api/v1/admin/vendors/:id/approve
// @access  Super Admin
exports.approveVendor = async (req, res) => {
  try {
    const vendor = await Vendor.findByIdAndUpdate(
      req.params.id,
      {
        approvalStatus: 'approved',
        approvedAt: new Date(),
        isOpen: true,
        trialExpiry: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000), // 14 days free trial
      },
      { new: true }
    ).populate('user', 'name phone email');

    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    // Emit real-time notification to vendor via Socket.io
    const io = req.app.get('socketio');
    if (io) {
      // Notify the specific vendor
      io.to(`vendor_${vendor._id}`).emit('approval_update', {
        status: 'approved',
        message: 'Congratulations! Your store has been approved.',
      });
      
      // Notify all customers about the new shop
      io.emit('vendor_new_live', {
        _id: vendor._id,
        storeName: vendor.storeName,
        category: vendor.category,
        isOpen: vendor.isOpen,
        location: vendor.location,
      });
    }

    console.log(`[Admin] ✅ Vendor "${vendor.storeName}" APPROVED`);
    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reject a vendor
// @route   PUT /api/v1/admin/vendors/:id/reject
// @access  Super Admin
exports.rejectVendor = async (req, res) => {
  try {
    const { reason } = req.body;

    const vendor = await Vendor.findByIdAndUpdate(
      req.params.id,
      {
        approvalStatus: 'rejected',
        rejectionReason: reason || 'Does not meet platform requirements.',
      },
      { new: true }
    ).populate('user', 'name phone email');

    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    // Emit real-time notification to vendor
    const io = req.app.get('socketio');
    if (io) {
      io.to(`vendor_${vendor._id}`).emit('approval_update', {
        status: 'rejected',
        message: reason || 'Your application was not approved at this time.',
      });
    }

    console.log(`[Admin] ❌ Vendor "${vendor.storeName}" REJECTED`);
    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Check approval status for a vendor (called by vendor app on login)
// @route   GET /api/v1/admin/vendors/:id/status
// @access  Public (Vendor)
exports.getVendorStatus = async (req, res) => {
  try {
    const vendor = await Vendor.findById(req.params.id).select('approvalStatus rejectionReason storeName trialExpiry isSubscribed subscriptionExpiry subscriptionPlan isLocked lockReason showSubscriptionBadge permissions');

    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor profile not found' });
    }

    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// --- DRIVER MANAGEMENT ---

// @desc    Get all pending drivers awaiting approval
// @route   GET /api/v1/admin/drivers/pending
exports.getPendingDrivers = async (req, res) => {
  try {
    const drivers = await User.find({ role: 'driver', driverApprovalStatus: 'pending' })
      .select('name phone vehicleType vehicleNumber licenseNumber driverApprovalStatus createdAt')
      .sort({ createdAt: -1 });
    res.status(200).json({ success: true, count: drivers.length, data: drivers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get all drivers
// @route   GET /api/v1/admin/drivers
exports.getAllDrivers = async (req, res) => {
  try {
    const drivers = await User.aggregate([
      { $match: { role: 'driver' } },
      {
        $lookup: {
          from: 'orders',
          localField: '_id',
          foreignField: 'driver',
          as: 'allDeliveries',
        },
      },
      {
        $addFields: {
          deliveryCount: {
            $size: {
              $filter: {
                input: '$allDeliveries',
                as: 'o',
                cond: { $eq: ['$$o.status', 'Delivered'] },
              },
            },
          },
          daysWorked: {
            $size: {
              $setUnion: {
                $map: {
                  input: {
                    $filter: {
                      input: '$allDeliveries',
                      as: 'o',
                      cond: { $eq: ['$$o.status', 'Delivered'] },
                    },
                  },
                  as: 'o',
                  in: { $dateToString: { format: "%Y-%m-%d", date: "$$o.createdAt" } },
                },
              },
            },
          },
        },
      },
      {
        $project: {
          allDeliveries: 0,
          password: 0,
        },
      },
      { $sort: { createdAt: -1 } },
    ]);
    const mappedDrivers = drivers.map(d => {
      let currentDutySeconds = d.onlineSecondsToday || 0;
      if (d.isOnline && d.onlineSessionStart) {
        currentDutySeconds += Math.max(0, Math.floor((Date.now() - new Date(d.onlineSessionStart).getTime()) / 1000));
      }
      const hrs = Math.floor(currentDutySeconds / 3600);
      const mins = Math.floor((currentDutySeconds % 3600) / 60);
      const dutyTimeStr = hrs > 0 ? `${hrs}h ${mins}m` : `${mins}m`;
      return {
        ...d,
        onlineDutyTime: dutyTimeStr,
      };
    });

    res.status(200).json({ success: true, count: mappedDrivers.length, data: mappedDrivers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Approve a driver
// @route   PUT /api/v1/admin/drivers/:id/approve
exports.approveDriver = async (req, res) => {
  try {
    const driver = await User.findByIdAndUpdate(
      req.params.id,
      { driverApprovalStatus: 'approved' },
      { new: true }
    ).select('name phone vehicleType vehicleNumber driverApprovalStatus');

    if (!driver) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    // Real-time notification to driver
    const io = req.app.get('socketio');
    if (io) {
      io.to(`driver_${driver._id}`).emit('driver_approval_update', {
        status: 'approved',
        message: 'Congratulations! Your delivery partner account has been approved. You can now start accepting orders!',
      });
    }

    console.log(`[Admin] ✅ Driver "${driver.name}" APPROVED`);
    res.status(200).json({ success: true, data: driver });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reject a driver
// @route   PUT /api/v1/admin/drivers/:id/reject
exports.rejectDriver = async (req, res) => {
  try {
    const { reason } = req.body;

    const driver = await User.findByIdAndUpdate(
      req.params.id,
      {
        driverApprovalStatus: 'rejected',
        driverRejectionReason: reason || 'Your application does not meet our requirements.',
      },
      { new: true }
    ).select('name phone driverApprovalStatus driverRejectionReason');

    if (!driver) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    // Real-time notification to driver
    const io = req.app.get('socketio');
    if (io) {
      io.to(`driver_${driver._id}`).emit('driver_approval_update', {
        status: 'rejected',
        message: reason || 'Your application was not approved at this time.',
      });
    }

    console.log(`[Admin] ❌ Driver "${driver.name}" REJECTED`);
    res.status(200).json({ success: true, data: driver });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Check approval status for a vendor by phone (called by vendor app on login)
// @route   GET /api/v1/admin/vendors/status-by-phone/:phone
// @access  Public
exports.getVendorStatusByPhone = async (req, res) => {
  try {
    const vendor = await Vendor.findOne({ phone: req.params.phone })
      .select('approvalStatus rejectionReason storeName category isOpen trialExpiry isSubscribed subscriptionExpiry subscriptionPlan isLocked lockReason showSubscriptionBadge permissions');

    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor profile not found' });
    }

    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset Database (Delete all orders, vendors, and non-admin users)
// @route   DELETE /api/v1/admin/reset-database
// @access  Super Admin
exports.resetDatabase = async (req, res) => {
  try {
    console.log('[Admin] ⚠️  Initiating Full System Wipe...');
    await Order.deleteMany({});
    await Vendor.deleteMany({});
    await User.deleteMany({ role: { $ne: 'admin' } });
    
    // Clear shared sync file if it exists
    const syncPaths = [
      'D:/New folder (2)/namba_shared_db.json',
      path.join(process.env.TEMP || process.env.TMP || '/tmp', 'namba_shared_db.json')
    ];
    syncPaths.forEach(p => {
      if (fs.existsSync(p)) {
        fs.writeFileSync(p, '[]');
        console.log(`[Admin] Wiped sync file at: ${p}`);
      }
    });

    


    // Broadcast wipeout to all connected clients
    const io = req.app.get('socketio');
    if (io) {
      io.emit('orders_wiped');
      console.log('[Admin] 📢 Broadcasted global orders_wiped signal');
    }

    res.status(200).json({ success: true, message: 'Total System Wipe successful.' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset Vendors Only
// @route   DELETE /api/v1/admin/reset/vendors
exports.resetVendors = async (req, res) => {
  try {
    const deletedVendors = await Vendor.deleteMany({});
    const deletedUsers = await User.deleteMany({ role: 'vendor' }); // Crucial: Delete vendor login accounts too
    const deletedOrders = await Order.deleteMany({});
    


    // Broadcast wipeout to all connected clients
    const io = req.app.get('socketio');
    if (io) {
      io.emit('orders_wiped');
    }

    console.log(`[Admin] 🏁  Wiped ${deletedVendors.deletedCount} Vendors, ${deletedUsers.deletedCount} Vendor Accounts, and all associated Orders/Sync files.`);
    res.status(200).json({ success: true, message: `Successfully wiped Vendors, Vendor Accounts, and all Orders.` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset Customers Only
// @route   DELETE /api/v1/admin/reset/customers
exports.resetCustomers = async (req, res) => {
  try {
    const deletedCustomers = await User.deleteMany({ role: 'customer' });
    const deletedOrders = await Order.deleteMany({});
    


    // Broadcast wipeout to all connected clients
    const io = req.app.get('socketio');
    if (io) {
      io.emit('orders_wiped');
    }

    console.log(`[Admin] 👥  Wiped ${deletedCustomers.deletedCount} Customers and all associated Orders/Sync files.`);
    res.status(200).json({ success: true, message: `Successfully wiped Customers and all Orders.` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset Delivery Partners Only
// @route   DELETE /api/v1/admin/reset/delivery
exports.resetDelivery = async (req, res) => {
  try {
    const deletedDelivery = await User.deleteMany({ role: 'delivery' });
    const deletedOrders = await Order.deleteMany({});
    


    // Broadcast wipeout to all connected clients
    const io = req.app.get('socketio');
    if (io) {
      io.emit('orders_wiped');
    }

    console.log(`[Admin] 🚚  Wiped ${deletedDelivery.deletedCount} Delivery Partners and all associated Orders/Sync files.`);
    res.status(200).json({ success: true, message: `Successfully wiped Delivery Partners and all Orders.` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset Orders Only (includes shared sync file)
// @route   DELETE /api/v1/admin/reset/orders
exports.resetOrders = async (req, res) => {
  try {
    const mongoose = require('mongoose');
    const deleted = await Order.deleteMany({});
    
    // Robust wipe: check all databases for 'orders' collection
    try {
        const adminConn = await mongoose.createConnection('mongodb://localhost:27017/admin').asPromise();
        const dbs = await adminConn.db.admin().listDatabases();
        for (const dbInfo of dbs.databases) {
            const name = dbInfo.name;
            if (['admin', 'local', 'config'].includes(name)) continue;
            if (name === 'namba_db') continue; 
            
            const conn = await mongoose.createConnection(`mongodb://localhost:27017/${name}`).asPromise();
            const r = await conn.db.collection('orders').deleteMany({});
            if (r.deletedCount > 0) {
                console.log(`[Admin] Wiped ${r.deletedCount} orders from ${name}.orders`);
            }
            await conn.close();
        }
        await adminConn.close();
    } catch (dbErr) {
        console.warn('[Admin] Multi-DB wipe failed, continuing...', dbErr.message);
    }

    // Clear shared sync file if it exists
    const syncPaths = [
      'D:/New folder (2)/namba_shared_db.json',
      path.join(process.env.TEMP || process.env.TMP || '/tmp', 'namba_shared_db.json')
    ];
    syncPaths.forEach(p => {
      if (fs.existsSync(p)) {
        fs.writeFileSync(p, '[]');
        console.log(`[Admin] Wiped sync file at: ${p}`);
      }
    });
    
    // Broadcast wipeout to all connected clients
    const io = req.app.get('socketio');
    if (io) {
      io.emit('orders_wiped');
    }
    
    console.log(`[Admin] ✅ Wiped ${deleted.deletedCount} Orders and Sync Files.`);
    res.status(200).json({ success: true, message: `Successfully wiped ${deleted.deletedCount} Orders and Shared Sync Files.` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset Admins Only (Danger!)
// @route   DELETE /api/v1/admin/reset/admins
exports.resetAdmins = async (req, res) => {
  try {
    const deleted = await User.deleteMany({ role: 'admin' });
    console.log(`[Admin] ⛔  Wiped ${deleted.deletedCount} Administrators.`);
    res.status(200).json({ success: true, message: `Successfully wiped ${deleted.deletedCount} Administrators. You will be locked out.` });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// --- DISPATCH MANAGEMENT ---

// @desc    Get orders that need a delivery partner
exports.getDispatchOrders = async (req, res) => {
  try {
    const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000);
    const orders = await Order.find({
      $or: [
        { status: { $in: ['Pending', 'Accepted', 'Preparing', 'Ready', 'Assigned', 'HandedOver', 'PickedUp', 'OutForDelivery'] } },
        { status: { $in: ['Delivered', 'Cancelled'] }, updatedAt: { $gte: twelveHoursAgo } }
      ],
      paymentStatus: { $ne: 'Failed' },
    })
      .populate('customer', 'name phone')
      .populate('vendor', 'storeName category location')
      .populate('driver', 'name phone vehicleType vehicleNumber')
      .sort({ createdAt: -1 });

    console.log(`[Admin] Fetching dispatch orders. Found: ${orders.length} orders.`);
    if (orders.length > 0) {
      console.log(`[Admin] Order IDs: ${orders.map(o => o.displayId).join(', ')}`);
    }

    res.status(200).json({ success: true, count: orders.length, data: orders });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get live customer orders (Active status)
// @route   GET /api/v1/admin/orders/customer
exports.getCustomerOrders = async (req, res) => {
  try {
    const orders = await Order.find({ status: { $nin: ['Delivered', 'Cancelled', 'Cart', 'PaymentPending'] }, paymentStatus: { $ne: 'Failed' } })
      .populate('customer', 'name phone')
      .populate('vendor', 'storeName category phone location')
      .populate('driver', 'name phone vehicleType vehicleNumber')
      .sort({ createdAt: -1 });

    res.status(200).json({ success: true, count: orders.length, data: orders });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get customer order history (Delivered or Cancelled)
// @route   GET /api/v1/admin/orders/customer/history
exports.getCustomerOrderHistory = async (req, res) => {
  try {
    const orders = await Order.find({ status: { $in: ['Delivered', 'Cancelled'] } })
      .populate('customer', 'name phone')
      .populate('vendor', 'storeName category phone location')
      .populate('driver', 'name phone vehicleType vehicleNumber')
      .sort({ updatedAt: -1 })
      .limit(50);

    res.status(200).json({ success: true, count: orders.length, data: orders });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// Helper: Calculate distance between two coordinates in km (Haversine formula)
function getDistanceKm(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295;
  const c = Math.cos;
  const a = 0.5 - c((lat2 - lat1) * p)/2 + 
            c(lat1 * p) * c(lat2 * p) * 
            (1 - c((lon2 - lon1) * p))/2;
  return 12742 * Math.asin(Math.sqrt(a));
}

// @desc    Get all online drivers for assignment (with optional nearest distance suggestions)
// @route   GET /api/v1/admin/dispatch/drivers
exports.getAvailableDrivers = async (req, res) => {
  try {
    const { vendorLat, vendorLng, customerLat, customerLng, orderId } = req.query;

    let targetVendorLat = vendorLat ? parseFloat(vendorLat) : null;
    let targetVendorLng = vendorLng ? parseFloat(vendorLng) : null;
    let targetCustomerLat = customerLat ? parseFloat(customerLat) : null;
    let targetCustomerLng = customerLng ? parseFloat(customerLng) : null;

    if (orderId && (!targetVendorLat || !targetCustomerLat)) {
      const Order = require('../models/Order');
      const order = await Order.findById(orderId).populate('vendor', 'location');
      if (order) {
        if (order.vendor && order.vendor.location && order.vendor.location.coordinates) {
          targetVendorLat = order.vendor.location.coordinates[1];
          targetVendorLng = order.vendor.location.coordinates[0];
        }
        if (order.deliveryCoordinates && order.deliveryCoordinates.coordinates) {
          targetCustomerLat = order.deliveryCoordinates.coordinates[1];
          targetCustomerLng = order.deliveryCoordinates.coordinates[0];
        }
      }
    }

    const drivers = await User.find({
      role: 'driver',
      isOnline: true,
      driverApprovalStatus: 'approved',
    }).select('name phone lastLocation');

    const formattedDrivers = drivers.map(driver => {
      const dObj = driver.toObject();
      let dLat = null;
      let dLng = null;

      if (driver.lastLocation && driver.lastLocation.coordinates && driver.lastLocation.coordinates.length >= 2) {
        dLng = driver.lastLocation.coordinates[0];
        dLat = driver.lastLocation.coordinates[1];
      }

      if (dLat !== null && dLng !== null) {
        if (targetVendorLat !== null && targetVendorLng !== null) {
          dObj.distanceFromVendorKm = parseFloat(getDistanceKm(dLat, dLng, targetVendorLat, targetVendorLng).toFixed(2));
        }
        if (targetCustomerLat !== null && targetCustomerLng !== null) {
          dObj.distanceFromCustomerKm = parseFloat(getDistanceKm(dLat, dLng, targetCustomerLat, targetCustomerLng).toFixed(2));
        }
        dObj.distanceKm = dObj.distanceFromVendorKm ?? dObj.distanceFromCustomerKm ?? null;
      } else {
        dObj.distanceFromVendorKm = null;
        dObj.distanceFromCustomerKm = null;
        dObj.distanceKm = null;
      }
      return dObj;
    });

    // Sort drivers by nearest distance first
    formattedDrivers.sort((a, b) => {
      const distA = a.distanceKm ?? 999999;
      const distB = b.distanceKm ?? 999999;
      return distA - distB;
    });

    res.status(200).json({ success: true, count: formattedDrivers.length, data: formattedDrivers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Assign a driver to an order
// @route   PUT /api/v1/admin/dispatch/assign
exports.assignDriverToOrder = async (req, res) => {
  try {
    const { orderId, driverId } = req.body;
    const mongoose = require('mongoose');
    let query = { _id: orderId };
    if (!mongoose.Types.ObjectId.isValid(orderId)) {
        query = { displayId: orderId.startsWith('NM-') ? orderId : `NM-${orderId}` };
    }

    const currentOrder = await Order.findOne(query);
    if (!currentOrder) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    const updateFields = { driver: driverId };
    const advancedStatuses = ['Accepted', 'Preparing', 'Ready', 'HandedOver', 'PickedUp', 'OutForDelivery', 'Delivered', 'Cancelled'];
    if (!advancedStatuses.includes(currentOrder.status)) {
      updateFields.status = 'Assigned';
    }

    const order = await Order.findOneAndUpdate(
      query,
      updateFields,
      { new: true }
    )
      .populate('customer', 'name phone')
      .populate('vendor', 'storeName category');

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // Ping Admin and Driver via socket
    const io = req.app.get('socketio');
    if (io) {
      // Notify the specific driver
      io.to(`driver_${driverId}`).emit('new_assignment', {
        orderId: order._id,
        displayId: order.displayId,
        vendorName: order.isCustomStore ? (order.customStoreName || 'Any Store Pickup') : (order.vendor ? order.vendor.storeName : 'Any Store Pickup'),
        paymentMethod: order.paymentMethod,
        amount: order.totalAmount,
      });

      // Notify admin to refresh dispatch list
      io.to('admin').emit('dispatch_update', { message: 'Order Assigned' });
    }

    res.status(200).json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Unassign driver from order
// @route   PUT /api/v1/admin/dispatch/unassign/:id
exports.unassignDriverFromOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const mongoose = require('mongoose');
    let query = { _id: id };
    if (!mongoose.Types.ObjectId.isValid(id)) {
        query = { displayId: id.startsWith('NM-') ? id : `NM-${id}` };
    }

    const currentOrder = await Order.findOne(query);
    if (!currentOrder) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    const previousDriverId = currentOrder.driver;

    const updateFields = { $unset: { driver: 1 } };
    const advancedStatuses = ['Accepted', 'Preparing', 'Ready', 'HandedOver', 'PickedUp', 'OutForDelivery', 'Delivered', 'Cancelled'];
    if (!advancedStatuses.includes(currentOrder.status)) {
      updateFields.status = 'Accepted'; // Reset status so it appears in the awaiting queue
    }

    const order = await Order.findOneAndUpdate(
      query,
      updateFields,
      { new: true }
    );

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    const io = req.app.get('socketio');
    if (io) {
      io.to('admin').emit('dispatch_update', { message: 'Order Unassigned' });
      
      // Notify the driver that they are no longer assigned
      if (previousDriverId) {
        io.to(`driver_${previousDriverId}`).emit('order_status_update', {
          orderId: order._id,
          status: 'Cancelled', // Or a specific 'Unassigned' event if the app handles it
          message: 'This order has been unassigned from you.'
        });
        
        // Also trigger a full sync for the driver
        io.to(`driver_${previousDriverId}`).emit('force_sync'); 
      }
    }

    res.status(200).json({ success: true, data: order });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Cancel order from admin hub with targeted options
// @route   PUT /api/v1/admin/orders/:id/cancel
exports.cancelOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const { target } = req.body; // 'driver', 'vendor', 'customer', 'all'
    const mongoose = require('mongoose');
    let query = { _id: id };
    if (!mongoose.Types.ObjectId.isValid(id)) {
      query = { displayId: id.startsWith('NM-') ? id : `NM-${id}` };
    }

    const currentOrder = await Order.findOne(query);
    if (!currentOrder) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    const previousDriverId = currentOrder.driver;
    const previousVendorId = currentOrder.vendor;
    const previousCustomerId = currentOrder.customer;
    const io = req.app.get('socketio');

    let updatedOrder;

    if (target === 'driver') {
      const updateFields = { $unset: { driver: 1 } };
      const advancedStatuses = ['Accepted', 'Preparing', 'Ready', 'HandedOver', 'PickedUp', 'OutForDelivery', 'Delivered', 'Cancelled'];
      if (!advancedStatuses.includes(currentOrder.status)) {
        updateFields.status = 'Accepted';
      }
      updatedOrder = await Order.findOneAndUpdate(query, updateFields, { new: true });

      if (io && previousDriverId) {
        io.to(`driver_${previousDriverId}`).emit('order_status_update', {
          orderId: currentOrder._id,
          status: 'Cancelled',
          message: 'Order unassigned from driver by Admin'
        });
        io.to(`driver_${previousDriverId}`).emit('force_sync');
      }
    } else if (target === 'vendor') {
      updatedOrder = await Order.findOneAndUpdate(query, { status: 'Rejected' }, { new: true });
      if (io && previousVendorId) {
        io.to(`vendor_${previousVendorId}`).emit('order_status_update', {
          orderId: currentOrder._id,
          status: 'Rejected',
          message: 'Order cancelled for Vendor by Admin'
        });
      }
    } else if (target === 'customer') {
      updatedOrder = await Order.findOneAndUpdate(query, { status: 'Cancelled' }, { new: true });
      if (io && previousCustomerId) {
        io.to(`customer_${previousCustomerId}`).emit('order_status_update', {
          orderId: currentOrder._id,
          status: 'Cancelled',
          message: 'Order cancelled for Customer by Admin'
        });
      }
    } else {
      // 'all' or default -> Full cancellation across all 3 parties
      updatedOrder = await Order.findOneAndUpdate(query, { status: 'Cancelled', $unset: { driver: 1 } }, { new: true });

      const cancelPayload = {
        orderId: currentOrder._id.toString(),
        displayId: currentOrder.displayId,
        status: 'Cancelled',
        message: 'Order cancelled by Admin'
      };

      if (io) {
        // Emit to general order room
        io.to(`order_${currentOrder._id.toString()}`).emit('order_status_update', cancelPayload);

        if (previousDriverId) {
          io.to(`driver_${previousDriverId}`).emit('order_status_update', {
            ...cancelPayload,
            message: 'Order unassigned/cancelled by Admin'
          });
          io.to(`driver_${previousDriverId}`).emit('force_sync');
        }

        if (previousVendorId) {
          io.to(`vendor_${previousVendorId}`).emit('order_status_update', {
            ...cancelPayload,
            status: 'Cancelled',
            message: 'Order cancelled for Vendor by Admin'
          });
        }

        if (previousCustomerId) {
          io.to(`customer_${previousCustomerId}`).emit('order_status_update', {
            ...cancelPayload,
            message: 'Order cancelled by Admin'
          });
          // Also emit to phone room if applicable
          const customerUser = await User.findById(previousCustomerId).select('phone');
          if (customerUser && customerUser.phone) {
            io.to(`customer_${customerUser.phone}`).emit('order_status_update', cancelPayload);
          }
        }
      }
    }

    if (io) {
      io.to('admin').emit('order_status_update', {
        orderId: currentOrder._id.toString(),
        displayId: currentOrder.displayId,
        status: 'Cancelled',
        message: 'Order Cancelled'
      });
      io.to('admin').emit('dispatch_update', { message: 'Order Cancelled', target });
    }

    res.status(200).json({ success: true, data: updatedOrder, target: target || 'all' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// --- PLATFORM SETTINGS ---

// @desc    Get global platform settings
// @route   GET /api/v1/admin/settings
exports.getSettings = async (req, res) => {
  try {
    let settings = await Settings.findOne();
    
    // Create default settings if none exist
    if (!settings) {
      settings = await Settings.create({});
    }

    res.status(200).json({ success: true, data: settings });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update global platform settings
// @route   PUT /api/v1/admin/settings
exports.updateSettings = async (req, res) => {
  try {
    let settings = await Settings.findOne();
    
    if (!settings) {
      settings = await Settings.create(req.body);
    } else {
      settings = await Settings.findByIdAndUpdate(settings._id, req.body, {
        new: true,
        runValidators: true,
      });
    }

    // Emit real-time settings update
    const io = req.app.get('socketio');
    if (io) {
      io.emit('settings_update', {
        settings: settings,
        message: 'Global platform settings updated'
      });
      console.log(`[Setting Sync] ⚙️ Global platform settings updated`);
    }

    res.status(200).json({ success: true, data: settings });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
// --- DOCUMENT VERIFICATION ---

// @desc    Get drivers with pending documents
// @route   GET /api/v1/admin/documents/pending
exports.getPendingDocumentVerifications = async (req, res) => {
  try {
    const drivers = await User.find({
      role: 'driver',
      $or: [
        { 'documents.aadhar.status': 'pending' },
        { 'documents.license.status': 'pending' },
        { 'documents.rc.status': 'pending' },
        { 'documents.pan.status': 'pending' },
        { 'documents.bankStatement.status': 'pending' },
        { 'documents.selfie.status': 'pending' }
      ]
    }).select('name phone documents createdAt');

    res.status(200).json({ success: true, count: drivers.length, data: drivers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Verify or Reject a specific document for a driver
// @route   PUT /api/v1/admin/documents/:driverId/verify
exports.verifyDriverDocument = async (req, res) => {
  try {
    const { docType, status, reason } = req.body;
    const { driverId } = req.params;

    if (!docType || !status) {
      return res.status(400).json({ success: false, error: 'Please provide docType and status' });
    }

    const user = await User.findById(driverId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    if (!user.documents || !user.documents[docType]) {
      return res.status(400).json({ success: false, error: 'Document data not found' });
    }

    // Update document status
    user.documents[docType].status = status;
    if (status === 'rejected') {
      user.documents[docType].rejectionReason = reason || 'Document invalid or unclear';
    } else {
      user.documents[docType].rejectionReason = undefined;
    }

    // AUTO-APPROVE DRIVER IF ALL DOCS VERIFIED
    const docs = user.documents;
    const allVerified = 
      docs.aadhar?.status === 'verified' &&
      docs.license?.status === 'verified' &&
      docs.rc?.status === 'verified' &&
      docs.pan?.status === 'verified' &&
      docs.bankStatement?.status === 'verified' &&
      docs.selfie?.status === 'verified';

    if (allVerified) {
      user.driverApprovalStatus = 'approved';
    }

    await user.save();

    console.log(`[Admin] 📄 Document "${docType}" for Driver "${user.name}" -> ${status.toUpperCase()}`);

    // Notify driver via socket
    const io = req.app.get('socketio');
    if (io) {
      io.to(`driver_${driverId}`).emit('document_update', {
        docType,
        status,
        message: status === 'verified' 
          ? `Your ${docType} has been verified!` 
          : `Your ${docType} was rejected: ${reason}`,
        allVerified // Frontend can use this to show a success dialog
      });
    }

    res.status(200).json({ success: true, data: user.documents });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// --- ADMIN MANAGEMENT ---

// @desc    Get all regular admins
// @route   GET /api/v1/admin/admins
// @access  Super Admin
exports.getAllAdmins = async (req, res) => {
  try {
    const admins = await User.find({ role: { $in: ['admin', 'superadmin'] } }).sort({ createdAt: -1 });
    res.status(200).json({ success: true, count: admins.length, data: admins });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Provision a new regular admin
// @route   POST /api/v1/admin/admins
// @access  Super Admin
exports.provisionAdmin = async (req, res) => {
  try {
    const { name, phone, email, password, city, permissions } = req.body;

    if (!name || !phone || !password) {
      return res.status(400).json({ success: false, error: 'Please provide name, phone and password' });
    }

    // Check for existing user
    const existing = await User.findOne({ phone });
    if (existing) {
      return res.status(400).json({ success: false, error: 'Phone number already registered' });
    }

    const admin = await User.create({
      name,
      phone,
      email,
      password,
      role: 'admin',
      city: city || 'Chennai',
      permissions: permissions || {
        'Overview': true,
        'Vendors': true,
        'Admins': false,
        'Drivers': true,
        'Verification': false,
        'Dispatch Hub': true,
        'Broadcasts': false,
        'Support Hub': false,
        'Intelligence': false,
        'Security Audit': false,
        'Report Center': false,
        'Settings': false,
      }
    });

    res.status(201).json({ success: true, data: admin });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset admin password
// @route   PUT /api/v1/admin/admins/:id/reset-password
// @access  Super Admin
exports.resetAdminPassword = async (req, res) => {
  try {
    const { password } = req.body;
    if (!password) {
      return res.status(400).json({ success: false, error: 'Please provide a new password' });
    }

    const user = await User.findById(req.params.id).select('+password');
    if (!user) {
      return res.status(404).json({ success: false, error: 'Admin not found' });
    }

    user.password = password;
    await user.save();

    res.status(200).json({ success: true, message: 'Password reset successful' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update admin's own profile (email, password, name)
// @route   PUT /api/v1/admin/profile/:id
// @access  Admin/Super Admin (Self)
exports.updateAdminProfile = async (req, res) => {
  console.log('PUT /api/v1/admin/profile hit with ID:', req.params.id);
  try {
    const { name, email, password } = req.body;
    const user = await User.findById(req.params.id).select('+password');

    if (!user) {
      return res.status(404).json({ success: false, error: 'Admin not found' });
    }

    if (name) user.name = name;
    if (email) user.email = email;
    if (password) user.password = password;

    await user.save();

    res.status(200).json({ 
      success: true, 
      message: 'Profile updated successfully',
      data: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        permissions: user.permissions
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};// @desc    Update specific admin permissions
// @route   PUT /api/v1/admin/admins/:id/permissions
// @access  Super Admin
exports.updateAdminPermissions = async (req, res) => {
  try {
    const { permissions } = req.body;
    if (!permissions) {
      return res.status(400).json({ success: false, error: 'Please provide permissions object' });
    }

    const admin = await User.findByIdAndUpdate(
      req.params.id,
      { permissions },
      { new: true, runValidators: true }
    );

    if (!admin) {
      return res.status(404).json({ success: false, error: 'Admin not found' });
    }

    // Emit real-time permission update
    const io = req.app.get('socketio');
    if (io) {
      io.emit('permission_update', {
        adminId: admin._id,
        permissions: admin.permissions
      });
      console.log(`[Permission Sync] 🔐 Permissions updated for admin: ${admin.name}`);
    }

    res.status(200).json({ success: true, data: admin });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update admin role
// @route   PUT /api/v1/admin/admins/:id/role
// @access  Super Admin
exports.updateAdminRole = async (req, res) => {
  try {
    const { role } = req.body;
    if (!role || !['admin', 'superadmin'].includes(role)) {
      return res.status(400).json({ success: false, error: 'Please provide a valid role (admin or superadmin)' });
    }

    const admin = await User.findByIdAndUpdate(
      req.params.id,
      { role },
      { new: true, runValidators: true }
    );

    if (!admin) {
      return res.status(404).json({ success: false, error: 'Admin not found' });
    }
    
    // Emit real-time permission/role update
    const io = req.app.get('socketio');
    if (io) {
      // Notify them of potentially upgraded/downgraded permissions that typically go with the role
      // But role itself can be pushed if frontend uses it directly
      console.log(`[Role Sync] 👑 Role updated for admin: ${admin.name} to ${role}`);
    }

    res.status(200).json({ success: true, data: admin });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// --- SERVICE ZONES (MULTI-DISTRICT SUPPORT) ---

// @desc    Get all service zones
// @route   GET /api/v1/admin/zones
exports.getServiceZones = async (req, res) => {
  try {
    const zones = await ServiceZone.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: zones });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Create a new service zone
// @route   POST /api/v1/admin/zones
exports.createServiceZone = async (req, res) => {
  try {
    const zone = await ServiceZone.create(req.body);
    res.status(201).json({ success: true, data: zone });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// @desc    Update a service zone
// @route   PUT /api/v1/admin/zones/:id
exports.updateServiceZone = async (req, res) => {
  try {
    const zone = await ServiceZone.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!zone) {
      return res.status(404).json({ success: false, error: 'Zone not found' });
    }

    res.status(200).json({ success: true, data: zone });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// @desc    Delete a service zone
// @route   DELETE /api/v1/admin/zones/:id
exports.deleteServiceZone = async (req, res) => {
  try {
    const zone = await ServiceZone.findByIdAndDelete(req.params.id);

    if (!zone) {
      return res.status(404).json({ success: false, error: 'Zone not found' });
    }

    res.status(200).json({ success: true, message: 'Zone deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update Vendor Access (Lock/Unlock, Trial/Subscription Adjustment)
// @route   PUT /api/v1/admin/vendors/:id/access
// @access  Super Admin
exports.updateVendorAccess = async (req, res) => {
  try {
    const { 
      isLocked, 
      lockReason, 
      trialExpiry, 
      subscriptionExpiry, 
      isSubscribed, 
      showSubscriptionBadge,
      permissions,
      commissionEnabled,
      commissionRate 
    } = req.body;

    const updateData = {
      lockReason,
      trialExpiry,
      subscriptionExpiry,
      isSubscribed,
      showSubscriptionBadge,
      permissions,
      commissionEnabled,
      commissionRate,
    };

    if (isLocked !== undefined) {
      updateData.isLocked = isLocked;
      if (isLocked === false) {
        updateData.isManuallyUnlocked = true;
      } else if (isLocked === true) {
        updateData.isManuallyUnlocked = false;
      }
    }

    const vendor = await Vendor.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true }
    );

    if (!vendor) {
      return res.status(404).json({ success: false, error: 'Vendor not found' });
    }

    console.log(`[Admin] 🔐 Updated Access for Vendor: ${vendor.storeName} (Locked: ${vendor.isLocked})`);

    // Emit live update to Vendor App via Socket
    const io = req.app.get('socketio');
    if (io) {
      io.to(`vendor_${vendor._id}`).emit('access_update', {
        isLocked: vendor.isLocked,
        lockReason: vendor.lockReason,
        trialExpiry: vendor.trialExpiry,
        subscriptionExpiry: vendor.subscriptionExpiry,
        showSubscriptionBadge: vendor.showSubscriptionBadge,
        permissions: vendor.permissions,
      });

      // If just locked, force them offline
      if (vendor.isLocked && vendor.isOpen) {
        vendor.isOpen = false;
        await vendor.save();
        io.to('admin').emit('vendor_status_update', {
          vendorId: vendor._id,
          isOpen: false,
          storeName: vendor.storeName
        });
      }
    }

    res.status(200).json({ success: true, data: vendor });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get aggregated financial analytics for Super Admin
// @route   GET /api/v1/admin/financial-analytics
// @access  Super Admin
exports.getFinancialAnalytics = async (req, res) => {
  try {
    const stats = await Order.aggregate([
      { $match: { status: 'Delivered' } },
      {
        $group: {
          _id: null,
          totalDeliveryCharges: { $sum: { $ifNull: ['$deliveryCharge', 0] } },
          totalVendorFees: { $sum: { $ifNull: ['$vendorFee', 0] } },
          totalPlatformFees: { $sum: { $ifNull: ['$platformFee', 0] } },
          totalRevenue: { 
            $sum: { 
              $add: [
                { $ifNull: ['$deliveryCharge', 0] }, 
                { $ifNull: ['$vendorFee', 0] }, 
                { $ifNull: ['$platformFee', 0] }
              ] 
            } 
          },
          orderCount: { $sum: 1 }
        }
      }
    ]);

    // Trend data (last 7 days)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const trends = await Order.aggregate([
      { 
        $match: { 
          status: 'Delivered',
          createdAt: { $gte: sevenDaysAgo }
        } 
      },
      {
        $group: {
          _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
          delivery: { $sum: { $ifNull: ["$deliveryCharge", 0] } },
          vendor: { $sum: { $ifNull: ["$vendorFee", 0] } },
          platform: { $sum: { $ifNull: ["$platformFee", 0] } }
        }
      },
      { $sort: { "_id": 1 } }
    ]);

    res.status(200).json({ 
      success: true, 
      data: {
        summary: stats[0] ? {
          totalDeliveryCharges: stats[0].totalDeliveryCharges,
          totalVendorFees: stats[0].totalVendorFees,
          totalCustomerPlatformFees: stats[0].totalPlatformFees, // Keep key for frontend compatibility
          totalRevenue: stats[0].totalRevenue,
          orderCount: stats[0].orderCount
        } : {
          totalDeliveryCharges: 0,
          totalVendorFees: 0,
          totalCustomerPlatformFees: 0,
          totalRevenue: 0,
          orderCount: 0
        },
        trends
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
exports.getPerformanceAnalytics = async (req, res) => {
  try {
    // Top Vendors by Sales Volume and Value
    const topVendors = await Order.aggregate([
      { $match: { status: 'Delivered' } },
      {
        $group: {
          _id: '$vendor',
          orderCount: { $sum: 1 },
          totalSales: { $sum: '$totalAmount' },
          avgOrderValue: { $avg: '$totalAmount' }
        }
      },
      { $lookup: { from: 'vendors', localField: '_id', foreignField: '_id', as: 'vendorInfo' } },
      { $unwind: '$vendorInfo' },
      { $sort: { totalSales: -1 } },
      { $limit: 10 },
      {
        $project: {
          _id: 1,
          orderCount: 1,
          totalSales: 1,
          avgOrderValue: 1,
          storeName: '$vendorInfo.storeName',
          ownerName: '$vendorInfo.ownerName',
          phone: '$vendorInfo.phone',
          category: '$vendorInfo.category'
        }
      }
    ]);

    // Driver Performance & Reliability
    const driverPerformance = await Order.aggregate([
      { $match: { status: 'Delivered' } },
      {
        $group: {
          _id: '$driver',
          deliveryCount: { $sum: 1 },
          totalEarnings: { $sum: '$deliveryCharge' }, // Assuming deliveryCharge goes to driver
          activeDays: { $addToSet: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } } }
        }
      },
      {
        $project: {
          _id: 1,
          deliveryCount: 1,
          totalEarnings: 1,
          daysWorked: { $size: '$activeDays' }
        }
      },
      { $lookup: { from: 'users', localField: '_id', foreignField: '_id', as: 'driverInfo' } },
      { $unwind: '$driverInfo' },
      { $sort: { deliveryCount: -1 } },
      {
        $project: {
          _id: 1,
          deliveryCount: 1,
          totalEarnings: 1,
          daysWorked: 1,
          name: '$driverInfo.name',
          phone: '$driverInfo.phone',
          vehicleType: '$driverInfo.vehicleType',
          isOnline: '$driverInfo.isOnline',
          declinedCount: '$driverInfo.declinedCount'
        }
      }
    ]);
    res.status(200).json({
      success: true,
      data: {
        topVendors,
        driverPerformance
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

exports.getReportAnalytics = async (req, res) => {
  try {
    // Transaction Ledger (Vendor Yield)
    const payouts = await Order.aggregate([
      { $match: { status: 'Delivered' } },
      {
        $group: {
          _id: '$vendor',
          totalVolume: { $sum: { $ifNull: ['$totalAmount', 0] } },
          yield: { 
            $sum: { 
              $add: [
                { $ifNull: ['$vendorFee', 0] }, 
                { $ifNull: ['$platformFee', 0] }
              ] 
            } 
          },
          lastOrderDate: { $max: '$updatedAt' }
        }
      },
      { $lookup: { from: 'vendors', localField: '_id', foreignField: '_id', as: 'vendorInfo' } },
      { $unwind: '$vendorInfo' },
      {
        $project: {
          vendor: '$vendorInfo.storeName',
          amount: '$totalVolume',
          commission: '$yield',
          status: { $literal: 'Paid' }, // Simulation: assuming paid if delivered for now
          date: { $dateToString: { format: "%b %d", date: "$lastOrderDate" } }
        }
      },
      { $sort: { amount: -1 } }
    ]);

    // Driver Earnings Ledger
    const driverPayouts = await Order.aggregate([
      { $match: { status: 'Delivered', driver: { $exists: true } } },
      {
        $group: {
          _id: '$driver',
          totalVolume: { $sum: { $ifNull: ['$deliveryCharge', 0] } },
          pendingVolume: { 
            $sum: { 
              $cond: [
                { $ne: ['$driverPaymentStatus', 'Paid'] }, 
                { $ifNull: ['$deliveryCharge', 0] }, 
                0
              ] 
            } 
          },
          lastOrderDate: { $max: '$updatedAt' }
        }
      },
      { $lookup: { from: 'users', localField: '_id', foreignField: '_id', as: 'driverInfo' } },
      { $unwind: '$driverInfo' },
      {
        $project: {
          driverId: '$_id',
          driverName: '$driverInfo.name',
          amount: '$pendingVolume',
          totalEarnings: '$totalVolume',
          status: { $cond: [{ $gt: ['$pendingVolume', 0] }, 'Pending', 'Paid'] },
          date: { $dateToString: { format: "%b %d", date: "$lastOrderDate" } }
        }
      },
      { $sort: { amount: -1 } }
    ]);

    res.status(200).json({
      success: true,
      data: {
        vendorPayouts: payouts,
        driverPayouts: driverPayouts
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get failed payment orders
// @route   GET /api/v1/admin/orders/failed-payments
exports.getFailedPaymentOrders = async (req, res) => {
  try {
    const orders = await Order.find({ paymentStatus: 'Failed' })
      .populate('customer', 'name phone')
      .populate('vendor', 'storeName phone location')
      .sort({ updatedAt: -1 });

    res.status(200).json({ success: true, count: orders.length, data: orders });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Pay pending salary to driver
// @route   PUT /api/v1/admin/drivers/:id/pay
exports.payDriverSalary = async (req, res) => {
  try {
    const driverId = req.params.id;
    const result = await Order.updateMany(
      { driver: driverId, driverPaymentStatus: { $ne: 'Paid' }, status: 'Delivered' },
      { $set: { driverPaymentStatus: 'Paid' } }
    );

    res.status(200).json({
      success: true,
      message: `Successfully paid salary. ${result.modifiedCount} orders marked as paid.`,
      data: result
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get all customers with full details & order stats
// @route   GET /api/v1/admin/customers
// @access  Admin / SuperAdmin
exports.getAllCustomers = async (req, res) => {
  try {
    const customers = await User.aggregate([
      { $match: { role: 'customer' } },
      {
        $lookup: {
          from: 'orders',
          let: { uid: '$_id', uphone: '$phone' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $or: [
                    { $eq: ['$customer', '$$uid'] },
                    { $eq: ['$customerPhone', '$$uphone'] },
                  ],
                },
              },
            },
          ],
          as: 'allOrders',
        },
      },
      {
        $addFields: {
          totalOrders: { $size: '$allOrders' },
          deliveredOrders: {
            $size: {
              $filter: { input: '$allOrders', as: 'o', cond: { $eq: ['$$o.status', 'Delivered'] } },
            },
          },
          totalSpend: {
            $sum: {
              $map: {
                input: {
                  $filter: { input: '$allOrders', as: 'o', cond: { $eq: ['$$o.status', 'Delivered'] } },
                },
                as: 'o',
                in: { $add: ['$$o.totalAmount', { $ifNull: ['$$o.deliveryCharge', 0] }] },
              },
            },
          },
          lastOrderDate: { $max: '$allOrders.createdAt' },
          activeOrders: {
            $size: {
              $filter: {
                input: '$allOrders',
                as: 'o',
                cond: {
                  $not: { $in: ['$$o.status', ['Delivered', 'Cancelled', 'Cart', 'PaymentPending']] },
                },
              },
            },
          },
        },
      },
      {
        $project: {
          password: 0,
          resetPasswordOtp: 0,
          resetPasswordExpire: 0,
          allOrders: 0,
        },
      },
      { $sort: { createdAt: -1 } },
    ]);

    res.status(200).json({ success: true, count: customers.length, data: customers });
  } catch (err) {
    console.error('[getAllCustomers]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};
