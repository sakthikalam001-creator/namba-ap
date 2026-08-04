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
  adminLogin,
  customerOtpLogin,
  sendSecurityPin,
  verifySecurityPin
} = require('../controllers/authController');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/admin-login', adminLogin);
router.post('/register-vendor', registerVendor);
router.post('/register-driver', registerDriver);
router.post('/forgot-password', forgotPassword);
router.post('/verify-otp', verifyOtp);
router.post('/reset-password', resetPassword);
router.put('/driver-status', setDriverStatus);
router.post('/upload-document', uploadDocumentSide);
router.get('/documents/:driverId', getDriverDocuments);
router.post('/customer-login', customerOtpLogin);
router.post('/send-security-pin', sendSecurityPin);
router.post('/verify-security-pin', verifySecurityPin);

module.exports = router;
