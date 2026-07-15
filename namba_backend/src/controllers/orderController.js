const Order = require('../models/Order');
const User = require('../models/User');
const Vendor = require('../models/Vendor');
const Settings = require('../models/Settings');
const ServiceZone = require('../models/ServiceZone');
const asyncHandler = require('../utils/asyncHandler');

// Helper: Calculate distance between two coordinates in km (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  const c = Math.cos;
  const a = 0.5 - c((lat2 - lat1) * p)/2 + 
            c(lat1 * p) * c(lat2 * p) * 
            (1 - c((lon2 - lon1) * p))/2;

  return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
}

/**
 * Helper: Attempt to auto-assign a driver to an order
 */
const attemptAutoAssignment = async (order, io) => {
  if (order.driver) return;

  const settings = await Settings.findOne() || { autoAssign: true, maxDispatchRadiusKm: 10 };
  if (!settings.autoAssign) return;

  console.log(`[Auto-Assign] 🔍 Searching driver for order #${order.displayId}...`);

  let searchLocation = null;
  let storeName = 'Any Shop Order';

  if (order.vendor) {
    const vendorObj = await Vendor.findById(order.vendor);
    if (vendorObj && vendorObj.location) {
      searchLocation = vendorObj.location;
      storeName = vendorObj.storeName;
    }
  } else if (order.isCustomStore && order.deliveryCoordinates) {
    // Fallback for custom orders: use delivery location as search center
    searchLocation = order.deliveryCoordinates;
    storeName = order.customStoreName || 'Any Shop Order';
  }

  if (!searchLocation) {
    console.log(`[Auto-Assign] ⚠️ No search location available for order #${order.displayId}`);
    return;
  }

  const nearestDriver = await User.findOne({
    role: 'driver',
    isOnline: true,
    lastLocation: {
      $near: {
        $geometry: searchLocation,
        $maxDistance: settings.maxDispatchRadiusKm * 1000 // meters
      }
    }
  });

  if (nearestDriver) {
    console.log(`[Auto-Assign] ✅ Found nearest driver: ${nearestDriver.name} for order #${order.displayId}`);
    const freshOrder = await Order.findById(order._id);
    const advancedStatuses = ['Preparing', 'Ready', 'HandedOver', 'PickedUp', 'OutForDelivery', 'Delivered', 'Cancelled'];
    
    // Assign driver to order
    freshOrder.driver = nearestDriver._id;
    if (!advancedStatuses.includes(freshOrder.status)) {
      freshOrder.status = 'Assigned';
    }
    await freshOrder.save();

    // Update the local order object reference to emit correct status
    order.driver = freshOrder.driver;
    order.status = freshOrder.status;

    // Notify the specific driver
    io.to(`driver_${nearestDriver._id}`).emit('new_assignment', {
      orderId: order._id,
      displayId: order.displayId,
      vendorName: storeName,
      paymentMethod: order.paymentMethod,
      amount: order.totalAmount,
    });

    // Notify admin to update the list
    io.to('admin').emit('dispatch_update', { message: 'Order Auto-Assigned', orderId: order._id });
  } else {
    console.log(`[Auto-Assign] ⚠️ No online drivers found within ${settings.maxDispatchRadiusKm}km for order #${order.displayId}`);
  }
};

