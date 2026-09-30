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
global.io = io;

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
              const payload = {
                vendorId: vendor._id.toString(),
                _id: vendor._id.toString(),
                isOpen: vendor.isOpen === true,
                isOnline: vendor.isOpen === true,
                storeName: vendor.storeName,
                lastOfflineAt: vendor.lastOfflineAt ? vendor.lastOfflineAt.toISOString() : null,
                lastOnlineAt: vendor.lastOnlineAt ? vendor.lastOnlineAt.toISOString() : null,
              };

              // Re-broadcast live online status to Admin and Customers without overwriting timestamps
              io.emit('vendor_status_update', payload);
              io.to('admin').emit('vendor_status_update', payload);
              io.emit('vendor_status', {
                type: 'vendor_status',
                ...payload,
              });
              io.to('admin').emit('vendor_status', {
                type: 'vendor_status',
                ...payload,
              });
            }
          } catch (err) {
            console.error(`[Socket] Status sync on connection failed for vendor ${vendorId}:`, err.message);
          }
        }, 100);
      }
    } catch (err) {
      console.error('[Socket] Error in join_room:', err);
    }
  });

  // ⚡ Live Heartbeat from Vendor App
  socket.on('vendor_heartbeat', async (data) => {
    try {
      const vId = (typeof data === 'object' ? (data.vendorId || data.id || data._id) : data) || socket.vendorId;
      if (!vId) return;
      const isOpen = typeof data === 'object' && data.isOpen !== undefined ? data.isOpen === true : true;
      const Vendor = require('./src/models/Vendor');
      const vendor = await Vendor.findById(vId);
      if (vendor) {
        const payload = {
          vendorId: vendor._id.toString(),
          _id: vendor._id.toString(),
          isOpen: vendor.isOpen,
          isOnline: vendor.isOpen,
          storeName: vendor.storeName,
          lastOfflineAt: vendor.lastOfflineAt ? vendor.lastOfflineAt.toISOString() : null,
          lastOnlineAt: vendor.lastOnlineAt ? vendor.lastOnlineAt.toISOString() : null,
        };
        io.emit('vendor_status_update', payload);
        io.to('admin').emit('vendor_status_update', payload);
      }
    } catch (err) {
      console.error('[Socket] Error in vendor_heartbeat:', err.message);
    }
  });

  // ⚡ Live instant status toggle via Socket from Vendor App
  socket.on('vendor_status_toggle', async (data) => {
    try {
      const vId = (typeof data === 'object' ? (data.vendorId || data.id || data._id) : data) || socket.vendorId;
      if (!vId) return;
      const isOpen = data.isOpen === true;
      const Vendor = require('./src/models/Vendor');
      const existingVendor = await Vendor.findById(vId);
      if (!existingVendor) return;

      // Idempotency: if already in the requested state, do not alter timestamps or push duplicate logs
      if (Boolean(existingVendor.isOpen) === Boolean(isOpen)) {
        const payload = {
          vendorId: existingVendor._id.toString(),
          _id: existingVendor._id.toString(),
          isOpen: existingVendor.isOpen,
          isOnline: existingVendor.isOpen,
          storeName: existingVendor.storeName,
          lastOfflineAt: existingVendor.lastOfflineAt ? existingVendor.lastOfflineAt.toISOString() : null,
          lastOnlineAt: existingVendor.lastOnlineAt ? existingVendor.lastOnlineAt.toISOString() : null,
        };
        io.emit('vendor_status_update', payload);
        io.to('admin').emit('vendor_status_update', payload);
        return;
      }

      const now = new Date();
      const updateData = { isOpen };
      let logEntry = null;

      if (isOpen) {
        // Transition to ONLINE: lock in lastOnlineAt to now
        updateData.lastOnlineAt = now;
        let offlineDurationMinutes = 0;
        if (existingVendor.lastOfflineAt) {
          offlineDurationMinutes = Math.max(0, Math.round((now - new Date(existingVendor.lastOfflineAt)) / (1000 * 60)));
        }
        logEntry = {
          status: 'online',
          timestamp: now,
          durationMinutes: offlineDurationMinutes,
          reason: (typeof data === 'object' && data.reason) || 'Vendor App Toggle (Online)',
        };
      } else {
        // Transition to OFFLINE: lock in lastOfflineAt to now, calculate online duration
        updateData.lastOfflineAt = now;
        let onlineDurationMinutes = 0;
        if (existingVendor.lastOnlineAt) {
          onlineDurationMinutes = Math.max(0, Math.round((now - new Date(existingVendor.lastOnlineAt)) / (1000 * 60)));
        }
        logEntry = {
          status: 'offline',
          timestamp: now,
          durationMinutes: onlineDurationMinutes,
          reason: (typeof data === 'object' && data.reason) || 'Vendor App Toggle (Offline)',
        };
      }

      const updateQuery = { $set: updateData };
      if (logEntry) {
        updateQuery.$push = {
          statusLogs: {
            $each: [logEntry],
            $slice: -100,
          },
        };
      }

      const vendor = await Vendor.findByIdAndUpdate(vId, updateQuery, { new: true });
      if (vendor) {
        const payload = {
          vendorId: vendor._id.toString(),
          _id: vendor._id.toString(),
          isOpen: vendor.isOpen,
          isOnline: vendor.isOpen,
          storeName: vendor.storeName,
          lastOfflineAt: vendor.lastOfflineAt ? vendor.lastOfflineAt.toISOString() : null,
          lastOnlineAt: vendor.lastOnlineAt ? vendor.lastOnlineAt.toISOString() : null,
        };
        io.emit('vendor_status_update', payload);
        io.to('admin').emit('vendor_status_update', payload);
        io.emit('vendor_status', { type: 'vendor_status', ...payload });
        io.to('admin').emit('vendor_status', { type: 'vendor_status', ...payload });
      }
    } catch (err) {
      console.error('[Socket] Error in vendor_status_toggle:', err.message);
    }
  });

  socket.on('join_driver_room', async (data) => {
    try {
      const rawId = (typeof data === 'object' ? (data.driverId || data.id) : data) || '';
      const dId = String(rawId).replace(/^driver_/, '').trim();
      if (dId) {
        socket.join(`driver_${dId}`);
        socket.join(dId);
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
      console.log(`[Socket] Driver socket closed for driver: ${socket.driverId} (Driver remains Online until manual offline action).`);
    }

    if (socket.vendorId) {
      console.log(`[Socket-Disconnect] Vendor socket closed for vendor: ${socket.vendorId}`);
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

// Set to deduplicate 10-minute opening reminder push notifications per vendor per day
const notifiedOpenReminders = new Set();

// ── OPERATING HOURS AUTO-SCHEDULER ───────────────────────────────────────────
// Runs every 1 minute. Automatically opens and closes stores based on their operating hours,
// records online/offline statusLogs for admin audit, and sends 10-min pre-opening alerts.
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
    const curTotalMin = ist.getHours() * 60 + ist.getMinutes();
    const todayDateStr = ist.toISOString().split('T')[0];

    const Vendor = require('./src/models/Vendor');
    // Find all approved vendors with autoSchedulingEnabled
    const vendors = await Vendor.find({ autoSchedulingEnabled: true, approvalStatus: 'approved' });

    for (const vendor of vendors) {
      if (!vendor.operatingHours || vendor.operatingHours.length === 0) continue;
      const dayConfig = vendor.operatingHours.find(d => d.day === currentDay);
      if (!dayConfig) continue;

      if (dayConfig.open) {
        const [fromH, fromM] = (dayConfig.from || '09:00').split(':').map(Number);
        const [toH, toM] = (dayConfig.to || '21:00').split(':').map(Number);
        const fromTotalMin = fromH * 60 + fromM;
        const toTotalMin = toH * 60 + toM;
        const isWithinHours = curTotalMin >= fromTotalMin && curTotalMin < toTotalMin;

        // ⏰ WARNING ALERT: Exactly 10 minutes before opening time
        const diffMinutes = fromTotalMin - curTotalMin;
        const reminderKey = `${vendor._id.toString()}_${todayDateStr}_${dayConfig.from}`;

        if ((diffMinutes === 10 || diffMinutes === 9) && !vendor.isOpen && !notifiedOpenReminders.has(reminderKey)) {
          notifiedOpenReminders.add(reminderKey);
          if (notifiedOpenReminders.size > 2000) notifiedOpenReminders.clear();

          console.log(`[Auto-Schedule] ⏰ 10-Minute Pre-Opening Warning for store "${vendor.storeName}" (${dayConfig.from})`);
          const { sendShopOpeningReminderPush } = require('./src/utils/vendorPushNotifications');
          
          const title = "⏰ இன்னும் 10 நிமிடங்களில் கடை திறக்கும் நேரம்!";
          const body = `வணக்கம் ${vendor.storeName || ''}! உங்கள் கடை ${dayConfig.from} மணிக்கு தானாகவே Online-க்கு வந்துவிடும். தயாராக இருக்கவும்!`;
          const bodyEn = `Your store will automatically go online in 10 minutes (${dayConfig.from}). Please be ready!`;
          
          io.to(`vendor_${vendor._id}`).emit('new_order_alert', {
            type: 'SCHEDULED_OPEN_WARNING',
            title,
            message: body,
            messageEn: bodyEn,
            alertSound: 'new_order_alert',
            openingTime: dayConfig.from,
          });

          io.to(`vendor_${vendor._id}`).emit('shop_opening_reminder', {
            vendorId: vendor._id.toString(),
            storeName: vendor.storeName,
            openingTime: dayConfig.from,
            message: body,
          });

          if (vendor.pushTokens && vendor.pushTokens.length > 0) {
            try {
              await sendShopOpeningReminderPush(vendor, dayConfig.from);
            } catch (pushErr) {
              console.error(`[Auto-Schedule] Push warning failed:`, pushErr.message);
            }
          }
        }

        // Transition to Open/Online
        if (isWithinHours && !vendor.isOpen) {
          // Check if vendor is active (has connected socket or push notification tokens)
          const activeSockets = await io.in(`vendor_${vendor._id}`).fetchSockets();
          const hasPushTokens = vendor.pushTokens && vendor.pushTokens.length > 0;
          if (activeSockets.length === 0 && !hasPushTokens) {
            console.log(`[Auto-Schedule] Skipped opening "${vendor.storeName}" - 0 sockets and 0 push tokens (uninstalled/inactive). Disabling autoScheduling.`);
            let onlineDurationMinutes = 0;
            if (vendor.lastOnlineAt) {
              onlineDurationMinutes = Math.max(0, Math.round((now - new Date(vendor.lastOnlineAt)) / (1000 * 60)));
            }
            await Vendor.findByIdAndUpdate(vendor._id, { 
              autoSchedulingEnabled: false, 
              isOpen: false, 
              lastOfflineAt: vendor.lastOfflineAt || now,
              $push: {
                statusLogs: {
                  $each: [{
                    status: 'offline',
                    timestamp: now,
                    durationMinutes: onlineDurationMinutes,
                    reason: 'Disabled (0 Sockets & Tokens)',
                  }],
                  $slice: -100,
                },
              },
            });
            continue;
          }

          const hasActiveSubscription = vendor.isSubscribed && vendor.subscriptionExpiry && vendor.subscriptionExpiry > now;
          const hasActiveTrial = vendor.trialExpiry && vendor.trialExpiry > now;
          const isManuallyUnlocked = vendor.isManuallyUnlocked === true;
          const isAllowed = hasActiveSubscription || hasActiveTrial || isManuallyUnlocked || (!vendor.isLocked);

          if (isAllowed) {
            let offlineDurationMinutes = 0;
            if (vendor.lastOfflineAt) {
              offlineDurationMinutes = Math.max(0, Math.round((now - new Date(vendor.lastOfflineAt)) / (1000 * 60)));
            }
            const logEntry = {
              status: 'online',
              timestamp: now,
              durationMinutes: offlineDurationMinutes,
              reason: 'Auto-Scheduled Opening',
            };

            await Vendor.findByIdAndUpdate(vendor._id, {
              isOpen: true,
              lastOnlineAt: now,
              $push: {
                statusLogs: {
                  $each: [logEntry],
                  $slice: -100,
                },
              },
            });

            console.log(`[Auto-Schedule] 🟢 Auto-Opened store "${vendor.storeName}" at ${currentTimeStr} (Scheduled: ${dayConfig.from} - ${dayConfig.to})`);
            const statusPayload = {
              vendorId: vendor._id,
              isOpen: true,
              isOnline: true,
              storeName: vendor.storeName,
              lastOnlineAt: now.toISOString(),
              lastOfflineAt: vendor.lastOfflineAt ? vendor.lastOfflineAt.toISOString() : null,
            };
            io.emit('vendor_status_update', statusPayload);
            io.to('admin').emit('vendor_status_update', statusPayload);

            if (vendor.pushTokens && vendor.pushTokens.length > 0) {
              try {
                const { sendCustomPushToVendor } = require('./src/utils/vendorPushNotifications');
                await sendCustomPushToVendor(
                  vendor,
                  '🟢 Store Auto-Opened (Online)',
                  `Your store "${vendor.storeName}" is now online as scheduled (${dayConfig.from} to ${dayConfig.to}).`,
                  {
                    type: 'STORE_STATUS',
                    isOpen: 'true',
                    vendorId: vendor._id.toString(),
                  }
                );
              } catch (pushErr) {
                console.error(`[Auto-Schedule] Push notification failed:`, pushErr.message);
              }
            }
          } else {
            console.log(`[Auto-Schedule] Skipped opening "${vendor.storeName}" at ${currentTimeStr} - Subscription or Unlock Required`);
          }
        }

        // Transition to Closed/Offline
        if (!isWithinHours && vendor.isOpen) {
          let onlineDurationMinutes = 0;
          if (vendor.lastOnlineAt) {
            onlineDurationMinutes = Math.max(0, Math.round((now - new Date(vendor.lastOnlineAt)) / (1000 * 60)));
          }
          const logEntry = {
            status: 'offline',
            timestamp: now,
            durationMinutes: onlineDurationMinutes,
            reason: 'Auto-Scheduled Closing',
          };

          await Vendor.findByIdAndUpdate(vendor._id, {
            isOpen: false,
            lastOfflineAt: now,
            $push: {
              statusLogs: {
                $each: [logEntry],
                $slice: -100,
              },
            },
          });

          console.log(`[Auto-Schedule] 🔴 Auto-Closed store "${vendor.storeName}" at ${currentTimeStr} (Outside schedule: ${dayConfig.from} - ${dayConfig.to})`);
          const statusPayload = {
            vendorId: vendor._id,
            isOpen: false,
            isOnline: false,
            storeName: vendor.storeName,
            lastOnlineAt: vendor.lastOnlineAt ? vendor.lastOnlineAt.toISOString() : null,
            lastOfflineAt: now.toISOString(),
          };
          io.emit('vendor_status_update', statusPayload);
          io.to('admin').emit('vendor_status_update', statusPayload);

          if (vendor.pushTokens && vendor.pushTokens.length > 0) {
            try {
              const { sendCustomPushToVendor } = require('./src/utils/vendorPushNotifications');
              await sendCustomPushToVendor(
                vendor,
                '🔴 Store Auto-Closed (Offline)',
                `Your store "${vendor.storeName}" is now closed for the day (${dayConfig.to}).`,
                {
                  type: 'STORE_STATUS',
                  isOpen: 'false',
                  vendorId: vendor._id.toString(),
                }
              );
            } catch (pushErr) {
              console.error(`[Auto-Schedule] Push notification failed:`, pushErr.message);
            }
          }
        }
      } else {
        // Configured closed on this day
        if (vendor.isOpen) {
          let onlineDurationMinutes = 0;
          if (vendor.lastOnlineAt) {
            onlineDurationMinutes = Math.max(0, Math.round((now - new Date(vendor.lastOnlineAt)) / (1000 * 60)));
          }
          const logEntry = {
            status: 'offline',
            timestamp: now,
            durationMinutes: onlineDurationMinutes,
            reason: `Auto-Scheduled (Closed on ${currentDay})`,
          };

          await Vendor.findByIdAndUpdate(vendor._id, {
            isOpen: false,
            lastOfflineAt: now,
            $push: {
              statusLogs: {
                $each: [logEntry],
                $slice: -100,
              },
            },
          });

          console.log(`[Auto-Schedule] Closed store "${vendor.storeName}" (Configured closed on ${currentDay})`);
          const statusPayload = {
            vendorId: vendor._id,
            isOpen: false,
            isOnline: false,
            storeName: vendor.storeName,
            lastOnlineAt: vendor.lastOnlineAt ? vendor.lastOnlineAt.toISOString() : null,
            lastOfflineAt: now.toISOString(),
          };
          io.emit('vendor_status_update', statusPayload);
          io.to('admin').emit('vendor_status_update', statusPayload);
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
          let onlineDurationMinutes = 0;
          if (vendor.lastOnlineAt) {
            onlineDurationMinutes = Math.max(0, Math.round((new Date() - new Date(vendor.lastOnlineAt)) / (1000 * 60)));
          }
          const logEntry = {
            status: 'offline',
            timestamp: new Date(),
            durationMinutes: onlineDurationMinutes,
            reason: 'Self-Healing (Inactive/Uninstalled)',
          };

          await Vendor.findByIdAndUpdate(vendor._id, { 
            isOpen: false, 
            autoSchedulingEnabled: false, 
            lastOfflineAt: vendor.lastOfflineAt || new Date(),
            $push: {
              statusLogs: {
                $each: [logEntry],
                $slice: -100,
              },
            },
          });

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

// ─────────────────────────────────────────────────────────────────────────────
// TELEMETRY & SECURITY AUDIT HEARTBEAT DAEMON
// ─────────────────────────────────────────────────────────────────────────────
const { logEvent } = require('./src/utils/auditLogger');
const runTelemetryHeartbeat = async () => {
  try {
    const mem = process.memoryUsage();
    const memMb = (mem.heapUsed / 1024 / 1024).toFixed(1);
    const uptimeHours = (process.uptime() / 3600).toFixed(1);
    let socketCount = 0;
    if (global.io) {
      const sockets = await global.io.fetchSockets();
      socketCount = sockets.length;
    }
    await logEvent({
      action: 'SYSTEM_HEARTBEAT',
      category: 'SYSTEM',
      severity: 'INFO',
      actor: { name: 'System Daemon', email: 'daemon@namba.internal', role: 'KERNEL' },
      targetEntity: { entityType: 'Cluster', name: 'Namba Production Cluster' },
      detail: `Cluster Health Telemetry: Memory ${memMb}MB, Uptime ${uptimeHours}h, Active Real-time Sockets: ${socketCount}`,
    });
  } catch (err) {
    // Non-fatal
  }
};
setTimeout(runTelemetryHeartbeat, 45000);
setInterval(runTelemetryHeartbeat, 30 * 60 * 1000);

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
