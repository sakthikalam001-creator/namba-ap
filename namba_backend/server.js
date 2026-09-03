const dotenv = require('dotenv');
// Load env vars - Triggered Restart for Sync Fix
dotenv.config();

// Handle Uncaught Exceptions gracefully without crashing the whole process
process.on('uncaughtException', (err) => {
  console.error('[CRITICAL-LOG] Uncaught Exception trapped:', err ? (err.name + ': ' + err.message) : err);
  if (err && err.stack) console.error(err.stack);
});

const http = require('http');
const { Server } = require('socket.io');

const app = require('./src/app');
const connectDB = require('./src/config/db');

// Connect to MongoDB
connectDB();

// Initialize Self-Hosted WhatsApp Web Client (for sending OTP PINs)
require('./src/utils/whatsappClient');

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

// Helper to check if current time is within vendor's scheduled operating hours
const isWithinOperatingHours = (vendor, ist) => {
  if (!vendor.operatingHours || vendor.operatingHours.length === 0) return false;
  
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const currentDay = days[ist.getDay()];
  const dayConfig = vendor.operatingHours.find(d => d.day === currentDay);
  if (!dayConfig || !dayConfig.open) return false;
  
  const hours = ist.getHours().toString().padStart(2, '0');
  const minutes = ist.getMinutes().toString().padStart(2, '0');
  const currentTimeStr = `${hours}:${minutes}`;
  
  return currentTimeStr >= dayConfig.from && currentTimeStr < dayConfig.to;
};