// @desc    Place a new Order
// @route   POST /api/v1/orders
// @access  Public (Mock version without JWT auth middleware yet)
exports.placeOrder = asyncHandler(async (req, res) => {
  const { 
      customer, vendor, items, totalAmount, deliveryCharge, 
      paymentMethod, orderType, textContent, photoUrl,
      deliveryCoordinates // Expected format from mobile: { lat, lng } or similar
    } = req.body;

    // --- GEOFENCING VALIDATION ---
    const settings = await Settings.findOne() || await Settings.create({});
    const activeZones = await ServiceZone.find({ isActive: true });
    
    if (deliveryCoordinates && deliveryCoordinates.lat && deliveryCoordinates.lng) {
      let isWithinAnyZone = false;
      let closestZoneDetails = '';

      // 1. Check all dynamic active zones
      if (activeZones.length > 0) {
        for (const zone of activeZones) {
          const dist = calculateDistance(
            deliveryCoordinates.lat,
            deliveryCoordinates.lng,
            zone.lat,
            zone.lng
          );
          if (dist <= zone.radiusKm) {
            isWithinAnyZone = true;
            break;
          }
        }
      } 
      
      // 2. Fallback to global settings if no dynamic zones are matched or defined
      if (!isWithinAnyZone) {
        const globalDist = calculateDistance(
          deliveryCoordinates.lat,
          deliveryCoordinates.lng,
          settings.serviceCenterLat,
          settings.serviceCenterLng
        );
        if (globalDist <= settings.maxServiceRadiusKm) {
          isWithinAnyZone = true;
        }
      }

      if (!isWithinAnyZone) {
        return res.status(400).json({
          success: false,
          error: `Sorry, we do not serve this location yet. Orders are only allowed within our active service zones.`,
        });
      }
    }

    // Vendor Fee calculation (Commission based on subtotal or totalAmount)
    const isCommissionEnabled = settings.vendorCommissionEnabled !== false;
    const pct = (settings.platformCommissionPct !== undefined && settings.platformCommissionPct !== null) ? settings.platformCommissionPct : 5.0;
    
    let vendorCommissionRate = pct;
    let isVendorCommissionEnabled = true;

    if (vendor && require('mongoose').Types.ObjectId.isValid(vendor)) {
      const vendorObj = await Vendor.findById(vendor);
      if (vendorObj) {
        isVendorCommissionEnabled = vendorObj.commissionEnabled !== false;
        vendorCommissionRate = (vendorObj.commissionRate !== undefined && vendorObj.commissionRate !== null)
          ? (vendorObj.commissionRate * 100)
          : pct;
      }
    }

    const vendorFee = (isCommissionEnabled && isVendorCommissionEnabled) ? (totalAmount * (vendorCommissionRate / 100)) : 0;
    const customerPlatformFee = settings.customerPlatformFeeAmount || 5.0;
    
    // Final total for the order
    const finalTotal = totalAmount > 0 ? (totalAmount + customerPlatformFee) : 0;
    const vendorEarnings = totalAmount > 0 ? (totalAmount - vendorFee) : 0;

    // Create the Order in MongoDB
    const isCustomOrder = vendor === 'CUSTOM_SHOP' || req.body.isCustomStore === true;
    
    // Clean and Resolve Customer
    let customerId = customer;
    const customerName = req.body.customerName || req.body.customerNameOverride;
    const customerPhone = req.body.customerPhone || req.body.customerPhoneOverride;
    const mongoose = require('mongoose');

    if (typeof customer === 'object' && customer.phone) {
        // Clean phone number (remove +91, spaces, dashes)
        const cleanPhone = customer.phone.replace(/\D/g, '').slice(-10);
        
        let user = await User.findOne({ phone: cleanPhone });
        if (!user) {
            user = await User.create({
                name: customer.name || 'Guest Customer',
                phone: cleanPhone,
                role: 'customer',
                password: 'guest_password_123' // Dummy password
            });
        }
        customerId = user._id;
    } else if (typeof customer === 'string' && /^\d{10}$/.test(customer)) {
        // Treat 10-digit numeric string as phone number
        let user = await User.findOne({ phone: customer });
        if (!user) {
            user = await User.create({
                name: customerName || 'New Customer',
                phone: customer,
                role: 'customer',
                password: 'guest_password_123'
            });
        }
        customerId = user._id;
    } else if (customer && mongoose.Types.ObjectId.isValid(customer)) {
        // Check if user exists, otherwise recreate from info (handles post-wipe state)
        let user = await User.findById(customer);
        
        if (!user && customerPhone && customerPhone.length >= 10) {
            try {
                console.log(`[Order] Re-creating user ${customerName} (${customerPhone}) after wipe.`);
                const cleanPhone = customerPhone.replace(/\D/g, '').slice(-10);
                
                // Double check if a user with this phone already exists under a different ID
                let existingUser = await User.findOne({ phone: cleanPhone });
                if (existingUser) {
                    user = existingUser;
                } else {
                    user = await User.create({
                        _id: customer,
                        name: customerName || 'Returning Customer',
                        phone: cleanPhone,
                        role: 'customer',
                        password: 'guest_password_123'
                    });
                }
            } catch (createErr) {
                console.error('[Order] Failed to re-create user:', createErr.message);
            }
        }
        
        // IMPORTANT: Always use the provided ID if it's valid, even if User record is missing.
        customerId = user ? user._id : customer;

    } else if (customerPhone && customerPhone.length >= 10) {
        // We don't have a valid ObjectId, but we DO have a phone number
        const cleanPhone = customerPhone.replace(/\D/g, '').slice(-10);
        let user = await User.findOne({ phone: cleanPhone });
        if (!user) {
            console.log(`[Order] Creating missing user ${customerName} (${customerPhone}) by phone.`);
            user = await User.create({
                name: customerName || 'New Customer',
                phone: cleanPhone,
                role: 'customer',
                password: 'guest_password_123'
            });
        }
        customerId = user._id;
    } else {
        // Ultimate Fallback: Try to use provided info before completely defaulting to guest
        let fallbackPhone = '0000000000';
        let fallbackName = 'Guest Customer';
        
        if (customerPhone && customerPhone.length >= 10) {
            fallbackPhone = customerPhone.replace(/\D/g, '').slice(-10);
        }
        if (customerName) {
            fallbackName = customerName;
        }

        let user = await User.findOne({ phone: fallbackPhone });
        if (!user) {
            console.log(`[Order] Creating fallback user: ${fallbackName} (${fallbackPhone})`);
            user = await User.create({
                name: fallbackName,
                phone: fallbackPhone,
                role: 'customer',
                password: 'guest_password_123'
            });
        } else if (user.name === 'Guest Customer' && fallbackName !== 'Guest Customer') {
            // Update the guest user with the real name if it was previously generic
            user.name = fallbackName;
            await user.save();
        }
        customerId = user._id;
    }

    let initialStatus = 'Pending';
    if (isCustomOrder) {
      initialStatus = 'Accepted'; // Auto-accept if it's a personal assistant request
    } else if (paymentMethod !== 'COD') {
      initialStatus = 'PaymentPending';
    }

    const order = await Order.create({
      customer: customerId,
      vendor: isCustomOrder ? null : vendor,
      items: items || [],
      totalAmount: finalTotal,
      deliveryCharge,
      vendorFee,
      customerPlatformFee,
      vendorEarnings,
      platformFee: vendorFee, // Keep legacy field sync'd with vendorFee
      paymentMethod,
      orderType: orderType || 'Cart',
      textContent,
      photoUrl,
      isCustomStore: isCustomOrder,
      customStoreName: req.body.customStoreName,
      customStoreAddress: req.body.customStoreAddress,
      status: initialStatus,
      deliveryCoordinates: deliveryCoordinates ? {
        type: 'Point',
        coordinates: [deliveryCoordinates.lng, deliveryCoordinates.lat] // GeoJSON: [lng, lat]
      } : undefined,
    });

    // --- REAL-TIME PORTION ---
    const io = req.app.get('socketio');
    
    if (io) {
      console.log(`[Socket] Order Created: ${order._id}, Status: ${initialStatus}`);

      if (initialStatus !== 'PaymentPending') {
        // 1. Notify the Specific Vendor (Skip if it's a custom shop)
        if (!isCustomOrder && vendor) {
          const vendorRoom = `vendor_${vendor.toString()}`;
          console.log(`[Socket] Notifying Vendor: ${vendor} for Order: ${order._id}`);
          io.to(vendorRoom).emit('new_order_alert', {
            orderId: order._id.toString(),
            message: 'New Order Received!',
            orderType: order.orderType,
            itemsCount: (items && items.length) || 0,
            amount: finalTotal,
            displayId: order.displayId
          });
        }

        // 2. Notify all Admins
        io.to('admin').emit('new_order', {
          orderId: order._id.toString(),
          displayId: order.displayId,
          status: order.status,
          vendor: vendor ? vendor.toString() : null
        });
        
        // 3. If Custom Order, immediately notify Admins for Dispatch
        if (isCustomOrder) {
          io.to('admin').emit('new_dispatch_request', {
            orderId: order._id,
            displayId: order.displayId,
            vendorName: req.body.customStoreName || 'Any Shop Order',
            paymentMethod: order.paymentMethod,
            isCustomOrder: true,
          });

          // 4. ATTEMPT AUTO-ASSIGNMENT for custom orders immediately
          await attemptAutoAssignment(order, io);
        }
      }
    }

    // Respond back to customer
    res.status(201).json({
      success: true,
      data: order,
    });
});

