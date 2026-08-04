const dotenv = require('dotenv');
// Load env vars - Triggered Restart for Sync Fix
dotenv.config();

// Handle Uncaught Exceptions
process.on('uncaughtException', (err) => {
  console.error('[CRITICAL] Uncaught Exception! Shutting down...', err.name, err.message);
  console.error(err.stack);
  process.exit(1);
});

const http = require('http');
const { Server } = require('socket.io');

const app = require('./src/app');
const connectDB = require('./src/config/db');

// Connect to MongoDB
connectDB();

// Create HTTP server attached to the Express app
const server = http.createServer(app);

// Attach Socket.io for Real-time Engine
const io = new Server(server, {
  cors: {
    origin: '*', // For development. Change to explicit domains in production.
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
  },
});

// Drivers maintain their persistent online/offline state set manually by driver or admin
// app.set('socketio', io);

// Make `io` accessible via req.app.get('socketio') in controllers
app.set('socketio', io);

io.on('connection', (socket) => {
  console.log(`[Socket] New client connected: ${socket.id}`);

  // Basic diagnostic room join
  socket.on('join_room', (room) => {
    socket.join(room);
    console.log(`[Room] Socket ${socket.id} joined room ${room}`);
    
    // If a driver joins their specific room, track them
    if (room.startsWith('driver_')) {
      socket.driverId = room.split('driver_')[1];
      socket.data = socket.data || {};
      socket.data.driverId = socket.driverId;
    }

    // Track vendor room association
    if (room.startsWith('vendor_')) {
      socket.vendorId = room.split('vendor_')[1];
      socket.data = socket.data || {};
      socket.data.vendorId = socket.vendorId;
      console.log(`[Socket] Vendor ${socket.vendorId} associated with socket ${socket.id}`);
    }
  });

  // Real-time location tracking for riders
  socket.on('update_rider_location', async (data) => {
    try {
      if (!data) return;
      // data = { orderId, riderId, riderName, lat, lng }
      const { orderId, riderId, lat, lng } = data;

      // 1. Update the driver's lastLocation coordinates in database
      if (riderId && lat && lng) {
        try {
          const User = require('./src/models/User');
          await User.findByIdAndUpdate(riderId, {
            lastLocation: {
              type: 'Point',
              coordinates: [parseFloat(lng), parseFloat(lat)] // GeoJSON is [lng, lat]
            }
          });
        } catch (err) {
          console.error(`[Socket] Failed to update driver ${riderId} location in DB:`, err);
        }
      }

      // 2. Broadcast to order tracking room if orderId exists and is NOT "online"
      if (orderId && orderId !== 'online') {
        io.to(`order_${orderId}`).emit('rider_location_updated', data);
      }

      // 3. Broadcast globally to admins for live dispatch tracking
      io.emit('update_rider_location', data);
    } catch (socketErr) {
      console.error('[Socket] Error handling update_rider_location:', socketErr);
    }
  });

  socket.on('disconnect', async (reason) => {
    console.log(`[Socket] Client disconnected: ${socket.id}, Reason: ${reason}`);

    if (socket.vendorId) {
      const vendorId = socket.vendorId;
      // Wait 5 seconds to verify if they reconnect or if another device is active
      setTimeout(async () => {
        try {
          const activeSockets = await io.in(`vendor_${vendorId}`).fetchSockets();
          if (activeSockets.length === 0) {
            console.log(`[Socket] Vendor ${vendorId} completely disconnected. Marking store as Closed.`);
            const Vendor = require('./src/models/Vendor');
            const updatedVendor = await Vendor.findByIdAndUpdate(vendorId, { isOpen: false }, { new: true });
            if (updatedVendor) {
              console.log(`[Socket] Auto-closed store "${updatedVendor.storeName}" due to disconnect.`);
              io.emit('vendor_status_update', {
                vendorId: updatedVendor._id,
                isOpen: false,
                storeName: updatedVendor.storeName
              });
            }
          }
        } catch (err) {
          console.error(`[Socket] Failed to auto-close vendor ${vendorId}:`, err);
        }
      }, 5000);
    }
  });
});

