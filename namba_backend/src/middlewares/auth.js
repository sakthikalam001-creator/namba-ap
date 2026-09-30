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
    let user = await User.findById(decoded.id);
    if (!user) {
      const { resolveDriverUser } = require('../utils/driverResolver');
      user = await resolveDriverUser(decoded.id, req);
    }
    req.user = user;

    if (!req.user) {
      return res.status(401).json({ success: false, error: 'No user found with this id' });
    }

    if (!req.user.isActive) {
      return res.status(401).json({ success: false, error: 'ACCOUNT_DEACTIVATED', message: 'This account has been deactivated or offboarded.' });
    }

    // Driver Single-Device Session Validation (with seamless device transition)
    if (req.user.role === 'driver') {
      const clientDeviceId = req.headers['x-device-id'];
      if (clientDeviceId && req.user.activeDeviceId && req.user.activeDeviceId !== clientDeviceId) {
        req.user.activeDeviceId = clientDeviceId;
        req.user.isSessionActive = true;
        await req.user.save();
      }
    }

    next();
  } catch (err) {
    // Routine token expiration should return 401 cleanly without flooding server-error.log
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        success: false, 
        error: 'TOKEN_EXPIRED', 
        message: 'Your login session has expired. Please log in again.' 
      });
    }
    // Only log unexpected authentication failures
    if (err.name !== 'JsonWebTokenError') {
      console.warn('[Auth Middleware]', err.message);
    }
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
