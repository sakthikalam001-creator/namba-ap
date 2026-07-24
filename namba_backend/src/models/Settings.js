const mongoose = require('mongoose');

const SettingsSchema = new mongoose.Schema({
  autoAssign: {
    type: Boolean,
    default: true,
  },
  maxDispatchRadiusKm: {
    type: Number,
    default: 10,
  },
  maxServiceRadiusKm: {
    type: Number,
    default: 20,
  },
  serviceCenterLat: {
    type: Number,
    default: 11.3410, // Default Erode
  },
  serviceCenterLng: {
    type: Number,
    default: 77.7172, // Default Erode
  },
  platformCommissionPct: {
    type: Number,
    default: 5.0,
  },
  vendorCommissionEnabled: {
    type: Boolean,
    default: true,
  },
  customerPlatformFeeEnabled: {
    type: Boolean,
    default: true,
  },
  customerPlatformFeeAmount: {
    type: Number,
    default: 5.0,
  },
  maintenanceMode: {
    type: Boolean,
    default: false,
  },
  partnerInsuranceEnabled: {
    type: Boolean,
    default: true,
  },
  partnerFlexibilityEnabled: {
    type: Boolean,
    default: true,
  },
  partnerIncentivesEnabled: {
    type: Boolean,
    default: true,
  },
  partnerWelfareEnabled: {
    type: Boolean,
    default: true,
  },
  adminPermissions: {
    overview: { type: Boolean, default: true },
    vendors: { type: Boolean, default: true },
    admins: { type: Boolean, default: false },
    drivers: { type: Boolean, default: true },
    verification: { type: Boolean, default: false },
    dispatch: { type: Boolean, default: true },
    broadcasts: { type: Boolean, default: false },
    support: { type: Boolean, default: false },
    intelligence: { type: Boolean, default: false },
    security: { type: Boolean, default: false },
    reports: { type: Boolean, default: false },
    settings: { type: Boolean, default: false },
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Settings', SettingsSchema);