// @desc    Get a single Order
// @route   GET /api/v1/orders/:id
// @access  Public
exports.getOrder = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const mongoose = require('mongoose');
    let query = { _id: id };
    
    if (!mongoose.Types.ObjectId.isValid(id)) {
        query = { displayId: id.startsWith('NM-') ? id : `NM-${id}` };
    }

    const order = await Order.findOne(query)
        .populate('customer', 'name phone email')
        .populate('vendor', 'storeName category phone location')
        .populate('driver', 'name phone vehicleType vehicleNumber');

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    res.status(200).json({
      success: true,
      data: order,
    });
});

// @desc    Get all orders for a specific Vendor
// @route   GET /api/v1/orders/vendor/:vendorId
// @access  Public (Should be protected in production)
exports.getVendorOrders = asyncHandler(async (req, res) => {
    // Logic: Only show orders where payment is successful OR it is Cash on Delivery
    const orders = await Order.find({ 
      vendor: req.params.vendorId,
      $or: [
        { paymentStatus: 'Completed' },
        { paymentMethod: 'COD' }
      ]
    })
      .populate('customer', 'name phone')
      .sort({ createdAt: -1 });

    // Final safeguard: if any order's customer didn't populate, provide a placeholder object
    const sanitizedOrders = orders.map(order => {
      const o = order.toObject();
      if (!o.customer || typeof o.customer === 'string') {
        o.customer = { name: 'Customer', phone: '+91 9123456789' };
      }
      return o;
    });

    res.status(200).json({
      success: true,
      count: sanitizedOrders.length,
      data: sanitizedOrders,
    });
});

