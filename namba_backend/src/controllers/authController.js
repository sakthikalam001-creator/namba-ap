const User = require('../models/User');
const Vendor = require('../models/Vendor');
const jwt = require('jsonwebtoken');

// Generate JWT Token with sessionVersion support
const generateToken = (id, sessionVersion) => {
  const payload = { id };
  if (sessionVersion !== undefined) payload.sessionVersion = sessionVersion;
  return jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || '30d',
  });
};

// @desc    Register user
// @route   POST /api/v1/auth/register
// @access  Public
exports.register = async (req, res) => {
  try {
    const { name, phone, email, password, role } = req.body;

    // Check for existing user with the same role
    const existingUser = await User.findOne({ phone, role: role || 'customer' });
    if (existingUser) {
      if (existingUser.role === 'customer' && existingUser.name === 'Pending Registration') {
        // Complete the pending registration
        existingUser.name = name;
        if (email) existingUser.email = email;
        if (password) existingUser.password = password;
        await existingUser.save();

        const token = generateToken(existingUser._id);
        
        const io = req.app.get('socketio');
        if (io) {
          io.to('admin').emit('new_customer_registered', {
            message: `New customer registered: ${existingUser.name}`,
            customerId: existingUser._id,
          });
        }

        return res.status(201).json({
          success: true,
          token,
          user: {
            _id: existingUser._id,
            name: existingUser.name,
            role: existingUser.role,
          },
        });
      }
      return res.status(400).json({ success: false, error: 'Phone number already registered for this role' });
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

    // Check if phone already registered for vendor role
    const existingUser = await User.findOne({ phone, role: 'vendor' });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'Phone number already registered as a vendor' });
    }

    // Create the user account with vendor role
    const user = await User.create({
      name: ownerName,
      phone,
      email,
      password,
      role: 'vendor',
    });

    let resolvedCity = '';
    let resolvedPincode = '';
    if (storeAddress) {
      const addrLower = storeAddress.toLowerCase();
      if (addrLower.includes('chennai')) resolvedCity = 'Chennai';
      else if (addrLower.includes('erode')) resolvedCity = 'Erode';
      else if (addrLower.includes('coimbatore')) resolvedCity = 'Coimbatore';
      else if (addrLower.includes('salem')) resolvedCity = 'Salem';

      const pinMatch = storeAddress.match(/\b\d{6}\b/);
      if (pinMatch) resolvedPincode = pinMatch[0];
    }

    // Default coordinates based on resolvedCity if GPS is not available/provided
    let defaultLng = 77.7172; // Erode Lng
    let defaultLat = 11.3410; // Erode Lat
    if (resolvedCity === 'Chennai') {
      defaultLng = 80.2707;
      defaultLat = 13.0827;
    } else if (resolvedCity === 'Coimbatore') {
      defaultLng = 76.9558;
      defaultLat = 11.0168;
    } else if (resolvedCity === 'Salem') {
      defaultLng = 78.1460;
      defaultLat = 11.6643;
    }

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
      location: {
        type: 'Point',
        coordinates: [
          (lng !== undefined && lng !== null) ? parseFloat(lng) : defaultLng,
          (lat !== undefined && lat !== null) ? parseFloat(lat) : defaultLat
        ],
        city: resolvedCity,
        pincode: resolvedPincode,
        formattedAddress: storeAddress || ''
      }
    };

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

    // Check if phone already registered for driver role
    const existingUser = await User.findOne({ phone, role: 'driver' });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'Phone number already registered as a driver' });
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
      const { phone, password, deviceId, deviceInfo, role } = req.body;

      if (!phone || !password) {
        return res.status(400).json({ success: false, error: 'Please provide phone and password' });
      }

      // Check for user (include password explicitly since select is false in schema)
      const query = { phone };
      if (role) query.role = role;
      const user = await User.findOne(query).select('+password');

      if (!user || !user.password) {
        return res.status(401).json({ success: false, error: 'Invalid phone number or password' });
      }

      if (!user.isActive) {
        return res.status(403).json({ success: false, error: 'Account is deactivated or offboarded. Contact support.' });
      }

      // Check if password matches
      const isMatch = await user.matchPassword(password);

      if (!isMatch) {
        return res.status(401).json({ success: false, error: 'Invalid credentials' });
      }

      const io = req.app.get('socketio');

      // ── Strict Single-Device Lock for Drivers ─────────────────────────────
      if (user.role === 'driver') {
        // If user already has an active session on a different device
        if (
          user.isSessionActive &&
          user.activeDeviceId &&
          deviceId &&
          user.activeDeviceId !== deviceId
        ) {
          return res.status(403).json({
            success: false,
            isDeviceLocked: true,
            error: 'This account is currently active on another mobile device. Please log out from that device first or contact Super Admin to terminate the session.',
          });
        }

        // Lock session to current device
        user.activeDeviceId = deviceId || user.activeDeviceId || 'unknown-device';
        user.isSessionActive = true;
        user.sessionVersion = (user.sessionVersion || 0) + 1;
        user.lastLoginAt = new Date();
        if (deviceInfo) user.deviceInfo = deviceInfo;
        await user.save();
      }

      const token = generateToken(user._id, user.sessionVersion);

    // If vendor, attach vendor profile
    let vendorData = null;
    if (user.role === 'vendor') {
      const vendorDoc = await Vendor.findOne({ user: user._id });
      if (vendorDoc) {
        vendorData = vendorDoc.toObject({ versionKey: false });
        vendorData._id = vendorData._id.toString();
        vendorData.user = vendorData.user ? vendorData.user.toString() : null;
      }
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
        isSessionActive: user.isSessionActive,
        activeDeviceId: user.activeDeviceId,
      },
      vendor: vendorData,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Logout user & terminate active device session
