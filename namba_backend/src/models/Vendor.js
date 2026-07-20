const mongoose = require('mongoose');

const VendorSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.ObjectId,
    ref: 'User',
    required: true,
  },
  storeName: {
    type: String,
    required: [true, 'Please add a store name'],
    trim: true,
  },
  ownerName: {
    type: String,
    trim: true,
  },
  phone: {
    type: String,
    trim: true,
  },
  address: {
    type: String,
    trim: true,
  },
  category: {
    type: String,
    enum: ['Grocery', 'Bakery', 'Medicine', 'Food', 'Fruits & Vegetables'],
    required: true,
  },
  businessEmail: {
    type: String,
    trim: true,
    lowercase: true,
  },
  gstNumber: {
    type: String,
    trim: true,
    uppercase: true,
  },
  panNumber: {
    type: String,
    trim: true,
    uppercase: true,
  },
  // ── APPROVAL SYSTEM ─────────────────────────────────────────────────
  approvalStatus: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending',
  },
  rejectionReason: {
    type: String,
    default: '',
  },
  approvedAt: {
    type: Date,
  },
  // ────────────────────────────────────────────────────────────────────
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number],
      default: [77.7172, 11.3410], // Default: Erode
      index: '2dsphere',
    },
    formattedAddress: String,
    city: String,
    pincode: String,
  },
  isOpen: {
    type: Boolean,
    default: false,
  },
  rating: {
    type: Number,
    min: 0,
    max: 5,
    default: 0,
  },
  deliveryRadiusKm: {
    type: Number,
    default: 20,
  },
  commissionRate: {
    type: Number,
    default: 0.05,
  },
  commissionEnabled: {
    type: Boolean,
    default: true,
  },
  storeImages: {
    type: [String],
    default: [],
  },
  // ── SUBSCRIPTION SYSTEM ─────────────────────────────────────────────
  subscriptionPlan: {
    type: String,
    enum: ['None', 'Basic', 'Premium', 'Pro'],
    default: 'None',
  },
  subscriptionExpiry: {
    type: Date,
  },
  isSubscribed: {
    type: Boolean,
    default: false,
  },
  trialExpiry: {
    type: Date,
  },
  isLocked: {
    type: Boolean,
    default: false,
  },
  isManuallyUnlocked: {
    type: Boolean,
    default: false,
  },
  lockReason: {
    type: String,
  },
  showSubscriptionBadge: {
    type: Boolean,
    default: true,
  },
  // ── FEATURE PERMISSIONS ─────────────────────────────────────────────
  permissions: {
    allowAutoAccept: {
      type: Boolean,
      default: true,
    },
    allowSurgeBoost: {
      type: Boolean,
      default: true,
    },
    allowExtraWait: {
      type: Boolean,
      default: true,
    },
  },
  // ────────────────────────────────────────────────────────────────────
}, {
  timestamps: true,
});

module.exports = mongoose.model('Vendor', VendorSchema);