// @desc    Update Order Status (used by Drivers and Vendors)
// @route   PUT /api/v1/orders/:id/status
// @access  Public
exports.updateOrderStatus = asyncHandler(async (req, res) => {
    const { status, totalAmount, paymentMethod, paymentStatus, driverId } = req.body;
    let updateData = { status };

    if (paymentMethod) updateData.paymentMethod = paymentMethod;
    if (paymentStatus) {
        updateData.paymentStatus = paymentStatus;
        if (paymentStatus === 'Completed') {
            updateData.customerPaid = true;
        }
    }
    if (driverId) {
        updateData.driver = driverId; // Assign driver to order
        // If the order was just Accepted (common for custom) or Pending, move it to Assigned
        // This stops it from matching "Accepted without driver" broadcast filters
        if (status === 'Accepted' || status === 'Pending' || !status) {
            updateData.status = 'Assigned';
        }
    }

    // Removed premature totalAmount calculation, moved below currentOrder fetch

    const { id } = req.params;
    console.log(`[OrderUpdate] 🔄 Received update request for order: ${id}`);
    console.log(`[OrderUpdate] 📦 Data: ${JSON.stringify(req.body)}`);
    const mongoose = require('mongoose');
    let query = { _id: id };
    
    if (!mongoose.Types.ObjectId.isValid(id)) {
        query = { displayId: id.startsWith('NM-') ? id : `NM-${id}` };
    }

    const currentOrder = await Order.findOne(query);
    if (!currentOrder) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // Transition PaymentPending -> Pending on successful payment
    if (updateData.paymentStatus === 'Completed' && currentOrder.status === 'PaymentPending') {
      updateData.status = 'Pending';
    }

    // Calculate new total if vendor provided a quote (sent as totalAmount in req.body)
    if (totalAmount !== undefined && totalAmount !== null) {
      const settings = await require('../models/Settings').findOne() || { platformCommissionPct: 5.0, customerPlatformFeeAmount: 5.0 };
      const isCommissionEnabled = settings.vendorCommissionEnabled !== false;
      const pct = (settings.platformCommissionPct !== undefined && settings.platformCommissionPct !== null) ? settings.platformCommissionPct : 5.0;
      
      // If vendor sends 'totalAmount', they are actually quoting the Subtotal (items price)
      const subTotal = totalAmount; 
      const discount = req.body.discount || 0;
      const finalSubTotal = Math.max(0, subTotal - discount);
      
      const vFee = isCommissionEnabled ? (finalSubTotal * (pct / 100)) : 0;
      const cFee = settings.customerPlatformFeeAmount;
      const deliveryCharge = currentOrder.deliveryCharge || 0;

      updateData.subTotal = subTotal;
      updateData.discount = discount;
      updateData.vendorFee = vFee;
      updateData.customerPlatformFee = cFee;
      updateData.platformFee = vFee; // Legacy
      // Final Total for Customer = Subtotal - Discount + Delivery + Platform Fee
      updateData.totalAmount = finalSubTotal + deliveryCharge + cFee;
      updateData.vendorEarnings = finalSubTotal - vFee;
    }

    // Prevent status downgrades during driver assignment/acceptance/payment
    const advancedStatuses = ['Accepted', 'Assigned', 'Preparing', 'Ready', 'HandedOver', 'PickedUp', 'OutForDelivery', 'Delivered'];
    if ((status === 'Accepted' || status === 'Assigned' || status === 'Pending' || updateData.status === 'Assigned') && 
        advancedStatuses.includes(currentOrder.status)) {
      // Keep existing advanced status, only update other fields like totalAmount
      delete updateData.status;
    }

    const order = await Order.findOneAndUpdate(query, updateData, { new: true });

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // Ping all participants
    const io = req.app.get('socketio');
    if (io) {
        const orderRoom = `order_${order._id.toString()}`;
        const customerRoom = `customer_${order.customer ? order.customer.toString() : 'guest'}`;
        const vendorRoom = order.vendor ? `vendor_${order.vendor.toString()}` : null;

        // Get customer phone if possible for dual-room notification
        let customerPhoneRoom = null;
        if (order.customer) {
            const customerUser = await User.findById(order.customer).select('phone');
            if (customerUser && customerUser.phone) {
                customerPhoneRoom = `customer_${customerUser.phone}`;
            }
        }

        console.log(`[Socket] Emitting update to ${orderRoom}, ${customerRoom}${customerPhoneRoom ? ', ' + customerPhoneRoom : ''}, ${vendorRoom}`);
        
        const payload = {
            orderId: order._id.toString(),
            status: order.status,
            displayId: order.displayId,
            totalAmount: order.totalAmount,
            paymentMethod: order.paymentMethod,
            customerPlatformFee: order.customerPlatformFee,
            deliveryCharge: order.deliveryCharge,
            subTotal: order.subTotal || 0,
            discount: order.discount || 0,
        };

        io.to(orderRoom).emit('order_status_update', payload);
        io.to(customerRoom).emit('order_status_update', payload);
        if (customerPhoneRoom) io.to(customerPhoneRoom).emit('order_status_update', payload);
        if (vendorRoom) io.to(vendorRoom).emit('order_status_update', payload);
        io.to('admin').emit('dispatch_update', { message: `Order status updated to ${order.status}`, orderId: order._id.toString() });
    }

    // Notify Admins about successfull customer payment ONLY ON TRANSITION to Completed
    if (order.paymentStatus === 'Completed' && currentOrder.paymentStatus !== 'Completed') {
      const populatedOrder = await Order.findById(order._id).populate('customer', 'name');
      const customerName = (populatedOrder.customer && populatedOrder.customer.name) || 'A Customer';
      io.to('admin').emit('customer_payment_received', {
        orderId: order._id,
        displayId: order.displayId,
        customerName: customerName,
        amount: order.totalAmount,
        isCustomOrder: order.isCustomStore || order.orderType !== 'Cart', 
      });

      // If the order was awaiting payment, it is now fully placed. Alert vendor and admin!
      if (currentOrder.status === 'PaymentPending') {
        const isCustomOrder = order.isCustomStore || order.orderType !== 'Cart';
        
        if (!isCustomOrder && order.vendor) {
          const vendorRoom = `vendor_${order.vendor.toString()}`;
          console.log(`[Socket] Delayed Notification to Vendor: ${order.vendor} for Order: ${order._id}`);
          io.to(vendorRoom).emit('new_order_alert', {
            orderId: order._id.toString(),
            message: 'New Order Received!',
            orderType: order.orderType,
            itemsCount: (order.items && order.items.length) || 0,
            amount: order.totalAmount,
            displayId: order.displayId
          });
        }

        io.to('admin').emit('new_order', {
          orderId: order._id.toString(),
          displayId: order.displayId,
          status: order.status,
          vendor: order.vendor ? order.vendor.toString() : null
        });
      }
    }

    // Special: If price is updated for a Custom/Text order, send a quote event
    if (totalAmount && (order.isCustomStore || order.orderType !== 'Cart')) {
      const room1 = `customer_${order.customer.toString()}`;
      console.log(`[Socket] 💰 Emitting order_price_updated to Room: ${room1}`);
      io.to(room1).emit('order_price_updated', {
        orderId: order._id.toString(),
        totalAmount: order.totalAmount,
        customerPlatformFee: order.customerPlatformFee,
        deliveryCharge: order.deliveryCharge,
        subTotal: order.subTotal || 0,
        discount: order.discount || 0,
      });

      // Also notify by phone if available
      const customerUser = await User.findById(order.customer).select('phone');
      if (customerUser && customerUser.phone) {
        const room2 = `customer_${customerUser.phone}`;
        console.log(`[Socket] 💰 Emitting order_price_updated to Phone Room: ${room2}`);
        io.to(room2).emit('order_price_updated', {
          orderId: order._id.toString(),
          totalAmount: order.totalAmount,
          customerPlatformFee: order.customerPlatformFee,
          deliveryCharge: order.deliveryCharge,
          subTotal: order.subTotal || 0,
          discount: order.discount || 0,
        });
      }
    }

    // 1. Notify Admins to refresh Dispatch lists (new prices, etc.)
    io.to('admin').emit('dispatch_update', { 
      message: 'Order details updated',
      orderId: order._id,
      order: order
    });

    // 2. Notify the Vendor if they are assigned
    // 2. Notify the Vendor if they are assigned
    if (order.vendor) {
      // Check if we should send a 'new_order_alert' if they weren't notified at placement (for online payments)

      io.to(`vendor_${order.vendor.toString()}`).emit('order_status_update', {
        orderId: order._id,
        status: order.status,
        paymentStatus: order.paymentStatus,
        customerPaid: order.customerPaid,
        displayId: order.displayId,
        totalAmount: order.totalAmount,
      });
    }

    // 3. Notify assigned Driver (if any)
    if (order.driver) {
      io.to(`driver_${order.driver.toString()}`).emit('order_status_update', {
        orderId: order._id,
        status: order.status,
        displayId: order.displayId,
        totalAmount: order.totalAmount,
        paymentMethod: order.paymentMethod,
      });

      // If this is a NEW assignment (driver was just added), send the full new_assignment alert
      if (driverId && (!currentOrder.driver || currentOrder.driver.toString() !== driverId.toString())) {
        const populatedOrder = await Order.findById(order._id).populate('vendor', 'storeName');
        const vendorName = (populatedOrder.vendor && populatedOrder.vendor.storeName) || order.customStoreName || 'Any Shop Order';
        
        io.to(`driver_${order.driver.toString()}`).emit('new_assignment', {
          orderId: order._id,
          displayId: order.displayId,
          vendorName: vendorName,
          paymentMethod: order.paymentMethod,
          amount: order.totalAmount,
        });
      }
    }

    // Notify admin ONLY when vendor accepts (just transitioned to Accepted) AND no driver is assigned
    if (order.status === 'Accepted' && !order.driver && currentOrder.status !== 'Accepted') {
      // Populate vendor to get storeName
      await order.populate('vendor', 'storeName');
      const storeName = order.vendor?.storeName || 'Unknown Store';

      // 1. Notify Admin for the Live Dispatch list
      io.to('admin').emit('new_dispatch_request', {
        orderId: order._id,
        displayId: order.displayId,
        vendorName: storeName,
        paymentMethod: order.paymentMethod,
        message: `Order Accepted by ${storeName}`,
        vendorAccepted: true
      });

      // 2. ATTEMPT AUTO-ASSIGNMENT for standard orders
      await attemptAutoAssignment(order, io);
    }

    res.status(200).json({ success: true, data: order });
});