io.on('connection', (socket) => {
  console.log(`[Socket] New client connected: ${socket.id}`);
  
  // Basic diagnostic room join
  socket.on('join_room', (room) => {
    try {
      if (!room || typeof room !== 'string') return;
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
        const vendorId = room.split('vendor_')[1];
        socket.vendorId = vendorId;
        socket.data = socket.data || {};
        socket.data.vendorId = socket.vendorId;
        console.log(`[Socket] Vendor ${socket.vendorId} associated with socket ${socket.id}`);

        // Broadcast current store status immediately on connection/reconnection
        setTimeout(async () => {
          try {
            const Vendor = require('./src/models/Vendor');
            const vendor = await Vendor.findById(vendorId);
            if (vendor) {
              const now = new Date();
              const updateData = { lastOnlineAt: now };

              if (vendor.autoSchedulingEnabled && !vendor.isOpen) {
                const utc = now.getTime() + (now.getTimezoneOffset() * 60000);
                const ist = new Date(utc + (3600000 * 5.5));
                
                if (isWithinOperatingHours(vendor, ist)) {
                  const hasActiveSubscription = vendor.isSubscribed && vendor.subscriptionExpiry && vendor.subscriptionExpiry > now;
                  const hasActiveTrial = vendor.trialExpiry && vendor.trialExpiry > now;
                  const isManuallyUnlocked = vendor.isManuallyUnlocked === true;

                  if (hasActiveSubscription || hasActiveTrial || isManuallyUnlocked) {
                    updateData.isOpen = true;
                    vendor.isOpen = true;
                    console.log(`[Socket] Auto-opened store "${vendor.storeName}" on connection (within operating hours)`);
                  }
                }
              }

              // Update in DB
              await Vendor.findByIdAndUpdate(vendorId, updateData);
              vendor.lastOnlineAt = now;

              // Re-broadcast live online status to Admin and Customers
              io.emit('vendor_status_update', {
                vendorId: vendor._id.toString(),
                isOpen: vendor.isOpen,
                storeName: vendor.storeName,
                lastOfflineAt: vendor.lastOfflineAt ? vendor.lastOfflineAt.toISOString() : null,
                lastOnlineAt: now.toISOString(),
              });
              io.emit('vendor_status', {
                type: 'vendor_status',
                vendorId: vendor._id.toString(),
                isOpen: vendor.isOpen,
                storeName: vendor.storeName,
                lastOfflineAt: vendor.lastOfflineAt ? vendor.lastOfflineAt.toISOString() : null,
                lastOnlineAt: now.toISOString(),
              });
            }
          } catch (err) {
            console.error(`[Socket] Status sync on connection failed for vendor ${vendorId}:`, err.message);
          }
        }, 300);
      }
    } catch (err) {
      console.error('[Socket] Error in join_room:', err);
    }
  });

  socket.on('join_driver_room', async (data) => {
    try {
      const dId = (typeof data === 'object' ? data.driverId : data) || '';
      if (dId) {
        socket.join(`driver_${dId}`);
        socket.driverId = dId;
        socket.data = socket.data || {};
        socket.data.driverId = dId;
        console.log(`[Socket] Driver ${dId} joined driver_${dId} on socket ${socket.id}`);

        // Broadcast driver online status to admin dispatch hub
        try {
          const User = require('./src/models/User');
          const driver = await User.findById(dId);
          if (driver && driver.isOnline) {
            let currentDutySeconds = driver.onlineSecondsToday || 0;
            if (driver.onlineSessionStart) {
              currentDutySeconds += Math.floor((Date.now() - new Date(driver.onlineSessionStart).getTime()) / 1000);
            }
            const hrs = Math.floor(currentDutySeconds / 3600);
            const mins = Math.floor((currentDutySeconds % 3600) / 60);
            const dutyTimeStr = hrs > 0 ? `${hrs}h ${mins}m` : `${mins}m`;

            io.to('admin').emit('driver_status_update', {
              driverId: driver._id,
              isOnline: true,
              name: driver.name,
              onlineDutyTime: dutyTimeStr,
              message: `Driver ${driver.name} is ONLINE`
            });
          }
        } catch (_) {}
      }
    } catch (err) {
      console.error('[Socket] Error in join_driver_room:', err);
    }
  });

  // Haversine distance calculator
  function calcHaversineKm(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  // Real-time location tracking for riders
  socket.on('update_rider_location', async (data) => {
    try {
      if (!data || typeof data !== 'object') return;
      // data = { orderId, riderId, riderName, lat, lng }
      const { orderId, riderId, lat, lng } = data;

      const parsedLat = parseFloat(lat);
      const parsedLng = parseFloat(lng);

      // 1. Update the driver's lastLocation coordinates in database
      if (riderId && !isNaN(parsedLat) && !isNaN(parsedLng)) {
        try {
          const User = require('./src/models/User');
          await User.findByIdAndUpdate(riderId, {
            lastLocation: {
              type: 'Point',
              coordinates: [parsedLng, parsedLat] // GeoJSON is [lng, lat]
            }
          });
        } catch (err) {
          console.error(`[Socket] Failed to update driver ${riderId} location in DB:`, err);
        }
      }

      // 2. Record breadcrumb trail for active order
      if (orderId && orderId !== 'online' && !isNaN(parsedLat) && !isNaN(parsedLng)) {
        try {
          const Order = require('./src/models/Order');
          const order = await Order.findById(orderId).select('driverLocationTrail actualTravelledKm status');
          if (order && !['Delivered', 'Cancelled'].includes(order.status)) {
            const trail = order.driverLocationTrail || [];
            let shouldAppend = true;
            let addKm = 0;

            if (trail.length > 0) {
              const lastPt = trail[trail.length - 1];
              const distKm = calcHaversineKm(lastPt.lat, lastPt.lng, parsedLat, parsedLng);
              // Filter out jitter under 8 meters
              if (distKm < 0.008) {
                shouldAppend = false;
              } else {
                addKm = distKm;
              }
            }

            if (shouldAppend) {
              await Order.findByIdAndUpdate(orderId, {
                $push: {
                  driverLocationTrail: {
                    lat: parsedLat,
                    lng: parsedLng,
                    timestamp: new Date()
                  }
                },
                $inc: {
                  actualTravelledKm: addKm
                }
              });
            }
          }
        } catch (trailErr) {
          console.error(`[Socket] Failed to record driver trail for order ${orderId}:`, trailErr);
        }

        io.to(`order_${orderId}`).emit('rider_location_updated', data);
      }

      // 3. Broadcast globally to admins for live dispatch tracking
      io.emit('update_rider_location', data);
    } catch (socketErr) {
      console.error('[Socket] Error handling update_rider_location:', socketErr);
    }
  });

  // Admin remote session termination for riders
  socket.on('force_driver_logout', async (data) => {
    try {
      if (!data || !data.driverId) return;
      const driverId = data.driverId;
      console.log(`[Socket] 🚨 Force logout broadcast for driver: ${driverId}`);
      
      io.to(`driver_${driverId}`).emit('force_device_logout', {
        driverId,
        message: data.message || 'Super Admin terminated this mobile device session.'
      });

      io.emit('driver_status_update', {
        driverId,
        isOnline: false,
        action: 'FORCE_LOGOUT',
        forceLogout: true,
        message: 'Driver forced offline by Super Admin.'
      });

      const User = require('./src/models/User');
      await User.findByIdAndUpdate(driverId, {
        activeDeviceId: null,
        isSessionActive: false,
        isOnline: false,
        $inc: { sessionVersion: 1 }
      });
    } catch (err) {
      console.error('[Socket] Error handling force_driver_logout:', err);
    }
  });

  socket.on('disconnect', async (reason) => {
    console.log(`[Socket] Client disconnected: ${socket.id}, Reason: ${reason}`);

    if (socket.driverId) {
      const driverId = socket.driverId;
      setTimeout(async () => {
        try {
          const activeSockets = await io.in(`driver_${driverId}`).fetchSockets();
          if (activeSockets.length === 0) {
            console.log(`[Socket] Driver ${driverId} completely disconnected. Marking as Offline.`);
            const User = require('./src/models/User');
            const DriverDutySession = require('./src/models/DriverDutySession');
            
            const driver = await User.findById(driverId);
            if (driver && driver.isOnline) {
              const now = new Date();
              const updateData = { isOnline: false, isAvailable: false };

              if (driver.onlineSessionStart) {
                const sessionSeconds = Math.max(0, Math.floor((now.getTime() - new Date(driver.onlineSessionStart).getTime()) / 1000));
                updateData.onlineSecondsToday = (driver.onlineSecondsToday || 0) + sessionSeconds;
                updateData.onlineSessionStart = null;

                try {
                  const activeSession = await DriverDutySession.findOne({
                    driver: driverId,
                    offlineTime: null
                  }).sort({ onlineTime: -1 });

                  if (activeSession) {
                    activeSession.offlineTime = now;
                    activeSession.durationSeconds = sessionSeconds;
                    await activeSession.save();
                    console.log(`[Socket-Disconnect] 🔴 Ended duty session for driver ${driverId}`);
                  }
                } catch (sessErr) {
                  console.error(`[Socket-Disconnect] Duty session end error:`, sessErr);
                }
              }

              await User.findByIdAndUpdate(driverId, updateData);

              io.emit('driver_status_update', {
                driverId: driver._id,
                isOnline: false,
                message: `Driver ${driver.name} is now offline (app closed/disconnected).`
              });
            }
          }
        } catch (err) {
          console.error(`[Socket] Failed to mark driver ${driverId} offline:`, err);
        }
      }, 5000);
    }

    if (socket.vendorId) {
      const vendorId = socket.vendorId;
      // Wait 8 seconds grace period to verify if reconnecting (e.g. quick net switch / app pause)
      setTimeout(async () => {
        try {
          const activeSockets = await io.in(`vendor_${vendorId}`).fetchSockets();
          if (activeSockets.length === 0) {
            const Vendor = require('./src/models/Vendor');
            const vendor = await Vendor.findById(vendorId);
            
            if (vendor && vendor.isOpen) {
              console.log(`[Socket-Disconnect] Vendor "${vendor.storeName}" (${vendorId}) internet disconnected / 0 active sockets. Marking store as OFFLINE.`);
              const now = new Date();
              await Vendor.findByIdAndUpdate(vendorId, {
                isOpen: false,
                lastOfflineAt: now,
                $push: {
                  statusLogs: {
                    status: 'offline',
                    timestamp: now,
                    reason: 'Internet disconnected / App disconnected',
                  }
                }
              });

              io.emit('vendor_status_update', {
                vendorId: vendor._id.toString(),
                isOpen: false,
                lastOfflineAt: now.toISOString(),
                lastOnlineAt: vendor.lastOnlineAt ? vendor.lastOnlineAt.toISOString() : null,
                storeName: vendor.storeName
              });
              io.emit('vendor_status', {
                type: 'vendor_status',
                vendorId: vendor._id.toString(),
                isOpen: false,
                lastOfflineAt: now.toISOString(),
                lastOnlineAt: vendor.lastOnlineAt ? vendor.lastOnlineAt.toISOString() : null,
                storeName: vendor.storeName
              });
            }
          }
        } catch (err) {
          console.error(`[Socket] Failed to process disconnect check for vendor ${vendorId}:`, err);
        }
      }, 8000);
    }
  });
});

