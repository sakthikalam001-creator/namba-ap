const express = require('express');
const router = express.Router();
const {
  getPendingVendors,
  getAllVendors,
  approveVendor,
  rejectVendor,
  updateVendorAccess,
  getVendorStatus,
  getVendorStatusByPhone,
  resetDatabase,
  resetVendors,
  resetCustomers,
  resetDelivery,
  resetOrders,
  resetAdmins,
  getDispatchOrders,
  getAvailableDrivers,
  assignDriverToOrder,
  getSettings,
  updateSettings,
  getPendingDrivers,
  getAllDrivers,
  approveDriver,
  rejectDriver,
  getPendingDocumentVerifications,
  verifyDriverDocument,
  getAllAdmins,
  provisionAdmin,
  resetAdminPassword,
  updateAdminProfile,
  updateAdminPermissions,
  getCustomerOrders,
  getCustomerOrderHistory,
  getServiceZones,
  createServiceZone,
  updateServiceZone,
  deleteServiceZone,
  updateAdminRole,
  unassignDriverFromOrder,
  cancelOrder,
  getFinancialAnalytics,
  getReportAnalytics,
  getPerformanceAnalytics,
  getFailedPaymentOrders,
  payDriverSalary,
  getAllCustomers,
} = require('../controllers/adminController');
const { getLiveHeatmapData } = require('../controllers/heatmapController');
const { protect, authorize } = require('../middlewares/auth');

// Public settings for Customer/Vendor apps (e.g. delivery radius, service center coordinates)
router.get('/settings/public', getSettings);
router.get('/vendors/:id/status', getVendorStatus);
router.get('/vendors/status-by-phone/:phone', getVendorStatusByPhone);

router.use(protect);

// Super Admin routes
router.get('/vendors/pending', authorize('admin', 'superadmin'), getPendingVendors);
router.get('/vendors', authorize('admin', 'superadmin'), getAllVendors);
router.put('/vendors/:id/approve', authorize('admin', 'superadmin'), approveVendor);
router.put('/vendors/:id/reject', authorize('admin', 'superadmin'), rejectVendor);
router.put('/vendors/:id/access', authorize('admin', 'superadmin'), updateVendorAccess);

// Reset routes (Danger Zone)
router.delete('/reset-database', authorize('superadmin'), resetDatabase);
router.delete('/reset/vendors', authorize('superadmin'), resetVendors);
router.delete('/reset/customers', authorize('superadmin'), resetCustomers);
router.delete('/reset/delivery', authorize('superadmin'), resetDelivery);
router.delete('/reset/orders', authorize('superadmin'), resetOrders);
router.delete('/reset/admins', authorize('superadmin'), resetAdmins);

// Dispatch routes
router.get('/dispatch/orders', getDispatchOrders);
router.get('/dispatch/drivers', getAvailableDrivers);
router.put('/dispatch/assign', assignDriverToOrder);
router.put('/dispatch/unassign/:id', unassignDriverFromOrder);
router.get('/orders/customer', getCustomerOrders);
router.get('/orders/customer/history', getCustomerOrderHistory);
router.get('/orders/failed-payments', getFailedPaymentOrders);
router.put('/orders/:id/cancel', cancelOrder);

// Driver Management routes
router.get('/drivers/pending', getPendingDrivers);
router.get('/drivers', getAllDrivers);
router.put('/drivers/:id/approve', approveDriver);
router.put('/drivers/:id/reject', rejectDriver);
router.put('/drivers/:id/pay', payDriverSalary);

// Document Verification Hub
router.get('/documents/pending', getPendingDocumentVerifications);
router.put('/documents/:driverId/verify', verifyDriverDocument);

// Platform Settings
router.get('/settings', getSettings);
router.put('/settings', updateSettings);

// Admin Management
router.put('/profile/:id', updateAdminProfile); // Moved up
router.put('/admins/:id/permissions', updateAdminPermissions);
router.put('/admins/:id/role', updateAdminRole);
router.get('/admins', getAllAdmins);
router.post('/admins', provisionAdmin);
router.put('/admins/:id/reset-password', resetAdminPassword);

// Customer Management
router.get('/customers', authorize('admin', 'superadmin'), getAllCustomers);

// Geospatial Heatmap
router.get('/heatmap', getLiveHeatmapData);

// Financial Intelligence
router.get('/financial-analytics', getFinancialAnalytics);
router.get('/financial-analytics/reports', getReportAnalytics);
router.get('/performance-analytics', getPerformanceAnalytics);

// Service Zone Management
router.get('/zones', getServiceZones);
router.post('/zones', createServiceZone);
router.put('/zones/:id', updateServiceZone);
router.delete('/zones/:id', deleteServiceZone);

module.exports = router;