// @desc    Get current assigned orders for a specific driver
// @route   GET /api/v1/orders/driver/:driverId
exports.getDriverOrders = asyncHandler(async (req, res) => {
    console.log(`[DriverSync] 🔍 Fetching orders for driver: ${req.params.driverId}`);
    const orders = await Order.find({
      driver: req.params.driverId,
      status: { $in: ['Pending', 'Accepted', 'Confirmed', 'Assigned', 'Preparing', 'Ready', 'HandedOver', 'PickedUp', 'OutForDelivery', 'On The Way'] },
    })
      .populate('customer', 'name phone')
      .populate('vendor', 'storeName category location')
      .sort({ createdAt: -1 });

    console.log(`[DriverSync] ✅ Found ${orders.length} active orders for driver.`);
    if (orders.length > 0) {
      console.log(`[DriverSync] 📦 Order IDs: ${orders.map(o => o.displayId).join(', ')}`);
    }

    res.status(200).json({
      success: true,
      count: orders.length,
      data: orders,
    });
});
// @desc    Get order history for a specific driver (Delivered or Cancelled)
// @route   GET /api/v1/orders/driver/:driverId/history
exports.getDriverHistory = asyncHandler(async (req, res) => {
    const orders = await Order.find({
      driver: req.params.driverId,
      status: { $in: ['Delivered', 'Cancelled'] },
    })
      .populate('customer', 'name phone')
      .populate('vendor', 'storeName category location')
      .sort({ updatedAt: -1 });

    res.status(200).json({
      success: true,
      count: orders.length,
      data: orders,
    });
});

