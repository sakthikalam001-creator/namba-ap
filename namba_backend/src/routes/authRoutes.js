const express = require('express');
const { 
  register, 
  login, 
  registerVendor,
  registerDriver,
  forgotPassword, 
  verifyOtp, 
  resetPassword,
  setDriverStatus,
  uploadDocumentSide,
  getDriverDocuments,
  saveDriverBankDetails,
  adminLogin,
  customerOtpLogin,
  sendSecurityPin,
  verifySecurityPin,
  updateSavedAddresses,
  getSavedAddresses,
  registerUserPushToken,
  logout,
  forceLogoutDriver,
} = require('../controllers/authController');
const { protect } = require('../middlewares/auth');

const {
  getWhatsAppStatus,
  requestWhatsAppPairing,
  disconnectWhatsApp,
  testSendWhatsApp,
} = require('../controllers/whatsappController');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/logout', logout);
router.post('/admin-login', adminLogin);
router.post('/register-vendor', registerVendor);
router.post('/register-driver', registerDriver);
router.post('/forgot-password', forgotPassword);
router.post('/verify-otp', verifyOtp);
router.post('/reset-password', resetPassword);
router.put('/driver-status', setDriverStatus);
router.post('/upload-document', uploadDocumentSide);
router.post('/save-bank-details', saveDriverBankDetails);
router.get('/documents/:driverId', getDriverDocuments);
router.post('/customer-login', customerOtpLogin);
router.post('/send-security-pin', sendSecurityPin);
router.post('/verify-security-pin', verifySecurityPin);
router.get('/saved-addresses', protect, getSavedAddresses);
router.put('/saved-addresses', protect, updateSavedAddresses);
router.post('/push-token', registerUserPushToken);
router.put('/push-token', registerUserPushToken);

// WhatsApp Gateway Management API
router.get('/whatsapp/status', getWhatsAppStatus);
router.post('/whatsapp/pair', requestWhatsAppPairing);
router.post('/whatsapp/logout', disconnectWhatsApp);
router.post('/whatsapp/test-send', testSendWhatsApp);

module.exports = router;

