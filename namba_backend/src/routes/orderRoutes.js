const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { placeOrder, updateOrderStatus, getOrder, getVendorOrders, getDriverOrders, getDriverHistory, declineOrder, getCustomerOrders, uploadVendorPaymentDetails, markVendorPaidByAdmin } = require('../controllers/orderController');
const upload = require('../utils/upload');
const { protect, authorize } = require('../middlewares/auth');

// Ensure vendor_qrs directory exists
const vendorQrDir = path.join(__dirname, '../../public/vendor_qrs');
if (!fs.existsSync(vendorQrDir)) {
  fs.mkdirSync(vendorQrDir, { recursive: true });
}

const vendorQrStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, vendorQrDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    // Ensure we have an extension, fallback to .png if missing but mimetype is image/png
    let ext = path.extname(file.originalname).toLowerCase();
    if (!ext) {
      if (file.mimetype === 'image/jpeg') ext = '.jpg';
      else if (file.mimetype === 'image/png') ext = '.png';
      else if (file.mimetype === 'image/webp') ext = '.webp';
    }
    cb(null, 'vendor_qr-' + uniqueSuffix + ext);
  }
});

const uploadVendorQr = multer({
  storage: vendorQrStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // Consistent 10MB limit
  fileFilter: (req, file, cb) => {
    const filetypes = /jpeg|jpg|png|webp/;
    const mimetype = filetypes.test(file.mimetype);
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());

    // Robust check: allow if mimetype is valid, OR if extension is valid
    if (mimetype || extname) {
      return cb(null, true);
    }
    cb(new Error('Only .png, .jpg, .jpeg and .webp format allowed!'));
  }
});

const router = express.Router();

// Public routes for checkout testing
router.route('/').post(placeOrder);
router.route('/customer/:customerId').get(getCustomerOrders);
router.route('/:id/status').put(updateOrderStatus); // Moved here to allow public payment updates

router.route('/upload').post(upload.single('photo'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, error: 'No file uploaded' });
  }
  const fileUrl = `/public/uploads/${req.file.filename}`;
  res.status(200).json({ success: true, url: fileUrl });
});

// Protected routes
router.use(protect);
router.route('/vendor/:vendorId').get(getVendorOrders);

router.route('/driver/:driverId').get(getDriverOrders);
router.route('/driver/:driverId/history').get(getDriverHistory);
router.route('/:id').get(getOrder);
router.route('/:id/decline').put(declineOrder);
router.route('/:id/bill').put(upload.single('bill'), require('../controllers/orderController').uploadOrderBill);
router.route('/:id/vendor-payment-details').put(uploadVendorQr.single('qr'), uploadVendorPaymentDetails);
router.route('/:id/admin-pay-vendor').put(markVendorPaidByAdmin);

module.exports = router;