// ── TRIAL EXPIRY WATCHER ─────────────────────────────────────────────────────
// Runs every hour. Finds vendors whose trial has expired and notifies them.
const checkTrialExpiries = async () => {
  try {
    const Vendor = require('./src/models/Vendor');
    const now = new Date();

    // Find vendors whose trial expired AND are not yet subscribed AND not already locked for this reason
    const expiredVendors = await Vendor.find({
      trialExpiry: { $lt: now },
      isSubscribed: false,
      approvalStatus: 'approved',
      isManuallyUnlocked: { $ne: true },
    }).populate('user', 'name phone');

    if (expiredVendors.length === 0) return;

    console.log(`[Trial Watcher] ⏰ Found ${expiredVendors.length} vendor(s) with expired trials.`);

    for (const vendor of expiredVendors) {
      const daysExpired = Math.floor((now - new Date(vendor.trialExpiry)) / (1000 * 60 * 60 * 24));

      // Send real-time socket notification to vendor
      io.to(`vendor_${vendor._id}`).emit('trial_expired', {
        vendorId: vendor._id,
        storeName: vendor.storeName,
        trialExpiry: vendor.trialExpiry,
        daysExpired,
        message: `உங்கள் Trial Period முடிந்துவிட்டது! தொடர்ந்து சேவை பெற Subscription எடுங்கள்.`,
        messageEn: `Your free trial has ended ${daysExpired > 0 ? daysExpired + ' day(s) ago' : 'today'}. Please subscribe to continue using the platform.`,
        action: 'SUBSCRIBE_NOW',
      });

      // If trial expired more than 1 day ago AND store is still open → lock it
      if (daysExpired >= 1 && !vendor.isLocked) {
        await Vendor.findByIdAndUpdate(vendor._id, {
          isLocked: true,
          isOpen: false,
          lockReason: 'Trial period expired. Please subscribe to reactivate your store.',
        });

        // Notify vendor of the lock
        io.to(`vendor_${vendor._id}`).emit('access_update', {
          isLocked: true,
          lockReason: 'Trial period expired. Please subscribe to reactivate your store.',
          trialExpiry: vendor.trialExpiry,
          subscriptionExpiry: vendor.subscriptionExpiry,
          showSubscriptionBadge: true,
          permissions: vendor.permissions,
        });

        // Notify admin dashboard
        io.to('admin').emit('vendor_trial_expired', {
          vendorId: vendor._id,
          storeName: vendor.storeName,
          phone: vendor.phone,
          trialExpiry: vendor.trialExpiry,
          daysExpired,
          autoLocked: true,
        });

        console.log(`[Trial Watcher] 🔒 Auto-locked vendor "${vendor.storeName}" (trial expired ${daysExpired}d ago)`);
      } else if (daysExpired === 0) {
        // Trial just expired today → warn but don't lock yet
        io.to('admin').emit('vendor_trial_expired', {
          vendorId: vendor._id,
          storeName: vendor.storeName,
          phone: vendor.phone,
          trialExpiry: vendor.trialExpiry,
          daysExpired: 0,
          autoLocked: false,
        });

        console.log(`[Trial Watcher] ⚠️  Vendor "${vendor.storeName}" trial expired TODAY. Notified, not yet locked.`);
      }
    }
  } catch (err) {
    console.error('[Trial Watcher] ❌ Error during trial expiry check:', err.message);
  }
};

// Run immediately on startup, then every hour
checkTrialExpiries();
setInterval(checkTrialExpiries, 60 * 60 * 1000); // Every 1 hour
// ─────────────────────────────────────────────────────────────────────────────

