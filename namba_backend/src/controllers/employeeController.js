const EmployeeProfile = require('../models/EmployeeProfile');
const User = require('../models/User');

// @desc    Get all employees (Admins, System Executives, Drivers) with their master data
// @route   GET /api/v1/admin/employees
exports.getEmployees = async (req, res) => {
  try {
    const users = await User.find({ role: { $in: ['admin', 'superadmin', 'driver'] } }).sort({ role: 1, name: 1 });
    const profiles = await EmployeeProfile.find();

    const result = users.map(user => {
      const profile = profiles.find(p => p.user.toString() === user._id.toString());
      return {
        _id: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        role: user.role,
        profile: profile || null,
      };
    });

    res.status(200).json({ success: true, count: result.length, data: result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get single employee profile
// @route   GET /api/v1/admin/employees/:id
exports.getEmployeeProfile = async (req, res) => {
  try {
    const profile = await EmployeeProfile.findOne({ user: req.params.id }).populate('user', 'name email phone role');
    if (!profile) {
      return res.status(404).json({ success: false, error: 'Employee profile not found' });
    }
    res.status(200).json({ success: true, data: profile });
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
      // Update
      profile = await EmployeeProfile.findOneAndUpdate(
        { user: req.params.id },
        { dateOfBirth, dateOfJoining, bloodGroup, emergencyContact, bankDetails, baseSalary },
        { new: true, runValidators: true }
      );
    } else {
      // Create
      profile = await EmployeeProfile.create({
        user: req.params.id,
        dateOfBirth,
        dateOfJoining,
        bloodGroup,
        emergencyContact,
        bankDetails,
        baseSalary
      });
    }

    res.status(200).json({ success: true, data: profile });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