// @desc    Get order history for a specific customer
// @route   GET /api/v1/orders/customer/:customerId
exports.getCustomerOrders = asyncHandler(async (req, res) => {
    let searchId = req.params.customerId;
    
    // Resolve phone number if passed as customerId
    if (/^\d{10}$/.test(searchId)) {
        const user = await User.findOne({ phone: searchId });
        if (user) {
            searchId = user._id;
        } else {
            // No user with this phone, return empty
            return res.status(200).json({ success: true, count: 0, data: [] });
        }
    } else if (!require('mongoose').Types.ObjectId.isValid(searchId)) {
        // Handle other non-ObjectId cases (like mock_user_123 fallback to guest)
        const user = await User.findOne({ phone: '0000000000' });
        if (user) searchId = user._id;
    }

    const orders = await Order.find({ customer: searchId })
      .populate('vendor', 'storeName category location')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: orders.length,
      data: orders,
    });
});

// @desc    Driver declines an assigned order (removes driver, notifies admin to re-dispatch)
// @route   PUT /api/v1/orders/:id/decline
exports.declineOrder = asyncHandler(async (req, res) => {
    const currentOrder = await Order.findById(req.params.id);
    if (!currentOrder) return res.status(404).json({ success: false, error: 'Order not found' });

    const driverId = currentOrder.driver;
    if (driverId) {
      // Increment declinedCount for the driver
      await User.findByIdAndUpdate(driverId, { $inc: { declinedCount: 1 } });
    }

    const order = await Order.findByIdAndUpdate(
      req.params.id,
      { $unset: { driver: 1 }, status: 'Accepted' },
      { new: true }
    );

    const io = req.app.get('socketio');
    await order.populate('vendor', 'storeName');
    const storeName = order.vendor?.storeName || 'Unknown Store';

    // Notify admin to re-dispatch
    io.to('admin').emit('new_dispatch_request', {
      orderId: order._id,
      displayId: order.displayId,
      vendorName: storeName,
      reDispatched: true,
    });

    res.status(200).json({ success: true, data: order });
});

