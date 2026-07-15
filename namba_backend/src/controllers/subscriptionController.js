const SubscriptionPlan = require('../models/SubscriptionPlan');

// @desc    Get all subscription plans
// @route   GET /api/v1/subscriptions
// @access  Public
exports.getSubscriptions = async (req, res) => {
  try {
    const plans = await SubscriptionPlan.find({ isActive: true }).sort('price');
    res.status(200).json({ success: true, data: plans });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get all subscription plans (Admin)
// @route   GET /api/v1/admin/subscriptions
// @access  Admin
exports.getAdminSubscriptions = async (req, res) => {
  try {
    const plans = await SubscriptionPlan.find().sort('price');
    res.status(200).json({ success: true, data: plans });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Create a subscription plan
// @route   POST /api/v1/admin/subscriptions
// @access  Admin
exports.createSubscriptionPlan = async (req, res) => {
  try {
    const plan = await SubscriptionPlan.create(req.body);
    res.status(201).json({ success: true, data: plan });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// @desc    Update a subscription plan
// @route   PUT /api/v1/admin/subscriptions/:id
// @access  Admin
exports.updateSubscriptionPlan = async (req, res) => {
  try {
    const plan = await SubscriptionPlan.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!plan) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }

    res.status(200).json({ success: true, data: plan });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};

// @desc    Delete a subscription plan
// @route   DELETE /api/v1/admin/subscriptions/:id
// @access  Admin
exports.deleteSubscriptionPlan = async (req, res) => {
  try {
    const plan = await SubscriptionPlan.findByIdAndDelete(req.params.id);

    if (!plan) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }

    res.status(200).json({ success: true, data: {} });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
};
