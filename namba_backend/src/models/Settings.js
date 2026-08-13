const mongoose = require('mongoose');

const SettingsSchema = new mongoose.Schema({
  codEnabled: {
    type: Boolean,
    default: true,
  },
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
  includeRiderPickupDistance: {
    type: Boolean,
    default: true,
  },
  driverBaseRatePerKm: {
    type: Number,
    default: 7.0, // Default ₹7 / km
  },
  driverLongDistanceThresholdKm: {
    type: Number,
    default: 50.0, // Default 50 km threshold
  },
  driverLongDistanceBonusPerKm: {
    type: Number,
    default: 2.0, // Default +₹2 / km above 50 km (Total ₹9 / km)
  },
  driverMinEarningsPerOrder: {
    type: Number,
    default: 10.0, // Default minimum ₹10 per order
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
  vendorAlertSound: {
    type: String,
    enum: ['new_order_alert', 'bell_ring', 'loud_alarm', 'chime_alert'],
    default: 'new_order_alert',
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
