const mongoose = require('mongoose');

const SubscriptionPlanSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please add a plan name'],
    unique: true,
    trim: true,
  },
  price: {
    type: Number,
    required: [true, 'Please add a plan price'],
  },
  period: {
    type: String,
    default: 'month',
  },
  features: {
    type: [String],
    default: [],
  },
  icon: {
    type: String,
    default: 'flash_circle',
  },
  color: {
    type: String,
    default: '#00BFA5', // Teal
  },
  isPopular: {
    type: Boolean,
    default: false,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('SubscriptionPlan', SubscriptionPlanSchema);
