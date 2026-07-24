const User = require('../models/User');
const Vendor = require('../models/Vendor');
const jwt = require('jsonwebtoken');

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE,
  });
};

// @desc    Register user
// @route   POST /api/v1/auth/register
// @access  Public
exports.register = async (req, res) => {
  try {
    const { name, phone, email, password, role } = req.body;

    // Check for existing user
    const existingUser = await User.findOne({ phone });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'Phone number already registered' });
    }

    // Create user
    const user = await User.create({
      name,
      phone,
      email,
      password,
      role: role || 'customer',
    });

    const token = generateToken(user._id);

    if (user.role === 'customer') {
      const io = req.app.get('socketio');
      if (io) {
        io.to('admin').emit('new_customer_registered', {
          message: `New customer registered: ${user.name}`,
          customerId: user._id,
        });
      }
    }

    res.status(201).json({
      success: true,
      token,
      user: {
        _id: user._id,
        name: user.name,
        role: user.role,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Register as Vendor (creates User + Vendor profile, status=pending)
// @route   POST /api/v1/auth/register-vendor
// @access  Public
exports.registerVendor = async (req, res) => {
  try {
    const { 
      ownerName, 
      phone, 
      email, 
      password, 
      storeName, 
      storeAddress, 
      category,
      gstNumber,
      panNumber,
      businessEmail,
      lat,
      lng
    } = req.body;

    if (!ownerName || !phone || !password || !storeName || !category) {
      return res.status(400).json({ success: false, error: 'Please provide all required fields' });
    }

    // Check if phone already registered
    const existingUser = await User.findOne({ phone });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'Phone number already registered' });
    }

    // Create the user account with vendor role
    const user = await User.create({
      name: ownerName,
      phone,
      email,
      password,
      role: 'vendor',
    });

    const vendorData = {
      user: user._id,
      storeName,
      ownerName,
      phone,
      address: storeAddress || '',
      category,
      gstNumber,
      panNumber,
      businessEmail,
      approvalStatus: 'pending',
    };

    if (lat !== undefined && lng !== undefined) {
      vendorData.location = {
        type: 'Point',
        coordinates: [parseFloat(lng), parseFloat(lat)]
      };
    }

    // Create the vendor profile (status: 'pending' by default)
    const vendor = await Vendor.create(vendorData);

    const token = generateToken(user._id);

    console.log(`[Vendor Registration] 📋 "${storeName}" submitted for approval`);

    res.status(201).json({
      success: true,
      token,
      user: {
        _id: user._id,
        name: user.name,
        role: user.role,
      },
      vendor: {
        _id: vendor._id,
        storeName: vendor.storeName,
        approvalStatus: vendor.approvalStatus,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};



// @desc    Register as Delivery Driver (creates User with role=driver, status=pending)
// @route   POST /api/v1/auth/register-driver
// @access  Public
exports.registerDriver = async (req, res) => {
  try {
    const { name, phone, password, vehicleType, vehicleNumber, licenseNumber } = req.body;

    if (!name || !phone || !password || !vehicleType || !vehicleNumber || !licenseNumber) {
      return res.status(400).json({ success: false, error: 'Please provide all required fields: name, phone, password, vehicleType, vehicleNumber, licenseNumber' });
    }

    // Check if phone already registered
    const existingUser = await User.findOne({ phone });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'Phone number already registered' });
    }

    // Create the driver user account (approval pending by default)
    const user = await User.create({
      name,
      phone,
      password,
      role: 'driver',
      driverApprovalStatus: 'pending',
      vehicleType,
      vehicleNumber,
      licenseNumber,
    });

    const token = generateToken(user._id);

    console.log(`[Driver Registration] 🚴 "${name}" submitted for approval | Vehicle: ${vehicleType} - ${vehicleNumber}`);

    const io = req.app.get('socketio');
    if (io) {
      io.to('admin').emit('new_driver_registered', {
        message: `New driver registered: ${name}`,
        driverId: user._id,
      });
    }

    res.status(201).json({
      success: true,
      token,
      user: {
        _id: user._id,
        name: user.name,
        role: user.role,
        driverApprovalStatus: user.driverApprovalStatus,
        isOnline: user.isOnline,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Login user
// @route   POST /api/v1/auth/login
// @access  Public
exports.login = async (req, res) => {
    try {
      const { phone, password, deviceId } = req.body;

      if (!phone || !password) {
        return res.status(400).json({ success: false, error: 'Please provide phone and password' });
      }

      // Check for user (include password explicitly since select is false in schema)
      const user = await User.findOne({ phone }).select('+password');

      if (!user) {
        return res.status(401).json({ success: false, error: 'Invalid credentials' });
      }

      // Check if password matches
      const isMatch = await user.matchPassword(password);

      if (!isMatch) {
        return res.status(401).json({ success: false, error: 'Invalid credentials' });
      }

      const io = req.app.get('socketio');

      // Single Device Lock for Drivers
      if (user.role === 'driver' && deviceId) {
        if (io && user.activeDeviceId && user.activeDeviceId !== deviceId) {
          // Force disconnect/logout previous device session
          io.to(`driver_${user._id}`).emit('force_device_logout', {
            message: 'Your account was logged in on another device.'
          });
        }
        user.activeDeviceId = deviceId;
        await user.save();
      }

      const token = generateToken(user._id);

    // If vendor, attach vendor profile
    let vendorData = null;
    if (user.role === 'vendor') {
      vendorData = await Vendor.findOne({ user: user._id });
    }

    res.status(200).json({
      success: true,
      token,
      user: {
        _id: user._id,
        name: user.name,
        role: user.role,
        driverApprovalStatus: user.driverApprovalStatus,
        isOnline: user.isOnline,
      },
      vendor: vendorData,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Forgot password - Send OTP
// @route   POST /api/v1/auth/forgot-password
// @access  Public
exports.forgotPassword = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ success: false, error: 'Please provide a phone number' });
    }

    const user = await User.findOne({ phone });

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found with this phone number' });
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Set OTP and expiry (10 minutes)
    user.resetPasswordOtp = otp;
    user.resetPasswordExpire = Date.now() + 10 * 60 * 1000;

    await user.save();

    console.log(`[Forgot Password] 🔑 OTP for ${phone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: 'OTP sent successfully',
      otp_simulated: otp // In production, this would be sent via SMS and removed from response
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Verify OTP
// @route   POST /api/v1/auth/verify-otp
// @access  Public
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ success: false, error: 'Please provide phone and OTP' });
    }

    const user = await User.findOne({ 
      phone,
      resetPasswordOtp: otp,
      resetPasswordExpire: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({ success: false, error: 'Invalid or expired OTP' });
    }

    res.status(200).json({ success: true, message: 'OTP verified' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Reset password
// @route   POST /api/v1/auth/reset-password
// @access  Public
exports.resetPassword = async (req, res) => {
  try {
    const { phone, otp, newPassword } = req.body;

    if (!phone || !otp || !newPassword) {
      return res.status(400).json({ success: false, error: 'Please provide all fields' });
    }

    const user = await User.findOne({ 
      phone,
      resetPasswordOtp: otp,
      resetPasswordExpire: { $gt: Date.now() }
    }).select('+password');

    if (!user) {
      return res.status(400).json({ success: false, error: 'Invalid or expired OTP' });
    }

    // Set new password
    user.password = newPassword;
    user.resetPasswordOtp = undefined;
    user.resetPasswordExpire = undefined;

    await user.save();

    res.status(200).json({ success: true, message: 'Password reset successful' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Update driver online status
// @route   PUT /api/v1/auth/driver-status
// @access  Public
exports.setDriverStatus = async (req, res) => {
    try {
      const { driverId, isOnline, deviceId } = req.body;
      console.log('[setDriverStatus] Received request body:', req.body);
      if (!driverId) {
        return res.status(400).json({ success: false, error: 'driverId is required' });
      }
      
      const existingDriver = await User.findById(driverId);
      if (!existingDriver) {
        console.log(`[setDriverStatus] ❌ Driver not found in DB for ID: ${driverId}`);
        return res.status(404).json({ success: false, error: `Driver not found in DB for ID: ${driverId}` });
      }

      const io = req.app.get('socketio');

      // Enforce device lock on status update
      if (deviceId && existingDriver.activeDeviceId && existingDriver.activeDeviceId !== deviceId) {
        if (io) {
          io.to(`driver_${existingDriver._id}`).emit('force_device_logout', {
            message: 'Your account was logged in on another device.'
          });
        }
        return res.status(403).json({
          success: false,
          error: 'LOGGED_IN_ON_ANOTHER_DEVICE',
          message: 'This account is active on another device.'
        });
      }

    const now = new Date();
    const updateData = { isOnline: !!isOnline };

    if (isOnline) {
      updateData.lastOnlineAt = now;
      if (!existingDriver.isOnline || !existingDriver.onlineSessionStart) {
        updateData.onlineSessionStart = now;
      }
    } else {
      if (existingDriver.onlineSessionStart) {
        const sessionSeconds = Math.max(0, Math.floor((now.getTime() - new Date(existingDriver.onlineSessionStart).getTime()) / 1000));
        updateData.onlineSecondsToday = (existingDriver.onlineSecondsToday || 0) + sessionSeconds;
        updateData.onlineSessionStart = null;
      }
    }

    const user = await User.findByIdAndUpdate(driverId, updateData, { new: true });

    // Calculate current duty time for socket update
    let currentDutySeconds = user.onlineSecondsToday || 0;
    if (user.isOnline && user.onlineSessionStart) {
      currentDutySeconds += Math.floor((Date.now() - new Date(user.onlineSessionStart).getTime()) / 1000);
    }
    const hrs = Math.floor(currentDutySeconds / 3600);
    const mins = Math.floor((currentDutySeconds % 3600) / 60);
    const dutyTimeStr = hrs > 0 ? `${hrs}h ${mins}m` : `${mins}m`;

    // Emit real-time notification to all admins for dispatch hub update
    // io is already declared above (line 391)
    if (io) {
      io.to('admin').emit('driver_status_update', {
        driverId: user._id,
        isOnline: user.isOnline,
        name: user.name,
        onlineDutyTime: dutyTimeStr,
        message: `Driver ${user.name} is now ${user.isOnline ? 'ONLINE' : 'OFFLINE'}`
      });
    }
    
    res.status(200).json({ success: true, isOnline: user.isOnline, onlineDutyTime: dutyTimeStr });
  } catch (err) {
    console.error('[setDriverStatus]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};
// @desc    Upload document side for driver verification
// @route   POST /api/v1/auth/upload-document
// @access  Public
exports.uploadDocumentSide = async (req, res) => {
  try {
    const { driverId, docType, side, fileUrl } = req.body;

    if (!driverId || !docType || !side || !fileUrl) {
      return res.status(400).json({ success: false, error: 'Please provide driverId, docType, side, and fileUrl' });
    }

    const validDocs = ['aadhar', 'license', 'rc', 'pan', 'bankStatement'];
    if (!validDocs.includes(docType)) {
      return res.status(400).json({ success: false, error: 'Invalid document type' });
    }

    if (!['front', 'back'].includes(side)) {
      return res.status(400).json({ success: false, error: 'Invalid side (must be front or back)' });
    }

    const user = await User.findById(driverId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    // Update document path and set status to pending
    if (!user.documents) user.documents = {};
    if (!user.documents[docType]) user.documents[docType] = {};
    
    user.documents[docType][side] = fileUrl;
    user.documents[docType].status = 'pending';

    await user.save();

    console.log(`[Document Upload] 📄 Driver ${user.name} uploaded ${docType} ${side}`);

    res.status(200).json({ 
      success: true, 
      message: `${docType} ${side} uploaded successfully`,
      documents: user.documents 
    });
  } catch (err) {
    console.error('[uploadDocumentSide]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get all document statuses for a specific driver
// @route   GET /api/v1/auth/documents/:driverId
exports.getDriverDocuments = async (req, res) => {
  try {
    const user = await User.findById(req.params.driverId).select('documents driverApprovalStatus name isOnline');
    if (!user) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }
    res.status(200).json({ 
      success: true, 
      data: user.documents || {}, 
      status: user.driverApprovalStatus,
      isOnline: user.isOnline || false
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Admin login
// @route   POST /api/v1/auth/admin-login
// @access  Public
exports.adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, error: 'Please provide email and password' });
    }

    // Admins usually login with email
    const user = await User.findOne({ 
      email, 
      role: { $in: ['admin', 'superadmin'] } 
    }).select('+password');

    if (!user) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const isMatch = await user.matchPassword(password);
    if (!isMatch) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const token = generateToken(user._id);

    console.log(`[Admin Login] 🔐 ${user.name} logged in over UI`);

    res.status(200).json({
      success: true,
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        permissions: user.permissions,
      },
    });
  } catch (err) {
    console.error('[adminLogin]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};
// @desc    Customer OTP Login - Check if customer exists, login if yes, signal new user if no
// @route   POST /api/v1/auth/customer-login
// @access  Public
exports.customerOtpLogin = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }

    // Look up customer by phone
    const user = await User.findOne({ phone, role: 'customer' });

    if (!user) {
      // Not registered yet - tell Flutter to go to registration
      return res.status(200).json({
        success: false,
        isNewUser: true,
        message: 'User not found. Please complete registration.',
      });
    }

    // Existing customer - generate token and return user data
    const token = generateToken(user._id);

    console.log(`[Customer Login] ✅ ${user.name} (${phone}) logged in via OTP`);

    res.status(200).json({
      success: true,
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email || '',
        phone: user.phone,
        role: user.role,
      },
    });
  } catch (err) {
    console.error('[customerOtpLogin]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};
