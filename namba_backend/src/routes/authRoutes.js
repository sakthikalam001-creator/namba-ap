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
  logout,
  forceLogoutDriver,
} = require('../controllers/authController');

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

module.exports = router;
