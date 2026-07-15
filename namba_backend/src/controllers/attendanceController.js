const Attendance = require('../models/Attendance');

// @desc    Check-In an employee (Driver/Admin)
// @route   POST /api/v1/attendance/check-in
exports.checkIn = async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    
    // Check if already checked in today
    const existing = await Attendance.findOne({ user: req.user.id, date: today });
    if (existing) {
      return res.status(400).json({ success: false, error: 'Already checked in today' });
    }

    const { coordinates } = req.body; // Expecting [lng, lat]
    
    const attendance = await Attendance.create({
      user: req.user.id,
      date: today,
      checkInTime: new Date(),
      status: 'Present',
      workLocation: coordinates ? { type: 'Point', coordinates } : undefined
    });

    res.status(201).json({ success: true, data: attendance });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Check-Out an employee
// @route   PUT /api/v1/attendance/check-out
exports.checkOut = async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];
    
    const attendance = await Attendance.findOne({ user: req.user.id, date: today });
    if (!attendance) {
      return res.status(404).json({ success: false, error: 'No check-in record found for today' });
    }
    
    if (attendance.checkOutTime) {
      return res.status(400).json({ success: false, error: 'Already checked out today' });
    }

    attendance.checkOutTime = new Date();
    await attendance.save();

    res.status(200).json({ success: true, data: attendance });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get all attendance for today (Admin View)
// @route   GET /api/v1/admin/attendance
exports.getTodayAttendance = async (req, res) => {
  try {
    // Optionally accept date from query, default to today
    const date = req.query.date || new Date().toISOString().split('T')[0];
    
    const logs = await Attendance.find({ date }).populate('user', 'name role phone').sort({ checkInTime: -1 });
    
    res.status(200).json({ success: true, count: logs.length, data: logs });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
