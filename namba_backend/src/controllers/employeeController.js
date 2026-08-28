const EmployeeProfile = require('../models/EmployeeProfile');
const User = require('../models/User');
const Order = require('../models/Order');

const formatJoinDate = (dateObj) => {
  if (!dateObj) return 'N/A';
  const d = new Date(dateObj);
  if (isNaN(d.getTime())) return 'N/A';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const day = d.getDate().toString().padStart(2, '0');
  const month = months[d.getMonth()];
  const year = d.getFullYear();
  return `${day} ${month} ${year}`;
};

// @desc    Get all employees (Admins, System Executives, Drivers) with their master data
// @route   GET /api/v1/admin/employees
exports.getEmployees = async (req, res) => {
  try {
    const users = await User.find({ role: { $in: ['admin', 'superadmin', 'driver'] } })
      .sort({ role: 1, name: 1 })
      .lean();

    const profiles = await EmployeeProfile.find().lean();
    const deliveredOrders = await Order.find({ status: 'Delivered' }).select('driver driverEarnings deliveryCharge').lean();

    let onlineDriversCount = 0;
    let bankVerifiedCount = 0;
    let driversCount = 0;
    let adminsCount = 0;

    const result = users.map((user) => {
      const profile = profiles.find((p) => p.user.toString() === user._id.toString());
      const isDriver = user.role === 'driver';
      if (isDriver) {
        driversCount++;
        if (user.isOnline) onlineDriversCount++;
      } else {
        adminsCount++;
      }

      // Check banking details from profile OR user documents
      let bank = null;
      let isBankAdded = false;

      if (profile && profile.bankDetails && (profile.bankDetails.accountNumber || profile.bankDetails.accountName)) {
        bank = profile.bankDetails;
        isBankAdded = true;
      } else if (user.documents && (user.documents.bankDetails || user.documents.bankStatement)) {
        const userBank = user.documents.bankDetails || user.documents.bankStatement;
        if (userBank.accountNumber || userBank.accountHolderName || userBank.upiId) {
          bank = {
            accountName: userBank.accountHolderName || user.name,
            accountNumber: userBank.accountNumber || 'N/A',
            ifscCode: userBank.ifscCode || 'N/A',
            bankName: userBank.bankName || 'Direct Bank/UPI',
            upiId: userBank.upiId || 'N/A',
          };
          isBankAdded = true;
        }
      }

      if (isBankAdded) bankVerifiedCount++;

      // Driver Trip Calculations
      let totalTrips = 0;
      let totalEarnings = 0;
      if (isDriver) {
        const driverTrips = deliveredOrders.filter(
          (o) => o.driver && o.driver.toString() === user._id.toString()
        );
        totalTrips = driverTrips.length;
        totalEarnings = driverTrips.reduce((acc, curr) => acc + (curr.driverEarnings || curr.deliveryCharge || 0), 0);
      }

      const joinDateRaw = (profile && profile.dateOfJoining) || user.createdAt;
      const formattedJoinDate = formatJoinDate(joinDateRaw);

      return {
        _id: user._id,
        employeeId: `EMP-${user._id.toString().substring(18, 24).toUpperCase()}`,
        name: user.name || 'Staff Member',
        phone: user.phone || 'N/A',
        email: user.email || `${(user.name || 'user').toLowerCase().replace(/\s+/g, '')}@namba.app`,
        role: user.role,
        roleLabel: user.role === 'superadmin' ? 'Super Admin' : (user.role === 'admin' ? 'Operations Admin' : 'Delivery Partner'),
        city: user.city || 'Chennai Hub',
        isOnline: user.isOnline || false,
        isActive: user.isActive !== false,
        vehicleType: user.vehicleType || (isDriver ? 'Bike' : 'N/A'),
        vehicleNumber: user.vehicleNumber || 'N/A',
        licenseNumber: user.licenseNumber || 'N/A',
        approvalStatus: user.driverApprovalStatus || 'approved',
        activeDeviceId: user.activeDeviceId || null,
        isSessionActive: user.isSessionActive === true,
        lastLoginAt: user.lastLoginAt || null,
        joinDate: formattedJoinDate,
        joinDateRaw,
        isBankAdded,
        bankDetails: bank || {
          accountName: user.name,
          accountNumber: 'Not Configured',
          ifscCode: 'N/A',
          bankName: 'Pending Bank Setup',
          upiId: 'N/A',
        },
        employmentStatus: (profile && profile.employmentStatus) || (user.isActive === false ? 'Relieved' : 'Active'),
        relievingDetails: (profile && profile.relievingDetails) ? {
          ...profile.relievingDetails,
          formattedRelievingDate: formatJoinDate(profile.relievingDetails.relievingDate || profile.relievingDetails.relievedAt),
        } : null,
        profile: profile ? {
          dateOfBirth: profile.dateOfBirth,
          dateOfJoining: profile.dateOfJoining,
          bloodGroup: profile.bloodGroup || 'N/A',
          emergencyContact: profile.emergencyContact || { name: 'Not Added', phone: 'N/A', relation: 'N/A' },
          baseSalary: profile.baseSalary || 0,
          employmentStatus: profile.employmentStatus || 'Active',
          relievingDetails: profile.relievingDetails || null,
        } : {
          dateOfBirth: null,
          dateOfJoining: joinDateRaw,
          bloodGroup: 'N/A',
          emergencyContact: { name: 'Not Added', phone: 'N/A', relation: 'N/A' },
          baseSalary: isDriver ? 0 : 25000,
          employmentStatus: user.isActive === false ? 'Relieved' : 'Active',
          relievingDetails: null,
        },
        stats: {
          totalTrips,
          totalEarnings,
          rating: 4.8,
          onDutyStatus: user.isOnline ? 'ONLINE' : 'OFFLINE',
        },
      };
    });

    res.status(200).json({
      success: true,
      count: result.length,
      summary: {
        totalStaffCount: result.length,
        driversCount,
        adminsCount,
        onlineDriversCount,
        bankVerifiedCount,
      },
      data: result,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get single employee profile
// @route   GET /api/v1/admin/employees/:id
exports.getEmployeeProfile = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).lean();
    if (!user) {
      return res.status(404).json({ success: false, error: 'Employee not found' });
    }

    const profile = await EmployeeProfile.findOne({ user: req.params.id }).lean();
    res.status(200).json({
      success: true,
      data: {
        user,
        profile: profile || null,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Create or Update Employee Master Data
// @route   PUT /api/v1/admin/employees/:id
exports.upsertEmployeeProfile = async (req, res) => {
  try {
    const { dateOfBirth, dateOfJoining, bloodGroup, emergencyContact, bankDetails, baseSalary } = req.body;

    let profile = await EmployeeProfile.findOne({ user: req.params.id });

    if (profile) {
      profile = await EmployeeProfile.findOneAndUpdate(
        { user: req.params.id },
        { dateOfBirth, dateOfJoining, bloodGroup, emergencyContact, bankDetails, baseSalary },
        { new: true, runValidators: true }
      );
    } else {
      profile = await EmployeeProfile.create({
        user: req.params.id,
        dateOfBirth,
        dateOfJoining: dateOfJoining || Date.now(),
        bloodGroup,
        emergencyContact,
        bankDetails,
        baseSalary,
      });
    }

    res.status(200).json({ success: true, message: 'Employee profile updated successfully', data: profile });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Relieve / Offboard an employee
// @route   PUT /api/v1/admin/employees/:id/relieve
exports.relieveEmployee = async (req, res) => {
  try {
    const { relievingDate, reason, remarks, duesSettled } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, error: 'Employee not found' });

    user.isActive = false;
    user.isOnline = false;
    await user.save();

    const relData = {
      employmentStatus: 'Relieved',
      relievingDetails: {
        relievingDate: relievingDate ? new Date(relievingDate) : new Date(),
        reason: reason || 'Voluntary Resignation',
        remarks: remarks || '',
        duesSettled: duesSettled !== false,
        relievedAt: new Date(),
      },
    };

    let profile = await EmployeeProfile.findOne({ user: req.params.id });
    if (profile) {
      profile = await EmployeeProfile.findOneAndUpdate(
        { user: req.params.id },
        relData,
        { new: true }
      );
    } else {
      profile = await EmployeeProfile.create({
        user: req.params.id,
        ...relData,
      });
    }

    res.status(200).json({
      success: true,
      message: 'Employee has been successfully relieved and offboarded',
      data: { user, profile },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reinstate / Re-hire an employee
// @route   PUT /api/v1/admin/employees/:id/reinstate
exports.reinstateEmployee = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, error: 'Employee not found' });

    user.isActive = true;
    await user.save();

    let profile = await EmployeeProfile.findOneAndUpdate(
      { user: req.params.id },
      { employmentStatus: 'Active' },
      { new: true }
    );

    res.status(200).json({
      success: true,
      message: 'Employee reinstated and activated successfully',
      data: { user, profile },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