// @route   POST /api/v1/auth/logout
// @access  Public / Private
exports.logout = async (req, res) => {
  try {
    const userId = (req.user && req.user._id) ? req.user._id : req.body.userId;
    if (!userId) {
      return res.status(400).json({ success: false, error: 'User ID required for logout' });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    // Reset device session
    user.activeDeviceId = null;
    user.isSessionActive = false;
    user.sessionVersion = (user.sessionVersion || 0) + 1;

    // If driver was online, mark offline and close duty session
    if (user.role === 'driver') {
      user.isOnline = false;
      const now = new Date();
      if (user.onlineSessionStart) {
        const sessionSeconds = Math.max(0, Math.floor((now.getTime() - new Date(user.onlineSessionStart).getTime()) / 1000));
        user.onlineSecondsToday = (user.onlineSecondsToday || 0) + sessionSeconds;
        user.onlineSessionStart = null;
      }

      try {
        const DriverDutySession = require('../models/DriverDutySession');
        await DriverDutySession.updateMany(
          { driver: user._id, offlineTime: null },
          { $set: { offlineTime: now } }
        );
      } catch (dutyErr) {
        console.error('[Logout] Error updating duty session:', dutyErr);
      }
    }

    await user.save();

    const io = req.app.get('socketio');
    if (io) {
      io.to(`driver_${user._id}`).emit('driver_logged_out', { message: 'Logged out successfully' });
      io.emit('driver_status_changed', { driverId: user._id, isOnline: false });
    }

    res.status(200).json({
      success: true,
      message: 'Logged out and device session terminated successfully',
    });
  } catch (err) {
    console.error('[Logout Error]:', err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Admin terminates driver mobile session remotely (Force Logout)
// @route   POST /api/v1/admin/drivers/:id/force-logout
// @access  Private (Admin / Superadmin)
exports.forceLogoutDriver = async (req, res) => {
  try {
    const driverId = req.params.id || req.body.driverId;
    if (!driverId) {
      return res.status(400).json({ success: false, error: 'Driver ID is required' });
    }

    const driver = await User.findById(driverId);
    if (!driver) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    // Reset session & device lock
    driver.activeDeviceId = null;
    driver.isSessionActive = false;
    driver.sessionVersion = (driver.sessionVersion || 0) + 1;
    driver.isOnline = false;

    const now = new Date();
    if (driver.onlineSessionStart) {
      const sessionSeconds = Math.max(0, Math.floor((now.getTime() - new Date(driver.onlineSessionStart).getTime()) / 1000));
      driver.onlineSecondsToday = (driver.onlineSecondsToday || 0) + sessionSeconds;
      driver.onlineSessionStart = null;
    }

    try {
      const DriverDutySession = require('../models/DriverDutySession');
      await DriverDutySession.updateMany(
        { driver: driver._id, offlineTime: null },
        { $set: { offlineTime: now } }
      );
    } catch (dutyErr) {
      console.error('[ForceLogoutDriver] Error closing duty session:', dutyErr);
    }

    await driver.save();

    const io = req.app.get('socketio');
    if (io) {
      // Send force logout event to driver's socket room
      io.to(`driver_${driver._id}`).emit('force_device_logout', {
        message: 'Your mobile session was terminated by Super Admin. You can now log in on your current device.',
        terminatedByAdmin: true,
      });
      io.emit('driver_status_changed', { driverId: driver._id, isOnline: false });
    }

    res.status(200).json({
      success: true,
      message: `Driver ${driver.name} device session successfully terminated. Device lock released.`,
      driver: {
        _id: driver._id,
        name: driver.name,
        isOnline: driver.isOnline,
        isSessionActive: false,
        activeDeviceId: null,
      },
    });
  } catch (err) {
    console.error('[ForceLogoutDriver Error]:', err);
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

    // Generate 6-digit OTP or 4-digit PIN based on role
    // Generate 6-digit OTP or 6-digit PIN based on role
    const isCustomer = user.role === 'customer';
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Set OTP and expiry (10 minutes)
    user.resetPasswordOtp = otp;
    user.resetPasswordExpire = Date.now() + 10 * 60 * 1000;

    await user.save();

    if (isCustomer) {
      try {
        const { sendWhatsAppMessage } = require('../utils/whatsapp');
        const messageText = `Namba Delivery: Your security PIN is ${otp}. It is valid for 10 minutes.`;
        await sendWhatsAppMessage(phone, messageText);
      } catch (waErr) {
        console.error('[WhatsApp API Error]', waErr.message);
      }
    } else {
      console.log(`[Forgot Password] 🔑 OTP for ${phone}: ${otp}`);
    }

    res.status(200).json({
      success: true,
      message: isCustomer ? 'Security PIN sent to WhatsApp successfully' : 'OTP sent successfully',
      otp_simulated: otp // In production, this would be sent via SMS/WhatsApp and removed from response
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
      const { driverId, isOnline, deviceId, forceLogout, action } = req.body;
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

      const isForceLogout = forceLogout === true || action === 'FORCE_LOGOUT';
      if (isForceLogout) {
        if (io) {
          io.to(`driver_${existingDriver._id}`).emit('force_device_logout', {
            driverId: existingDriver._id,
            message: 'Super Admin terminated this mobile device session.'
          });
          io.emit('driver_status_update', {
            driverId: existingDriver._id,
            isOnline: false,
            action: 'FORCE_LOGOUT',
            forceLogout: true,
            message: 'Driver forced offline by Super Admin.'
          });
        }
      }

      // Enforce device lock on status update
      if (!isForceLogout && deviceId && existingDriver.activeDeviceId && existingDriver.activeDeviceId !== deviceId) {
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
    if (isForceLogout) {
      updateData.activeDeviceId = null;
      updateData.isSessionActive = false;
      updateData.sessionVersion = (existingDriver.sessionVersion || 1) + 1;
    }

    const DriverDutySession = require('../models/DriverDutySession');

    if (isOnline) {
      updateData.lastOnlineAt = now;
      if (!existingDriver.isOnline || !existingDriver.onlineSessionStart) {
        updateData.onlineSessionStart = existingDriver.onlineSessionStart || now;
      }

      // Ensure active DriverDutySession exists
      try {
        const activeSession = await DriverDutySession.findOne({
          driver: driverId,
          offlineTime: null
        });

        if (!activeSession) {
          const sessionStart = updateData.onlineSessionStart || existingDriver.onlineSessionStart || now;
          const localDate = new Date(sessionStart.getTime() + (5.5 * 60 * 60 * 1000)).toISOString().split('T')[0]; // IST Date YYYY-MM-DD
          await DriverDutySession.create({
            driver: driverId,
            date: localDate,
            onlineTime: sessionStart,
          });
          console.log(`[DutySession] 🟢 Active session created/ensured for driver ${driverId} at ${sessionStart}`);
        }
      } catch (sessionErr) {
        console.error('[DutySession] Failed to ensure session:', sessionErr);
      }
    } else {
      if (existingDriver.onlineSessionStart || existingDriver.isOnline) {
        const sessionStart = existingDriver.onlineSessionStart || now;
        const sessionSeconds = Math.max(0, Math.floor((now.getTime() - new Date(sessionStart).getTime()) / 1000));
        updateData.onlineSecondsToday = (existingDriver.onlineSecondsToday || 0) + sessionSeconds;
        updateData.onlineSessionStart = null;

        // Log session end (offline time)
        try {
          const activeSession = await DriverDutySession.findOne({
            driver: driverId,
            offlineTime: null
          }).sort({ onlineTime: -1 });

          if (activeSession) {
            activeSession.offlineTime = now;
            activeSession.durationSeconds = sessionSeconds;
            await activeSession.save();
            console.log(`[DutySession] 🔴 Session ended for driver ${driverId} at ${now} (Duration: ${sessionSeconds}s)`);
          } else {
            console.warn(`[DutySession] ⚠️ No active session found to close for driver ${driverId}`);
          }
        } catch (sessionErr) {
          console.error('[DutySession] Failed to close session:', sessionErr);
        }
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

    const validDocs = ['selfie', 'aadhar', 'license', 'rc', 'pan', 'bankStatement', 'bankDetails'];
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

    // Mirror bankStatement / bankDetails
    if (docType === 'bankDetails' || docType === 'bankStatement') {
      if (!user.documents.bankStatement) user.documents.bankStatement = {};
      if (!user.documents.bankDetails) user.documents.bankDetails = {};
      user.documents.bankStatement[side] = fileUrl;
      user.documents.bankStatement.status = 'pending';
      user.documents.bankDetails[side] = fileUrl;
      user.documents.bankDetails.status = 'pending';
    }

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

// @desc    Save rich bank & UPI details for driver
// @route   POST /api/v1/auth/save-bank-details
// @access  Public
exports.saveDriverBankDetails = async (req, res) => {
  try {
    const { driverId, accountHolderName, accountNumber, ifscCode, bankName, upiId, upiNumber, fileUrl } = req.body;

    if (!driverId) {
      return res.status(400).json({ success: false, error: 'Please provide driverId' });
    }

    const user = await User.findById(driverId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }

    if (!user.documents) user.documents = {};
    if (!user.documents.bankStatement) user.documents.bankStatement = {};
    if (!user.documents.bankDetails) user.documents.bankDetails = {};

    const bankPayload = {
      accountHolderName: accountHolderName || user.name,
      accountNumber: accountNumber || '',
      ifscCode: (ifscCode || '').toUpperCase(),
      bankName: bankName || '',
      upiId: upiId || '',
      upiNumber: upiNumber || '',
      front: fileUrl || user.documents.bankStatement.front || user.documents.bankDetails.front || '',
      status: 'pending',
    };

    user.documents.bankDetails = { ...user.documents.bankDetails, ...bankPayload };
    user.documents.bankStatement = { ...user.documents.bankStatement, ...bankPayload };

    await user.save();

    console.log(`[Bank Details] 🏦 Saved Bank & UPI details for Driver ${user.name}: A/C ${accountNumber}, IFSC ${ifscCode}, UPI ${upiId || upiNumber}`);

    res.status(200).json({
      success: true,
      message: 'Bank and UPI details saved successfully',
      documents: user.documents,
    });
  } catch (err) {
    console.error('[saveDriverBankDetails]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Get all document statuses for a specific driver
// @route   GET /api/v1/auth/documents/:driverId
exports.getDriverDocuments = async (req, res) => {
  try {
    const user = await User.findById(req.params.driverId).select('documents driverApprovalStatus driverRejectionReason name isOnline hotZonesEnabled');
    if (!user) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }
    res.status(200).json({ 
      success: true, 
      data: user.documents || {}, 
      status: user.driverApprovalStatus || 'pending',
      rejectionReason: user.driverRejectionReason || '',
      isOnline: user.isOnline || false,
      hotZonesEnabled: user.hotZonesEnabled === true
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

// @desc    Send 6-digit Security PIN to WhatsApp
// @route   POST /api/v1/auth/send-security-pin
// @access  Public
exports.sendSecurityPin = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone || !/^\d{10}$/.test(phone)) {
      return res.status(400).json({ success: false, error: 'Please provide a valid 10-digit phone number' });
    }

    // Find or create customer
    let user = await User.findOne({ phone, role: 'customer' });

    if (!user) {
      // Create user in a pending registration state
      user = await User.create({
        name: 'Pending Registration',
        phone,
        email: `pending_${phone}@nambadelivery.com`,
        role: 'customer',
      });
    }

    // Generate 6-digit PIN
    const pin = Math.floor(100000 + Math.random() * 900000).toString();

    // Set PIN and expiry (10 minutes)
    user.resetPasswordOtp = pin;
    user.resetPasswordExpire = Date.now() + 10 * 60 * 1000;
    await user.save();

    // Send real WhatsApp message
    try {
      const { sendWhatsAppMessage } = require('../utils/whatsapp');
      const messageText = `Namba Delivery: Your security PIN is ${pin}. It is valid for 10 minutes.`;
      await sendWhatsAppMessage(phone, messageText);
    } catch (waErr) {
      console.error('[WhatsApp API Error]', waErr.message);
    }

    res.status(200).json({
      success: true,
      message: 'Security PIN sent to WhatsApp successfully',
    });
  } catch (err) {
    console.error('[sendSecurityPin]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};

// @desc    Verify 6-digit Security PIN and complete login/registration check
// @route   POST /api/v1/auth/verify-security-pin
// @access  Public
exports.verifySecurityPin = async (req, res) => {
  try {
    const { phone, pin } = req.body;

    if (!phone || !pin) {
      return res.status(400).json({ success: false, error: 'Please provide phone and security PIN' });
    }

    const user = await User.findOne({
      phone,
      role: 'customer',
      resetPasswordOtp: pin,
      resetPasswordExpire: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({ success: false, error: 'Invalid or expired security PIN' });
    }

    const isNewUser = user.name === 'Pending Registration';

    if (isNewUser) {
      // Clear the PIN
      user.resetPasswordOtp = undefined;
      user.resetPasswordExpire = undefined;
      await user.save();

      return res.status(200).json({
        success: true,
        isNewUser: true,
        message: 'Security PIN verified. Please complete registration.'
      });
    }

    // Existing user -> Generate token and return login payload
    const token = generateToken(user._id);

    // Clear the PIN
    user.resetPasswordOtp = undefined;
    user.resetPasswordExpire = undefined;
    await user.save();

    console.log(`[Customer Login] ✅ ${user.name} (${phone}) logged in via WhatsApp Security PIN`);

    res.status(200).json({
      success: true,
      isNewUser: false,
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
    console.error('[verifySecurityPin]', err);
    res.status(500).json({ success: false, error: err.message });
  }
};
