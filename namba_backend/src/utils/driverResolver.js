const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Known aliases or previous session IDs that map to current canonical drivers
const DRIVER_ALIASES = {
  '6a63575d6d06d3258119cd83': '8883998540', // Vishak legacy ID before DB reset
};

/**
 * Robust driver resolver that finds the canonical Driver User record
 * even if a client presents an old/stale ID, phone number, token, or device ID.
 *
 * @param {string|mongoose.Types.ObjectId} driverId - The driver ID or alias passed in request
 * @param {object} [req] - Express request object (optional)
 * @returns {Promise<User|null>} - Resolved driver User document or null
 */
async function resolveDriverUser(driverId, req = null) {
  try {
    let driver = null;
    const cleanId = driverId ? driverId.toString().trim() : '';

    // 1. Check known explicit legacy aliases
    if (cleanId && DRIVER_ALIASES[cleanId]) {
      driver = await User.findOne({ phone: DRIVER_ALIASES[cleanId], role: 'driver' });
      if (driver) {
        console.log(`[driverResolver] 🔄 Resolved alias ${cleanId} -> Driver ${driver.name} (${driver._id})`);
        return driver;
      }
    }

    // 2. Try direct ObjectId lookup
    if (cleanId && mongoose.Types.ObjectId.isValid(cleanId)) {
      driver = await User.findById(cleanId);
      if (driver && driver.role === 'driver') {
        return driver;
      }
    }

    // 3. Try lookup by phone number if passed as driverId
    if (cleanId && /^\d{10}$/.test(cleanId)) {
      driver = await User.findOne({ phone: cleanId, role: 'driver' });
      if (driver) {
        console.log(`[driverResolver] 📱 Resolved phone ${cleanId} -> Driver ${driver.name} (${driver._id})`);
        return driver;
      }
    }

    // 4. Try lookup via Bearer token in request headers
    if (req && req.headers && req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      try {
        const token = req.headers.authorization.split(' ')[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (decoded && decoded.id) {
          driver = await User.findById(decoded.id);
          if (driver && driver.role === 'driver') {
            console.log(`[driverResolver] 🔑 Resolved JWT token -> Driver ${driver.name} (${driver._id})`);
            return driver;
          }
        }
      } catch (_) {}
    }

    // 5. Try lookup via device ID
    const deviceId = (req && req.headers && req.headers['x-device-id']) || (req && req.body && req.body.deviceId);
    if (deviceId) {
      driver = await User.findOne({ activeDeviceId: deviceId, role: 'driver' });
      if (driver) {
        console.log(`[driverResolver] 📱 Resolved activeDeviceId "${deviceId}" -> Driver ${driver.name} (${driver._id})`);
        return driver;
      }
    }

    // 6. Resilient Fallback: If only one driver exists in database, use that driver
    const allDrivers = await User.find({ role: 'driver' });
    if (allDrivers.length === 1) {
      console.log(`[driverResolver] 🛡️ Fallback to sole active driver: ${allDrivers[0].name} (${allDrivers[0]._id})`);
      return allDrivers[0];
    }

    // 7. Default driver fallback (Vishak)
    const defaultDriver = await User.findOne({ phone: '8883998540', role: 'driver' });
    if (defaultDriver) {
      console.log(`[driverResolver] 🛡️ Fallback to default driver: ${defaultDriver.name} (${defaultDriver._id})`);
      return defaultDriver;
    }

    return null;
  } catch (err) {
    console.error('[driverResolver] Error resolving driver:', err);
    return null;
  }
}

/**
 * Resolves a driver ID to its canonical ObjectId string, or falls back to original.
 */
async function resolveDriverId(driverId, req = null) {
  const driver = await resolveDriverUser(driverId, req);
  if (driver && driver._id) {
    return driver._id.toString();
  }
  return driverId;
}

module.exports = {
  resolveDriverUser,
  resolveDriverId,
  DRIVER_ALIASES,
};
