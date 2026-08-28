const Review = require('../models/Review');
const Order = require('../models/Order');
const Vendor = require('../models/Vendor');

// @desc    Get reviews for a vendor
// @route   GET /api/v1/reviews/vendor/:vendorId
// @access  Public
exports.getVendorReviews = async (req, res, next) => {
  try {
    const { vendorId } = req.params;

    const reviews = await Review.find({ vendor: vendorId })
      .sort('-createdAt')
      .lean();

    // Compute rating metrics
    const totalCount = reviews.length;
    let sum = 0;
    const counts = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };

    reviews.forEach(r => {
      sum += (r.rating || 5);
      const rounded = Math.min(5, Math.max(1, Math.round(r.rating || 5)));
      counts[rounded] = (counts[rounded] || 0) + 1;
    });

    const averageRating = totalCount > 0 ? parseFloat((sum / totalCount).toFixed(1)) : 5.0;

    res.status(200).json({
      success: true,
      data: {
        reviews,
        totalCount,
        averageRating,
        counts,
      },
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Create a review for an order
// @route   POST /api/v1/reviews
// @access  Public
exports.createReview = async (req, res, next) => {
  try {
    const { orderId, rating, comment, customerName } = req.body;

    let vendorId = req.body.vendorId;
    let customerId = req.body.customerId;
    let orderType = 'Order';

    let driverId = req.body.driverId;
    if (orderId) {
      const order = await Order.findById(orderId);
      if (order) {
        if (order.vendor) vendorId = order.vendor.toString();
        if (order.driver) driverId = order.driver.toString();
        if (order.customer) customerId = order.customer.toString();
        orderType = order.orderType ? `${order.orderType} Order` : 'Food Order';
      }
    }

    const review = await Review.create({
      order: orderId || null,
      vendor: vendorId || null,
      driver: driverId || null,
      customer: customerId || null,
      customerName: customerName || 'Customer',
      rating: parseFloat(rating) || 5,
      comment: comment || '',
      orderType,
    });

    // Update Vendor average rating & review count
    if (vendorId) {
      const allVendorReviews = await Review.find({ vendor: vendorId });
      const totalReviews = allVendorReviews.length;
      const avgRating = totalReviews > 0
        ? parseFloat((allVendorReviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews).toFixed(1))
        : 5.0;

      await Vendor.findByIdAndUpdate(vendorId, {
        rating: avgRating,
        numReviews: totalReviews,
      });
    }

    // Update Driver average rating
    if (driverId) {
      const User = require('../models/User');
      const allDriverReviews = await Review.find({ driver: driverId });
      const totalDriverReviews = allDriverReviews.length;
      const driverAvgRating = totalDriverReviews > 0
        ? parseFloat((allDriverReviews.reduce((sum, r) => sum + r.rating, 0) / totalDriverReviews).toFixed(1))
        : 5.0;

      await User.findByIdAndUpdate(driverId, {
        rating: driverAvgRating,
      });
    }

    res.status(201).json({
      success: true,
      data: review,
    });
  } catch (err) {
    next(err);
  }
};