// ── OPERATING HOURS AUTO-SCHEDULER ───────────────────────────────────────────
// Runs every 1 minute. Automatically opens and closes stores based on their operating hours.
const checkOperatingHours = async () => {
  try {
    const now = new Date();
    // India Standard Time is UTC + 5.5 hours (5 hours 30 minutes)
    const utc = now.getTime() + (now.getTimezoneOffset() * 60000);
    const ist = new Date(utc + (3600000 * 5.5));

    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const currentDay = days[ist.getDay()];
    const hours = ist.getHours().toString().padStart(2, '0');
    const minutes = ist.getMinutes().toString().padStart(2, '0');
    const currentTimeStr = `${hours}:${minutes}`;

    const Vendor = require('./src/models/Vendor');
    // Find all vendors with autoSchedulingEnabled
    const vendors = await Vendor.find({ autoSchedulingEnabled: true });

    for (const vendor of vendors) {
      if (!vendor.operatingHours || vendor.operatingHours.length === 0) continue;
      const dayConfig = vendor.operatingHours.find(d => d.day === currentDay);
      if (!dayConfig) continue;

      if (dayConfig.open) {
        // Transition to Open/Online
        if (dayConfig.from === currentTimeStr && !vendor.isOpen) {
          // Check if active subscription or trial
          const hasActiveSubscription = vendor.isSubscribed && vendor.subscriptionExpiry && vendor.subscriptionExpiry > now;
          const hasActiveTrial = vendor.trialExpiry && vendor.trialExpiry > now;
          const isManuallyUnlocked = vendor.isManuallyUnlocked === true;

          if (hasActiveSubscription || hasActiveTrial || isManuallyUnlocked) {
            await Vendor.findByIdAndUpdate(vendor._id, { isOpen: true });
            console.log(`[Auto-Schedule] Opened store "${vendor.storeName}" at ${currentTimeStr}`);
            io.emit('vendor_status_update', {
              vendorId: vendor._id,
              isOpen: true,
              storeName: vendor.storeName
            });
          } else {
            console.log(`[Auto-Schedule] Skipped opening "${vendor.storeName}" at ${currentTimeStr} - Subscription Required`);
          }
        }
        // Transition to Closed/Offline
        if (dayConfig.to === currentTimeStr && vendor.isOpen) {
          await Vendor.findByIdAndUpdate(vendor._id, { isOpen: false });
          console.log(`[Auto-Schedule] Closed store "${vendor.storeName}" at ${currentTimeStr}`);
          io.emit('vendor_status_update', {
            vendorId: vendor._id,
            isOpen: false,
            storeName: vendor.storeName
          });
        }
      } else {
        // If configured as closed today, and currently open, shut it at start of day
        if (currentTimeStr === "00:00" && vendor.isOpen) {
          await Vendor.findByIdAndUpdate(vendor._id, { isOpen: false });
          console.log(`[Auto-Schedule] Closed store "${vendor.storeName}" (Configured closed on ${currentDay})`);
          io.emit('vendor_status_update', {
            vendorId: vendor._id,
            isOpen: false,
            storeName: vendor.storeName
          });
        }
      }
    }
  } catch (err) {
    console.error('[Auto-Schedule] Error checking operating hours:', err.message);
  }
};

// Run checkOperatingHours every 1 minute
checkOperatingHours();
setInterval(checkOperatingHours, 60 * 1000); // Every 60 seconds
// ─────────────────────────────────────────────────────────────────────────────

// Drivers stay Online until they manually swipe to Offline in their mobile app.

const PORT = process.env.PORT || 5000;

server.listen(PORT, () => {
  console.log(`[Server] Ecosystem Backend running on port ${PORT} in ${process.env.NODE_ENV} mode.`);
});

// Handle Unhandled Rejections (Async errors)
process.on('unhandledRejection', (err) => {
  console.error('[NON-FATAL] Unhandled Rejection:', err ? (err.name + ': ' + err.message) : err);
  if (err && err.stack) console.error(err.stack);
});

// Graceful Shutdown on standard signals
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    console.log('Process terminated.');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  server.close(() => {
    console.log('Process terminated.');
  });
});
