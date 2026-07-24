const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const UserSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please add a name'],
    trim: true,
  },
  phone: {
    type: String,
    required: [true, 'Please add a phone number'],
    unique: true,
    match: [/^\d{10}$/, 'Please add a valid 10-digit phone number'],
  },
  email: {
    type: String,
    match: [
      /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/,
      'Please add a valid email',
    ],
  },
  city: {
    type: String,
    trim: true,
  },
  role: {
    type: String,
    enum: ['customer', 'vendor', 'driver', 'admin', 'superadmin'],
    default: 'customer',
  },
  // Driver Approval Workflow
  driverApprovalStatus: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending',
  },
  driverRejectionReason: String,
  // Driver Vehicle Details
  vehicleType: {
    type: String,
    enum: ['bike', 'scooter', 'bicycle', 'car', 'auto'],
  },
  vehicleNumber: {
    type: String,
    trim: true,
  },
  licenseNumber: {
    type: String,
    trim: true,
  },
  password: {
    type: String,
    minlength: 6,
    select: false,
  },
  // Soft delete flag instead of permanent deletion for audit trails
  isActive: {
    type: Boolean,
    default: true,
  },
  permissions: {
    type: Map,
    of: Boolean,
    default: {
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
    },
  },
  resetPasswordOtp: String,

  resetPasswordExpire: Date,
  
  // Driver specific fields
  activeDeviceId: {
    type: String,
    default: null,
  },
  isOnline: {
    type: Boolean,
    default: false,
  },
  onlineSessionStart: {
    type: Date,
  },
  lastOnlineAt: {
    type: Date,
  },
  onlineSecondsToday: {
    type: Number,
    default: 0,
  },
  lastLocation: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number],
      default: [0, 0],
    },
  },
  // Document Verification Hub
  documents: {
    aadhar: {
      front: String,
      back: String,
      status: { type: String, enum: ['unloaded', 'pending', 'verified', 'rejected'], default: 'unloaded' },
      rejectionReason: String,
    },
    license: {
      front: String,
      back: String,
      status: { type: String, enum: ['unloaded', 'pending', 'verified', 'rejected'], default: 'unloaded' },
      rejectionReason: String,
    },
    rc: {
      front: String,
      back: String,
      status: { type: String, enum: ['unloaded', 'pending', 'verified', 'rejected'], default: 'unloaded' },
      rejectionReason: String,
    },
    pan: {
      front: String,
      back: String,
      status: { type: String, enum: ['unloaded', 'pending', 'verified', 'rejected'], default: 'unloaded' },
      rejectionReason: String,
    },
    bankStatement: {
      front: String,
      back: String,
      status: { type: String, enum: ['unloaded', 'pending', 'verified', 'rejected'], default: 'unloaded' },
      rejectionReason: String,
    },
    selfie: {
      front: String,
      status: { type: String, enum: ['unloaded', 'pending', 'verified', 'rejected'], default: 'unloaded' },
      rejectionReason: String,
    },
  },
  // Performance Metrics
  declinedCount: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: true,
});

// Create index for GeoSpatial queries
UserSchema.index({ lastLocation: '2dsphere' });

// Hash password using bcrypt before saving
UserSchema.pre('save', async function () {
  if (!this.isModified('password') || !this.password) {
    return;
  }
  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Compare user entered password to hashed password in database
UserSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('User', UserSchema);