// ── ⏰ SHOP OPENING 10-MINUTE REMINDER WATCHER ──────────────────────────────
// Runs every 1 minute. Calculates current IST time and notifies vendors 10 mins before their opening time.
const checkShopOpeningReminders = async () => {
  try {
    const Vendor = require('./src/models/Vendor');
    const { sendShopOpeningReminderPush } = require('./src/utils/vendorPushNotifications');

    // Current IST time (UTC + 5:30)
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);
    
    // Add 10 minutes to find stores that open in exactly 10 minutes
    const reminderTarget = new Date(istNow.getTime() + 10 * 60 * 1000);
    
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const currentDay = days[istNow.getUTCDay()];
    
    const pad = (n) => String(n).padStart(2, '0');
    const targetHours = pad(reminderTarget.getUTCHours());
    const targetMins = pad(reminderTarget.getUTCMinutes());
    const targetTimeStr = `${targetHours}:${targetMins}`; // e.g. "10:00"
    const todayDateStr = istNow.toISOString().split('T')[0]; // "YYYY-MM-DD"

    const vendors = await Vendor.find({
      approvalStatus: 'approved',
      isOpen: false, // only remind stores that are currently closed
    });

    for (const vendor of vendors) {
      if (!vendor.operatingHours || vendor.operatingHours.length === 0) continue;
      const dayConfig = vendor.operatingHours.find((d) => d.day === currentDay);
      if (!dayConfig || !dayConfig.open || !dayConfig.from) continue;

      const openFrom = dayConfig.from.trim();
      if (openFrom === targetTimeStr) {
        const reminderKey = `${todayDateStr}_${openFrom}`;
        if (vendor.lastOpeningReminderKey === reminderKey) continue;

        console.log(`[Shop Opening Reminder] ⏰ Store "${vendor.storeName}" opens at ${openFrom} (in 10 mins). Sending push reminder!`);
        
        await sendShopOpeningReminderPush(vendor, openFrom);

        io.to(`vendor_${vendor._id}`).emit('shop_opening_reminder', {
          vendorId: vendor._id.toString(),
          storeName: vendor.storeName,
          openingTime: openFrom,
          message: `உங்கள் கடையின் தொடக்க நேரம் (${openFrom}) இன்னும் 10 நிமிடங்களில் உள்ளது. ஆப்பைத் திறந்து கடையை Online செய்யவும்!`,
        });

        vendor.lastOpeningReminderKey = reminderKey;
        await vendor.save();
      }
    }
  } catch (err) {
    console.error('[Shop Opening Reminder] Error running check:', err.message);
  }
};

