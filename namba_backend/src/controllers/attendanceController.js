const Attendance = require('../models/Attendance');
const User = require('../models/User');
const DriverDutySession = require('../models/DriverDutySession');

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
    
    let attendance = await Attendance.findOne({ user: req.user.id, date: today });
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

// @desc    Get all attendance for date with full staff reconciliation (Admin View)
// @route   GET /api/v1/attendance/admin
exports.getTodayAttendance = async (req, res) => {
  try {
    const date = req.query.date || new Date().toISOString().split('T')[0];
    
    // 1. Get all active staff & drivers
    const users = await User.find({
      role: { $in: ['admin', 'superadmin', 'driver'] },
      isActive: { $ne: false },
    }).select('name role phone email city isOnline vehicleType lastLoginAt lastOnlineAt onlineSessionStart createdAt').sort({ role: 1, name: 1 }).lean();

    // 2. Get recorded attendance logs for this date
    const recordedLogs = await Attendance.find({ date }).populate('user', 'name role phone email isOnline').lean();

    // 3. Get driver duty sessions for this date
    const dutySessions = await DriverDutySession.find({ date }).sort({ onlineTime: 1 }).lean();

    let presentCount = 0;
    let absentCount = 0;
    let onLeaveCount = 0;
    let onlineDriversCount = 0;

    const list = users.map((user) => {
      const isDriver = user.role === 'driver';
      if (isDriver && user.isOnline) onlineDriversCount++;

      const log = recordedLogs.find((r) => r.user && r.user._id.toString() === user._id.toString());

      if (log) {
        if (log.status === 'Present' || log.status === 'Half-Day') presentCount++;
        else if (log.status === 'Leave') onLeaveCount++;
        else absentCount++;

        return {
          _id: log._id,
          userId: user._id,
          employeeId: `EMP-${user._id.toString().substring(18, 24).toUpperCase()}`,
          name: user.name || 'Staff Member',
          role: user.role,
          roleLabel: user.role === 'superadmin' ? 'Super Admin' : (user.role === 'admin' ? 'Operations Admin' : 'Delivery Partner'),
          phone: user.phone || 'N/A',
          city: user.city || 'Chennai Hub',
          isOnline: user.isOnline || false,
          date: log.date,
          checkInTime: log.checkInTime,
          checkOutTime: log.checkOutTime || null,
          status: log.status || 'Present',
          isManualPunch: false,
        };
      }

      // If no explicit document exists yet today: synthesize based on live duty status
      if (isDriver) {
        const userSessions = dutySessions.filter(s => s.driver && s.driver.toString() === user._id.toString());
        
        if (userSessions.length > 0) {
          presentCount++;
          const firstSession = userSessions[0];
          const lastSession = userSessions[userSessions.length - 1];
          const checkInTime = firstSession.onlineTime;
          const checkOutTime = user.isOnline ? null : (lastSession.offlineTime || user.lastOnlineAt || lastSession.updatedAt);

          return {
            _id: `duty-${user._id}`,
            userId: user._id,
            employeeId: `EMP-${user._id.toString().substring(18, 24).toUpperCase()}`,
            name: user.name || 'Delivery Partner',
            role: user.role,
            roleLabel: 'Delivery Partner',
            phone: user.phone || 'N/A',
            city: user.city || 'Chennai Hub',
            isOnline: user.isOnline || false,
            date,
            checkInTime: checkInTime ? new Date(checkInTime).toISOString() : null,
            checkOutTime: checkOutTime ? new Date(checkOutTime).toISOString() : null,
            status: 'Present',
            isManualPunch: false,
          };
        } else if (user.isOnline === true) {
          presentCount++;
          const checkInTime = user.onlineSessionStart || user.lastLoginAt || new Date();

          return {
            _id: `duty-${user._id}`,
            userId: user._id,
            employeeId: `EMP-${user._id.toString().substring(18, 24).toUpperCase()}`,
            name: user.name || 'Delivery Partner',
            role: user.role,
            roleLabel: 'Delivery Partner',
            phone: user.phone || 'N/A',
            city: user.city || 'Chennai Hub',
            isOnline: true,
            date,
            checkInTime: new Date(checkInTime).toISOString(),
            checkOutTime: null,
            status: 'Present',
            isManualPunch: false,
          };
        } else {
          absentCount++;
          return {
            _id: `synthetic-${user._id}`,
            userId: user._id,
            employeeId: `EMP-${user._id.toString().substring(18, 24).toUpperCase()}`,
            name: user.name || 'Delivery Partner',
            role: user.role,
            roleLabel: 'Delivery Partner',
            phone: user.phone || 'N/A',
            city: user.city || 'Chennai Hub',
            isOnline: false,
            date,
            checkInTime: null,
            checkOutTime: null,
            status: 'Absent',
            isManualPunch: false,
          };
        }
      }

      // For Operations Admins & Super Admins (Default Morning Shift 09:00 AM IST)
      presentCount++;
      let checkInTime = new Date(`${date}T03:30:00.000Z`); // 09:00 AM IST
      if (user.lastLoginAt) {
        const loginIso = new Date(user.lastLoginAt).toISOString();
        if (loginIso.startsWith(date)) {
          checkInTime = new Date(user.lastLoginAt);
        }
      }

      return {
        _id: `synthetic-${user._id}`,
        userId: user._id,
        employeeId: `EMP-${user._id.toString().substring(18, 24).toUpperCase()}`,
        name: user.name || 'Staff Member',
        role: user.role,
        roleLabel: user.role === 'superadmin' ? 'Super Admin' : 'Operations Admin',
        phone: user.phone || 'N/A',
        city: user.city || 'Chennai Hub',
        isOnline: user.isOnline || true,
        date,
        checkInTime: checkInTime.toISOString(),
        checkOutTime: null,
        status: 'Present',
        isManualPunch: false,
      };
    });

    res.status(200).json({
      success: true,
      count: list.length,
      selectedDate: date,
      summary: {
        totalStaff: users.length,
        presentCount,
        absentCount,
        onLeaveCount,
        onlineDriversCount,
        attendanceRate: users.length > 0 ? Math.round((presentCount / users.length) * 100) : 100,
      },
      data: list,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Admin manually marks / punches attendance for employee
// @route   POST /api/v1/attendance/admin/mark
exports.markAdminAttendance = async (req, res) => {
  try {
    const { userId, date, status, checkInTime, checkOutTime, remarks } = req.body;
    const targetDate = date || new Date().toISOString().split('T')[0];

    let attendance = await Attendance.findOne({ user: userId, date: targetDate });

    if (attendance) {
      attendance.status = status || attendance.status;
      if (checkInTime) attendance.checkInTime = new Date(checkInTime);
      if (checkOutTime) attendance.checkOutTime = new Date(checkOutTime);
      await attendance.save();
    } else {
      attendance = await Attendance.create({
        user: userId,
        date: targetDate,
        checkInTime: checkInTime ? new Date(checkInTime) : new Date(),
        checkOutTime: checkOutTime ? new Date(checkOutTime) : undefined,
        status: status || 'Present',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Attendance successfully updated',
      data: attendance,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
