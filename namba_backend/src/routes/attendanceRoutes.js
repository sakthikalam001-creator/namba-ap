const express = require('express');
const router = express.Router();
const {
  checkIn,
  checkOut,
  getTodayAttendance,
  markAdminAttendance,
} = require('../controllers/attendanceController');
const { protect, authorize } = require('../middlewares/auth');

router.use(protect);

// Mobile App Routes (For drivers/staff)
router.post('/check-in', checkIn);
router.put('/check-out', checkOut);

// Admin Dashboard Routes
router.get('/admin', authorize('admin', 'superadmin'), getTodayAttendance);
router.post('/admin/mark', authorize('admin', 'superadmin'), markAdminAttendance);

module.exports = router;
