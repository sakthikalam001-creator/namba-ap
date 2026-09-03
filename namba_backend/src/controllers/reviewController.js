const Review = require('../models/Review');
const Order = require('../models/Order');
const Vendor = require('../models/Vendor');
const User = require('../models/User');

// @desc    Get reviews for a vendor
// @route   GET /api/v1/reviews/vendor/:vendorId
// @access  Public
exports.getVendorReviews = async (req, res, next) => {
  try {
    const { vendorId } = req.params;

    const reviews = await Review.find({ 
      $or: [
        { vendor: vendorId },
        { targetType: 'vendor', vendor: vendorId },
      ]
    })
      .sort('-createdAt')
      .lean();

    // Compute rating metrics
    const totalCount = reviews.length;
    let sum = 0;
    const counts = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    const tagsCount = {};

    reviews.forEach(r => {
      const val = Math.min(5, Math.max(1, Number(r.rating) || 5));
      sum += val;
      const rounded = Math.round(val);
      counts[rounded] = (counts[rounded] || 0) + 1;

      if (Array.isArray(r.tags)) {
        r.tags.forEach(tag => {
          if (tag) tagsCount[tag] = (tagsCount[tag] || 0) + 1;
        });
      }
    });

    const averageRating = totalCount > 0 ? parseFloat((sum / totalCount).toFixed(1)) : 5.0;

    res.status(200).json({
      success: true,
      data: {
        reviews,
        totalCount,
        averageRating,
        counts,
        tags: tagsCount,
      },
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Get real reviews & rating for a driver
// @route   GET /api/v1/reviews/driver/:driverId
// @access  Public
exports.getDriverReviews = async (req, res, next) => {
  try {
    const { driverId } = req.params;

    const reviews = await Review.find({ 
      $or: [
        { driver: driverId },
        { targetType: 'driver', driver: driverId },
      ]
    })
      .sort('-createdAt')
      .lean();

    const totalCount = reviews.length;
    let sum = 0;
    let totalTips = 0;
    const counts = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
    const tagsCount = {};

    reviews.forEach(r => {
      const val = Math.min(5, Math.max(1, Number(r.rating) || 5));
      sum += val;
      const rounded = Math.round(val);
      counts[rounded] = (counts[rounded] || 0) + 1;

      if (r.tip) totalTips += Number(r.tip) || 0;

      if (Array.isArray(r.tags)) {
        r.tags.forEach(tag => {
          if (tag) tagsCount[tag] = (tagsCount[tag] || 0) + 1;
        });
      }
    });

    const averageRating = totalCount > 0 ? parseFloat((sum / totalCount).toFixed(1)) : null;

    res.status(200).json({
      success: true,
      data: {
        reviews,
        totalCount,
        averageRating,
        counts,
        tags: tagsCount,
        totalTips,
      },
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Create real reviews for an order (Vendor + Driver)
// @route   POST /api/v1/reviews
// @access  Public
exports.createReview = async (req, res, next) => {
  try {
    const { 
      orderId, 
      customerName, 
      customerId,
      // Vendor Feedback
      vendorId: rawVendorId,
      vendorRating,
      vendorComment,
      vendorTags,
      // Rider / Driver Feedback
      driverId: rawDriverId,
      driverRating,
      driverComment,
      driverTags,
      driverTip,
      // Legacy Fallbacks
      rating, 
      comment,
    } = req.body;

    let vendorId = rawVendorId;
    let driverId = rawDriverId;
    let custId = customerId;
    let custName = customerName || 'Customer';
    let orderType = 'Food Order';
    let storeName = 'Store';
    let driverName = 'Driver';

    let orderDoc = null;
    if (orderId) {
      orderDoc = await Order.findById(orderId).populate('vendor driver customer');
      if (orderDoc) {
        if (orderDoc.vendor) {
          vendorId = orderDoc.vendor._id ? orderDoc.vendor._id.toString() : orderDoc.vendor.toString();
          storeName = orderDoc.vendor.storeName || orderDoc.storeName || 'Store';
        }
        if (orderDoc.driver) {
          driverId = orderDoc.driver._id ? orderDoc.driver._id.toString() : orderDoc.driver.toString();
          driverName = orderDoc.driver.name || 'Driver';
        }
        if (orderDoc.customer) {
          custId = orderDoc.customer._id ? orderDoc.customer._id.toString() : orderDoc.customer.toString();
          custName = orderDoc.customer.name || custName;
        }
        orderType = orderDoc.orderType ? `${orderDoc.orderType} Order` : 'Food Order';
      }
    }

    const createdReviews = [];

    // 1. Process Vendor Rating & Review
    const vRatingVal = vendorRating != null ? parseFloat(vendorRating) : (rating != null ? parseFloat(rating) : null);
    if (vRatingVal != null && vRatingVal > 0 && vendorId) {
      const numericVendorRating = Math.min(5, Math.max(1, vRatingVal));
      const vCommentStr = vendorComment || comment || '';
      const vTagsArr = Array.isArray(vendorTags) ? vendorTags : [];

      const vendorRev = await Review.create({
        order: orderId || null,
        vendor: vendorId,
        customer: custId || null,
        customerName: custName,
        rating: numericVendorRating,
        comment: vCommentStr,
        tags: vTagsArr,
        targetType: 'vendor',
        orderType,
      });
      createdReviews.push(vendorRev);

      // Recalculate real Vendor average rating & review count
      const allVendorReviews = await Review.find({ 
        $or: [
          { vendor: vendorId },
          { targetType: 'vendor', vendor: vendorId }
        ]
      });
      const totalReviews = allVendorReviews.length;
      const avgRating = totalReviews > 0
        ? parseFloat((allVendorReviews.reduce((sum, r) => sum + (Number(r.rating) || 5), 0) / totalReviews).toFixed(1))
        : 5.0;

      await Vendor.findByIdAndUpdate(vendorId, {
        rating: avgRating,
        numReviews: totalReviews,
      });

      console.log(`[Review] ⭐ Vendor "${storeName}" rated ${numericVendorRating}★ by ${custName} (New Avg: ${avgRating}★, Total: ${totalReviews})`);
    }

    // 2. Process Driver / Rider Rating & Review
    const dRatingVal = driverRating != null ? parseFloat(driverRating) : null;
    if (dRatingVal != null && dRatingVal > 0 && driverId) {
      const numericDriverRating = Math.min(5, Math.max(1, dRatingVal));
      const dCommentStr = driverComment || '';
      const dTagsArr = Array.isArray(driverTags) ? driverTags : [];
      const dTipNum = driverTip != null ? Math.max(0, parseFloat(driverTip) || 0) : 0;

      const driverRev = await Review.create({
        order: orderId || null,
        driver: driverId,
        customer: custId || null,
        customerName: custName,
        rating: numericDriverRating,
        comment: dCommentStr,
        tags: dTagsArr,
        targetType: 'driver',
        tip: dTipNum,
        orderType,
      });
      createdReviews.push(driverRev);

      // Recalculate real Driver average rating & review count
      const allDriverReviews = await Review.find({ 
        $or: [
          { driver: driverId },
          { targetType: 'driver', driver: driverId }
        ]
      });
      const totalDriverReviews = allDriverReviews.length;
      const driverAvgRating = totalDriverReviews > 0
        ? parseFloat((allDriverReviews.reduce((sum, r) => sum + (Number(r.rating) || 5), 0) / totalDriverReviews).toFixed(1))
        : 5.0;

      await User.findByIdAndUpdate(driverId, {
        rating: driverAvgRating,
        ratingCount: totalDriverReviews,
      });

      console.log(`[Review] 🛵 Driver "${driverName}" rated ${numericDriverRating}★ by ${custName} (New Avg: ${driverAvgRating}★, Total: ${totalDriverReviews})`);

      // Real-time Socket Notification to Driver
      const io = req.app.get('socketio');
      if (io) {
        io.emit(`driver_rating_updated_${driverId}`, {
          rating: driverAvgRating,
          ratingCount: totalDriverReviews,
          newRating: numericDriverRating,
          comment: dCommentStr,
          tags: dTagsArr,
        });
        io.emit('driver_rating_sync', {
          driverId,
          rating: driverAvgRating,
          ratingCount: totalDriverReviews,
        });
      }
    }

    // 3. Update Order Document in MongoDB
    if (orderId) {
      const updatePayload = {};
      if (vRatingVal != null) {
        updatePayload.userRating = Math.min(5, Math.max(1, vRatingVal));
        updatePayload.userReview = vendorComment || comment || '';
        updatePayload.vendorRating = Math.min(5, Math.max(1, vRatingVal));
        updatePayload.vendorRatingComment = vendorComment || comment || '';
        if (Array.isArray(vendorTags)) updatePayload.vendorTags = vendorTags;
      }
      if (dRatingVal != null) {
        updatePayload.driverRating = Math.min(5, Math.max(1, dRatingVal));
        updatePayload.driverRatingComment = driverComment || '';
        if (Array.isArray(driverTags)) updatePayload.driverTags = driverTags;
        if (driverTip != null) updatePayload.driverTip = parseFloat(driverTip) || 0;
      }

      if (Object.keys(updatePayload).length > 0) {
        await Order.findByIdAndUpdate(orderId, updatePayload);
      }
    }

    // 4. Real-time Socket Notification to Admin
    const io = req.app.get('socketio');
    if (io) {
      io.emit('new_review_submitted', {
        orderId,
        vendorRating: vRatingVal,
        driverRating: dRatingVal,
        customerName: custName,
        storeName,
        driverName,
      });
    }

    res.status(201).json({
      success: true,
      message: 'Reviews submitted and calculated successfully',
      data: createdReviews,
    });
  } catch (err) {
    next(err);
  }
};