// @desc    Upload Shop Bill Photo for an Order
// @route   PUT /api/v1/orders/:id/bill
// @access  Public
exports.uploadOrderBill = asyncHandler(async (req, res) => {
    try {
        const { id } = req.params;
        console.log(`[Bill-Upload] 📸 Incoming bill upload for Order ID: ${id}`);
        console.log(`[Bill-Upload] 🔑 User: ${req.user ? req.user.phone : 'Anonymous'}`);

        if (!req.file) {
            console.warn(`[Bill-Upload] ⚠️ No file found in request for Order ID: ${id}`);
            return res.status(400).json({ success: false, error: 'Please upload a bill photo' });
        }

        console.log(`[Bill-Upload] 📄 File received: ${req.file.originalname} (${req.file.mimetype}, ${req.file.size} bytes)`);

        const mongoose = require('mongoose');
        let query = { _id: id };
        
        if (!mongoose.Types.ObjectId.isValid(id)) {
            query = { displayId: id.startsWith('NM-') ? id : `NM-${id}` };
            console.log(`[Bill-Upload] 🔍 Searching by Display ID: ${query.displayId}`);
        }

        const order = await Order.findOneAndUpdate(
            query,
            { 
                billPhotoPath: `/public/uploads/${req.file.filename}`,
                billUploadedAt: new Date()
            },
            { new: true }
        );

        if (!order) {
            console.error(`[Bill-Upload] ❌ Order not found for ID/DisplayID: ${id}`);
            return res.status(404).json({ success: false, error: 'Order not found' });
        }

        console.log(`[Bill-Upload] ✅ Bill updated for Order: ${order.displayId || order._id}`);

        // Notify customer and admin that bill is uploaded
        const io = req.app.get('socketio');
        if (io) {
            const msg = { orderId: order._id, billPhotoPath: order.billPhotoPath };
            io.to(`customer_${order.customer.toString()}`).emit('bill_uploaded', msg);
            io.to('admin').emit('dispatch_update', { message: 'Bill Uploaded', orderId: order._id });
        }

        res.status(200).json({
            success: true,
            data: order,
        });
    } catch (error) {
        console.error(`[Bill-Upload] 🔥 FATAL ERROR:`, error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// @desc    Upload Vendor Payment Details (QR or UPI Number)
// @route   PUT /api/v1/orders/:id/vendor-payment-details
// @access  Public
exports.uploadVendorPaymentDetails = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { upiNumber } = req.body;
    
    const mongoose = require('mongoose');
    let query = { _id: id };
    
    if (!mongoose.Types.ObjectId.isValid(id)) {
        query = { displayId: id.startsWith('NM-') ? id : `NM-${id}` };
    }

    let updateData = { vendorPaymentDetailsUploadedByDriver: true };
    if (upiNumber) updateData.vendorUpiNumber = upiNumber;
    if (req.file) updateData.vendorUpiQrPath = `/public/vendor_qrs/${req.file.filename}`;

    const order = await Order.findOneAndUpdate(query, updateData, { new: true }).populate('vendor', 'storeName');

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // Ping Admin that a new vendor payment is requested
    const io = req.app.get('socketio');
    io.to('admin').emit('new_vendor_payment_request', {
      orderId: order._id,
      displayId: order.displayId,
      vendorName: order.vendor?.storeName || order.customStoreName || 'Vendor',
      amount: order.totalAmount,
    });

    res.status(200).json({ success: true, data: order });
});

// @desc    Admin marks vendor as paid
// @route   PUT /api/v1/orders/:id/admin-pay-vendor
// @access  Public
exports.markVendorPaidByAdmin = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const mongoose = require('mongoose');
    let query = { _id: id };
    
    if (!mongoose.Types.ObjectId.isValid(id)) {
        query = { displayId: id.startsWith('NM-') ? id : `NM-${id}` };
    }

    const order = await Order.findOneAndUpdate(
        query,
        { vendorPaymentStatus: 'Completed' },
        { new: true }
    );

    if (!order) {
      return res.status(404).json({ success: false, error: 'Order not found' });
    }

    // Ping Driver that payment is done
    const io = req.app.get('socketio');
    if (order.driver) {
      io.to(`driver_${order.driver.toString()}`).emit('vendor_payment_completed', {
        orderId: order._id,
      });
    }

    // Ping Vendor that payment is done
    if (order.vendor) {
      io.to(`vendor_${order.vendor}`).emit('vendor_payment_completed', {
        orderId: order._id,
        vendorPaymentStatus: order.vendorPaymentStatus,
      });
    }

    // Ping Admin list to refresh
    io.to('admin').emit('vendor_payment_update', { orderId: order._id });

    res.status(200).json({ success: true, data: order });
});

