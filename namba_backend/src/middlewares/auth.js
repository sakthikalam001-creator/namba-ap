const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Protect routes
exports.protect = async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    // Get token from header
    token = req.headers.authorization.split(' ')[1];
  }

  // Make sure token exists
  if (!token) {
    return res.status(401).json({ success: false, error: 'Not authorized to access this route' });
  }

  try {
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Get user from the token
    req.user = await User.findById(decoded.id);

    if (!req.user) {
      return res.status(401).json({ success: false, error: 'No user found with this id' });
    }

    if (!req.user.isActive) {
      return res.status(401).json({ success: false, error: 'ACCOUNT_DEACTIVATED', message: 'This account has been deactivated or offboarded.' });
    }

    // Driver Single-Device Session Validation
    if (req.user.role === 'driver') {
      if (
        decoded.sessionVersion !== undefined &&
        req.user.sessionVersion !== undefined &&
        decoded.sessionVersion !== req.user.sessionVersion
      ) {
        return res.status(401).json({
          success: false,
          error: 'SESSION_EXPIRED',
          message: 'Your active session was terminated or logged out. Please log in again.',
        });
      }

      const clientDeviceId = req.headers['x-device-id'];
      if (clientDeviceId && req.user.activeDeviceId && req.user.activeDeviceId !== clientDeviceId) {
        return res.status(401).json({
          success: false,
          error: 'DEVICE_MISMATCH',
          message: 'This account is active on another device.',
        });
      }
    }

    next();
  } catch (err) {
    console.error('JWT Verification Error:', err.message);
    return res.status(401).json({ success: false, error: 'Not authorized to access this route' });
  }
};

// Grant access to specific roles
exports.authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: `User role ${req.user.role} is not authorized to access this route`
      });
    }
    next();
  };
};
