const SubscriptionPlan = require('../models/SubscriptionPlan');

const defaultPlans = [
  {
    name: 'Starter (ஆரம்பம்)',
    price: 299,
    period: 'month',
    features: [
      'Up to 150 Orders / month',
      'Standard Listing on Customer App',
      'Live Store Management Dashboard',
      'Store Timing & Open/Close Controls',
      'Standard 5% Commission',
      'Email & In-App Ticket Support'
    ],
    icon: 'flash_circle',
    color: '#059669',
    isPopular: false,
    isActive: true
  },
  {
    name: 'Growth (வளர்ச்சி)',
    price: 999,
    period: 'month',
    features: [
      'Unlimited Orders & Menu Catalog',
      'Top Search & Category Hero Listing',
      'Reduced 3% Commission Rate',
      'Real-Time Customer Analytics',
      'Special Offer Badges & Promo Tags',
      'Priority Dispatch & Support'
    ],
    icon: 'status_up',
    color: '#4F46E5',
    isPopular: true,
    isActive: true
  },
  {
    name: 'Business Pro (வணிகம் ப்ரோ)',
    price: 2499,
    period: 'month',
    features: [
      '0% Commission on Food & Cart Orders',
      'Verified Gold Partner Trust Badge',
      'Top Banner Ad on Customer App',
      'Instant 15-Minute Payout Clearances',
      'Dedicated 24/7 Account Manager',
      'Custom Push Broadcasts to Nearby Users'
    ],
    icon: 'crown',
    color: '#D97706',
    isPopular: false,
    isActive: true
  },
  {
    name: 'Enterprise VIP (வருடாந்திர விஐபி)',
    price: 7999,
    period: 'year',
    features: [
      'All Business Pro Features for 365 Days',
      '0% Platform Commission Year-Round',
      'Free Product Photography Session',
      'VIP Priority Delivery Assignment',
      'Custom Marketing Campaign Studio',
      'Direct Hotline to Dispatch Center'
    ],
    icon: 'magicpen',
    color: '#7C3AED',
    isPopular: false,
    isActive: true
  }
];

// @desc    Get all subscription plans
// @route   GET /api/v1/subscriptions
// @access  Public
exports.getSubscriptions = async (req, res) => {
  try {
    let plans = await SubscriptionPlan.find({ isActive: true }).sort('price');
    if (!plans || plans.length === 0) {
      await SubscriptionPlan.insertMany(defaultPlans);
      plans = await SubscriptionPlan.find({ isActive: true }).sort('price');
    }
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
    let plans = await SubscriptionPlan.find().sort('price');
    if (!plans || plans.length === 0) {
      await SubscriptionPlan.insertMany(defaultPlans);
      plans = await SubscriptionPlan.find().sort('price');
    }
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