setInterval(checkShopOpeningReminders, 60000);

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

    const tempDate = new Date(ist.getTime() + 10 * 60 * 1000);
    const futureHours = tempDate.getHours().toString().padStart(2, '0');
    const futureMinutes = tempDate.getMinutes().toString().padStart(2, '0');
    const timeIn10MinsStr = `${futureHours}:${futureMinutes}`;

    const Vendor = require('./src/models/Vendor');
    // Find all vendors with autoSchedulingEnabled
    const vendors = await Vendor.find({ autoSchedulingEnabled: true });

    for (const vendor of vendors) {
      if (!vendor.operatingHours || vendor.operatingHours.length === 0) continue;
      const dayConfig = vendor.operatingHours.find(d => d.day === currentDay);
      if (!dayConfig) continue;

      if (dayConfig.open) {
        // Warning alert: 10 minutes before opening
        if (dayConfig.from === timeIn10MinsStr && !vendor.isOpen) {
          console.log(`[Auto-Schedule] Warning 10m before opening store "${vendor.storeName}"`);
          const { sendCustomPushToVendor } = require('./src/utils/vendorPushNotifications');
          
          const title = "⏰ Auto-Open Reminder";
          const body = `உங்கள் கடை இன்னும் 10 நிமிடங்களில் (${dayConfig.from}) தானாகவே ஆன்லைனுக்கு வந்துவிடும். இன்று விடுமுறை எனில் செட்டிங்ஸில் மாற்றவும்!`;
          const bodyEn = `Your store will automatically go online in 10 minutes (${dayConfig.from}). Update timings if you are on leave.`;
          
          io.to(`vendor_${vendor._id}`).emit('new_order_alert', {
            type: 'SCHEDULED_OPEN_WARNING',
            title,
            message: body,
            messageEn: bodyEn
          });

          if (vendor.pushTokens && vendor.pushTokens.length > 0) {
            try {
              await sendCustomPushToVendor(
                vendor,
                title,
                bodyEn,
                {
                  type: 'SCHEDULED_OPEN_WARNING',
                  vendorId: vendor._id.toString(),
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                }
              );
            } catch (pushErr) {
              console.error(`[Auto-Schedule] Push warning failed:`, pushErr.message);
            }
          }
        }

        // Transition to Open/Online
        if (dayConfig.from === currentTimeStr && !vendor.isOpen) {
          // Only open if the vendor app is actually online/connected (at least 1 active socket)
          const activeSockets = await io.in(`vendor_${vendor._id}`).fetchSockets();
          if (activeSockets.length > 0) {
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
          } else {
            console.log(`[Auto-Schedule] Skipped auto-opening "${vendor.storeName}" at ${currentTimeStr} - No active socket connection`);
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

// ── SELF-HEALING VENDOR CLEANUP SCHEDULER ─────────────────────────────────────
// Runs every 5 minutes. Automatically closes any store that is marked open in database but has 0 active sockets.
const closeStuckVendors = async () => {
  try {
    const Vendor = require('./src/models/Vendor');
    const openVendors = await Vendor.find({ isOpen: true });
    
    for (const vendor of openVendors) {
      const activeSockets = await io.in(`vendor_${vendor._id}`).fetchSockets();
      if (activeSockets.length === 0) {
        console.log(`[Self-Healing] Vendor ${vendor.storeName} (${vendor._id}) is open with 0 sockets. Checking if uninstalled...`);
        const { sendSilentPingPush } = require('./src/utils/vendorPushNotifications');
        const validTokens = await sendSilentPingPush(vendor);
        
        if (validTokens === 0) {
          console.log(`[Self-Healing] Vendor ${vendor.storeName} (${vendor._id}) has 0 valid push tokens (uninstalled). Closing store.`);
          await Vendor.findByIdAndUpdate(vendor._id, { isOpen: false });
          io.emit('vendor_status_update', {
            vendorId: vendor._id,
            isOpen: false,
            storeName: vendor.storeName
          });
        } else {
          console.log(`[Self-Healing] Vendor ${vendor.storeName} (${vendor._id}) is still installed. Keeping store Online.`);
        }
      }
    }
  } catch (err) {
    console.error('[Self-Healing] Error closing stuck vendors:', err.message);
  }
};

// Run self-healing check after 30s delay on boot, then every 5 minutes
setTimeout(closeStuckVendors, 30000);
setInterval(closeStuckVendors, 5 * 60 * 1000);
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
