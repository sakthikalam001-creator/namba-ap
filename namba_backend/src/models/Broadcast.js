const mongoose = require('mongoose');

const broadcastSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  message: {
    type: String,
    required: true,
    trim: true,
  },
  category: {
    type: String,
    enum: ['announcement', 'emergency', 'promotional', 'maintenance', 'surge_incentive'],
    default: 'announcement',
  },
  priority: {
    type: String,
    enum: ['normal', 'high', 'urgent'],
    default: 'normal',
  },
  targetAudience: {
    type: [String],
    enum: ['drivers', 'vendors', 'customers', 'all'],
    default: ['all'],
  },
  sendMode: {
    type: String,
    enum: ['mass', 'individual'],
    default: 'mass',
  },
  individualRecipient: {
    userType: { type: String, enum: ['driver', 'vendor', 'customer'] },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    name: { type: String },
    phone: { type: String },
  },
  posterTheme: {
    type: String,
    default: 'none', // none, biryani_feast, monsoon_surge, mega_discount, rider_bonus, vendor_promo, custom
  },
  posterImageUrl: {
    type: String,
    default: '',
  },
  isPopupAd: {
    type: Boolean,
    default: false,
  },
  ctaText: {
    type: String,
    default: 'VIEW DETAILS',
  },
  ctaRoute: {
    type: String,
    default: '',
  },
  city: {
    type: String,
    default: 'all',
  },
  actionRoute: {
    type: String,
    default: '',
  },
  imageUrl: {
    type: String,
    default: '',
  },
  sentBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
  },
  senderName: {
    type: String,
    default: 'System Admin',
  },
  reachCount: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Broadcast', broadcastSchema);
