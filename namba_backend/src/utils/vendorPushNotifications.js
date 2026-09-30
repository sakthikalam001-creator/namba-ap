const path = require('path');
const VENDOR_ORDER_ALERT_CHANNEL_ID = 'namba_vendor_call_alerts_v22';
const VENDOR_ORDER_ALERT_SOUND = 'new_order_alert';
let firebaseAdmin = null;
let firebaseInitialized = false;

function loadServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    return require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
  }

  // Auto-detect: look for firebase-service-account.json in backend root
  const defaultPath = path.join(__dirname, '../../firebase-service-account.json');
  const fs = require('fs');
  if (fs.existsSync(defaultPath)) {
    console.log('[Push] Auto-detected firebase-service-account.json');
    return require(defaultPath);
  }

  return null;
}

function getFirebaseAdmin() {
  if (firebaseInitialized) return firebaseAdmin;
  firebaseInitialized = true;

  try {
    const serviceAccount = loadServiceAccount();
    if (!serviceAccount) {
      console.warn('[Push] Firebase service account not configured. Vendor push disabled.');
      return null;
    }

    // Lazy require keeps the backend bootable until firebase-admin is installed/configured.
    const admin = require('firebase-admin');
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }

    firebaseAdmin = admin;
    return firebaseAdmin;
  } catch (err) {
    console.error('[Push] Firebase initialization failed:', err.message);
    return null;
  }
}

function uniqueTokens(vendor) {
  return [...new Set((vendor.pushTokens || []).map((entry) => entry.token).filter(Boolean))];
}

/**
 * Returns order-type specific title & body for the push notification.
 * @param {string} orderType  'Cart' | 'Text' | 'Photo'
 * @param {string} displayId  Short display ID
 * @param {string} customerName
 * @param {number} amount
 */
function buildOrderPushContent(orderType, displayId, customerName, amount, isOfficeDelivery = false, extra = {}) {
  const officeTag = isOfficeDelivery ? '🏢 [OFFICE DELIVERY] ' : '';
  const officeText = isOfficeDelivery ? '🏢 Office/Workplace Delivery! ' : '';

  switch (orderType) {
    case 'Text': {
      const listPreview = extra.preview || extra.textContent ? `\n📝 "${extra.preview || extra.textContent}"` : '';
      return {
        title: `🚨 ${officeTag}NEW LIST ORDER #${displayId}`,
        body: `${officeText}${customerName} sent a shopping list order.${listPreview}\nTap to review and send quote!`,
      };
    }
    case 'Photo':
      return {
        title: `🚨 ${officeTag}NEW PHOTO ORDER #${displayId}`,
        body: `${officeText}${customerName} uploaded item photos. Tap to review and send quote!`,
      };
    default: // 'Cart' or anything else
      return {
        title: `🚨 ${officeTag}NEW ORDER RECEIVED #${displayId}`,
        body: `${officeText}${customerName} placed a new order. Tap to review and accept!`,
      };
  }
}

async function sendNewOrderPushToVendor(vendor, order, extra = {}) {
  const admin = getFirebaseAdmin();
  const tokens = uniqueTokens(vendor);
  if (!admin) return;
  if (tokens.length === 0) {
    console.warn(`[Push] No FCM tokens saved for vendor ${vendor._id}. Skipping new order push.`);
    return;
  }

  const orderId = order._id.toString();
  const displayId = order.displayId || orderId.slice(-6).toUpperCase();
  const amount = Number(order.totalAmount || extra.amount || 0);
  const orderType = order.orderType || extra.orderType || 'Cart';
  const customerName = extra.customerName || 'Customer';
  const isOfficeDelivery = Boolean(order.isOfficeDelivery || extra.isOfficeDelivery);
  const textContent = extra.textContent || order.textContent || '';
  const preview = extra.preview || (textContent ? (textContent.length > 80 ? textContent.substring(0, 80) + '...' : textContent) : 'Shopping List');
  const alertSound = extra.alertSound || vendor.orderAlertSound || 'new_order_alert';
  const channelId = `namba_vendor_call_alerts_v22_${alertSound}`;

  const { title, body } = buildOrderPushContent(orderType, displayId, customerName, amount, isOfficeDelivery, { textContent, preview });

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      type: 'new_order',
      orderId,
      displayId: displayId.toString(),
      amount: amount.toString(),
      customerName,
      orderType,
      textContent,
      preview,
      isOfficeDelivery: isOfficeDelivery ? 'true' : 'false',
      alertSound,
      notifTitle: title,
      notifBody: body,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      ttl: 0,
      notification: {
        channelId: channelId,
        sound: alertSound,
        defaultSound: false,
        priority: 'max',
        visibility: 'public',
        tag: `order_${orderId}`,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: `${alertSound}.caf`,
          badge: 1,
          alert: {
            title,
            body,
          },
        },
      },
      headers: {
        'apns-priority': '10',
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Push] 🚨 Sent new order push to vendor ${vendor._id}: ${response.successCount}/${tokens.length} delivered successfully.`);

    if (response.failureCount > 0) {
      const failedTokens = response.responses
        .map((item, index) => ({ item, token: tokens[index] }))
        .filter(({ item }) => !item.success)
        .map(({ token }) => token);

      if (failedTokens.length > 0) {
        vendor.pushTokens = (vendor.pushTokens || []).filter((entry) => !failedTokens.includes(entry.token));
        await vendor.save();
        console.log(`[Push] Removed ${failedTokens.length} stale push token(s) for vendor ${vendor._id}`);
      }
    }
  } catch (err) {
    console.error('[Push] sendEachForMulticast error:', err.message);
  }
}

async function sendCustomPushToVendor(vendor, title, body, dataPayload = {}) {
  const admin = getFirebaseAdmin();
  const tokens = uniqueTokens(vendor);
  if (!admin) return;
  if (tokens.length === 0) return;

  const soundName = dataPayload.alertSound || 'new_order_alert';
  const channelId = `namba_vendor_call_alerts_v22_${soundName}`;

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: dataPayload,
    android: {
      priority: 'high',
      notification: {
        channelId: channelId,
        sound: soundName,
        defaultSound: false,
        priority: 'max',
        visibility: 'public',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          sound: `${soundName}.caf`,
          alert: {
            title,
            body,
          },
          badge: 1,
        },
      },
      headers: {
        'apns-priority': '10',
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Push] Sent ${response.successCount}/${tokens.length} custom pushes to vendor ${vendor._id}`);
  } catch (err) {
    console.error('[Push] Custom push error:', err.message);
  }
}

async function sendQuotePushToCustomer(customerUser, order, extra = {}) {
  const admin = getFirebaseAdmin();
  if (!admin || !customerUser) return;

  const rawTokens = [];
  if (Array.isArray(customerUser.pushTokens)) {
    customerUser.pushTokens.forEach(entry => {
      if (typeof entry === 'string') rawTokens.push(entry);
      else if (entry && entry.token) rawTokens.push(entry.token);
    });
  }
  if (customerUser.fcmToken) {
    rawTokens.push(customerUser.fcmToken);
  }

  const tokens = [...new Set(rawTokens.filter(Boolean))];

  if (tokens.length === 0) {
    console.warn(`[Push] ⚠️ No FCM tokens saved for customer ${customerUser._id}. Skipping quote push.`);
    return;
  }

  const displayId = order.displayId || order._id.toString().slice(-6).toUpperCase();
  const subTotal = Math.round(order.subTotal || 0);
  const discount = Math.round(order.discount || 0);
  const deliveryCharge = Math.round(order.deliveryCharge || 0);
  const platformFee = Math.round(order.customerPlatformFee || 0);
  const finalSub = Math.max(0, subTotal - discount);
  const totalAmount = Math.round(order.totalAmount || (finalSub + deliveryCharge + platformFee));
  const alertSound = extra.alertSound || 'new_order_alert';
  const channelId = `namba_customer_quote_channel_v6_${alertSound}`;

  const title = `🧾 Bill Quote Ready • #${displayId} (₹${totalAmount})`;
  const discPart = discount > 0 ? ` - ₹${discount} Off` : '';
  const pFeePart = platformFee > 0 ? ` + Fee ₹${platformFee}` : '';
  const body = `Shop Bill: ₹${subTotal}${discPart} + Delivery: ₹${deliveryCharge}${pFeePart} = Total: ₹${totalAmount}. Tap to view & pay now!`;

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      type: 'price_quote',
      orderId: order._id.toString(),
      displayId: displayId,
      subTotal: subTotal.toString(),
      discount: discount.toString(),
      deliveryCharge: deliveryCharge.toString(),
      customerPlatformFee: platformFee.toString(),
      totalAmount: totalAmount.toString(),
      alertSound: alertSound,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        channelId: channelId,
        sound: alertSound,
        defaultSound: false,
        priority: 'max',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          sound: `${alertSound}.wav`,
          badge: 1
        }
      }
    }
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Push] 💰 Sent price quote push to customer ${customerUser._id}: ${response.successCount}/${tokens.length} delivered successfully.`);
  } catch (err) {
    console.error('[Push] Quote push to customer error:', err.message);
  }
}

async function sendNewOrderPushToDriver(driverUser, order, extra = {}) {
  const admin = getFirebaseAdmin();
  if (!admin || !driverUser) return;

  const rawTokens = [];
  if (Array.isArray(driverUser.pushTokens)) {
    driverUser.pushTokens.forEach(entry => {
      if (typeof entry === 'string') rawTokens.push(entry);
      else if (entry && entry.token) rawTokens.push(entry.token);
    });
  }
  if (driverUser.fcmToken) {
    rawTokens.push(driverUser.fcmToken);
  }

  const tokens = [...new Set(rawTokens.filter(Boolean))];

  if (tokens.length === 0) {
    console.warn(`[Push] ⚠️ No FCM tokens saved for driver ${driverUser._id}. Skipping new order assignment push.`);
    return;
  }

  const orderId = order._id.toString();
  const displayId = order.displayId || orderId.slice(-6).toUpperCase();
  const vendorName = extra.vendorName || order.customStoreName || 'Any Store Pickup';
  const vendorToCustomerKm = Number(order.distanceKm || extra.distanceKm || 0);

  // 🟢 CALCULATE 2-LEG TOTAL TRIP DISTANCE (Driver -> Vendor + Vendor -> Customer)
  let driverToVendorKm = 0;
  if (driverUser.location && Array.isArray(driverUser.location.coordinates) && driverUser.location.coordinates.length >= 2) {
    const dLng = driverUser.location.coordinates[0];
    const dLat = driverUser.location.coordinates[1];
    if (order.vendor && order.vendor.location && Array.isArray(order.vendor.location.coordinates) && order.vendor.location.coordinates.length >= 2) {
      const vLng = order.vendor.location.coordinates[0];
      const vLat = order.vendor.location.coordinates[1];
      driverToVendorKm = calculateDistance(dLat, dLng, vLat, vLng);
    }
  }

  const totalTripKm = parseFloat((driverToVendorKm + vendorToCustomerKm).toFixed(2));
  let driverEarnings = Number(order.driverEarnings || extra.driverEarnings || 0);
  if (driverEarnings <= 0) {
    try {
      const Settings = require('../models/Settings');
      const settings = await Settings.findOne() || {};
      const baseRate = Number(settings.driverBaseRatePerKm) || 7.0;
      const threshold = Number(settings.driverLongDistanceThresholdKm) || 50.0;
      const bonusRate = Number(settings.driverLongDistanceBonusPerKm) || 2.0;
      const minEarnings = Number(settings.driverMinEarningsPerOrder) || 10.0;
      const includePickup = settings.includeRiderPickupDistance === true;
      const payableKm = includePickup ? totalTripKm : parseFloat(vendorToCustomerKm.toFixed(2));

      if (payableKm <= threshold) {
        driverEarnings = payableKm * baseRate;
      } else {
        driverEarnings = (threshold * baseRate) + ((payableKm - threshold) * (baseRate + bonusRate));
      }
      driverEarnings = Math.max(minEarnings, Math.round(driverEarnings));
    } catch (_) {
      driverEarnings = totalTripKm > 0 ? Math.max(10, Math.round(totalTripKm * 7.0)) : 10;
    }
  }

  const earningsText = `Pay: ₹${Math.round(driverEarnings)}`;
  const kmText = totalTripKm > 0 ? ` (${totalTripKm.toFixed(1)} KM)` : '';

  const isOfficeDelivery = Boolean(order.isOfficeDelivery || extra.isOfficeDelivery);
  const officeTag = isOfficeDelivery ? '🏢 [OFFICE DELIVERY] ' : '';
  const officeBodyPrefix = isOfficeDelivery ? '🏢 Office / Workplace Delivery! ' : '';

  const title = `🚨 ${officeTag}NEW DELIVERY REQUEST #${displayId} — ${earningsText}${kmText}`;
  const body = `${officeBodyPrefix}Pickup: ${vendorName} — Payout: ${earningsText}${kmText}. Tap to review & accept delivery!`;

  const alertSound = extra.alertSound || 'new_order_alert';
  const channelId = `namba_delivery_order_alerts_v22_${alertSound}`;

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      type: 'new_assignment',
      orderId: orderId,
      displayId: displayId,
      vendorName: vendorName,
      amount: driverEarnings.toString(),
      orderTotal: (order.totalAmount || 0).toString(),
      distanceKm: totalTripKm.toString(),
      driverEarnings: driverEarnings.toString(),
      paymentMethod: order.paymentMethod || 'COD',
      isOfficeDelivery: isOfficeDelivery ? 'true' : 'false',
      deliveryAddressLabel: order.deliveryAddressLabel || extra.deliveryAddressLabel || (isOfficeDelivery ? 'Office' : 'Home'),
      alertSound: alertSound,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      ttl: 0,
      notification: {
        channelId: channelId,
        sound: alertSound,
        defaultSound: false,
        priority: 'max',
        visibility: 'public',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          sound: `${alertSound}.wav`,
          badge: 1
        }
      }
    }
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Push] 🚨 Sent new order assignment push to driver ${driverUser._id}: ${response.successCount}/${tokens.length} delivered successfully.`);
  } catch (err) {
    console.error('[Push] Driver assignment push error:', err.message);
  }
}

async function sendSilentPingPush(vendor) {
  const admin = getFirebaseAdmin();
  const tokens = uniqueTokens(vendor);
  if (!admin || tokens.length === 0) return 0;

  const message = {
    tokens,
    data: {
      type: 'ping',
    },
    android: {
      priority: 'normal',
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    let validTokensCount = tokens.length;
    
    if (response.failureCount > 0) {
      const failedTokens = response.responses
        .map((item, index) => ({ item, token: tokens[index] }))
        .filter(({ item }) => !item.success)
        .map(({ token }) => token);

      if (failedTokens.length > 0) {
        vendor.pushTokens = (vendor.pushTokens || []).filter((entry) => !failedTokens.includes(entry.token));
        await vendor.save();
        validTokensCount -= failedTokens.length;
        console.log(`[Push-Ping] Removed ${failedTokens.length} stale push tokens for vendor ${vendor._id}`);
      }
    }
    return validTokensCount;
  } catch (err) {
    console.error('[Push-Ping] Error sending silent ping:', err.message);
    return tokens.length; // Fallback
  }
}

async function sendShopOpeningReminderPush(vendor, openingTime) {
  const admin = getFirebaseAdmin();
  const tokens = uniqueTokens(vendor);
  if (!admin || tokens.length === 0) return;

  const title = `⏰ இன்னும் 10 நிமிடங்களில் கடை திறக்கும் நேரம்!`;
  const body = `வணக்கம் ${vendor.storeName || ''}! உங்கள் கடை ${openingTime} மணிக்கு தானாகவே Online-க்கு வந்துவிடும். தயாராக இருக்கவும்!`;
  const soundName = 'new_order_alert';
  const channelId = `namba_vendor_call_alerts_v22_${soundName}`;

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      type: 'shop_opening_reminder',
      vendorId: vendor._id.toString(),
      openingTime: openingTime.toString(),
      alertSound: soundName,
      notifTitle: title,
      notifBody: body,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: channelId,
        sound: soundName,
        priority: 'max',
        defaultSound: false,
        visibility: 'public',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: `${soundName}.caf`,
          alert: {
            title,
            body,
          },
          badge: 1,
        },
      },
      headers: {
        'apns-priority': '10',
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Push] ⏰ Sent opening reminder push with sound to vendor ${vendor.storeName} (${vendor._id}): ${response.successCount}/${tokens.length} delivered.`);
  } catch (err) {
    console.error(`[Push] Error sending opening reminder to vendor ${vendor._id}:`, err.message);
  }
}

async function sendPayoutPushToDriver(driverUser, { amount, settledCount = 1, transactionRef = '', alertSound = 'new_order_alert' }) {
  const admin = getFirebaseAdmin();
  if (!admin || !driverUser) return;

  const rawTokens = [];
  if (Array.isArray(driverUser.pushTokens)) {
    driverUser.pushTokens.forEach(entry => {
      if (typeof entry === 'string') rawTokens.push(entry);
      else if (entry && entry.token) rawTokens.push(entry.token);
    });
  }
  if (driverUser.fcmToken) {
    rawTokens.push(driverUser.fcmToken);
  }

  const tokens = [...new Set(rawTokens.filter(Boolean))];
  if (tokens.length === 0) {
    console.warn(`[Push] No FCM tokens saved for driver ${driverUser._id}. Skipping payout push.`);
    return;
  }

  const roundedAmount = Math.round(Number(amount) || 0);
  const title = `💰 Payout Settled & Credited! • ₹${roundedAmount}`;
  const body = `Admin has transferred ₹${roundedAmount} for ${settledCount} order(s) to your registered UPI / Bank account.${transactionRef ? ` Ref: ${transactionRef}` : ''}`;
  const channelId = `namba_driver_payout_alerts_${alertSound}`;

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      type: 'payout_settled',
      amount: roundedAmount.toString(),
      settledCount: settledCount.toString(),
      transactionRef: transactionRef.toString(),
      alertSound: alertSound,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      ttl: 0,
      notification: {
        channelId: channelId,
        sound: alertSound,
        defaultSound: false,
        priority: 'max',
        visibility: 'public',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          sound: `${alertSound}.wav`,
          badge: 1
        }
      }
    }
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Push] 💰 Sent payout settlement push to driver ${driverUser._id}: ${response.successCount}/${tokens.length} delivered.`);
  } catch (err) {
    console.error('[Push] Driver payout push error:', err.message);
  }
}

async function sendPayoutPushToVendor(vendor, { amount, settledCount = 1, transactionRef = '', alertSound = 'new_order_alert' }) {
  const admin = getFirebaseAdmin();
  const tokens = uniqueTokens(vendor);
  if (!admin || tokens.length === 0) {
    console.warn(`[Push] No FCM tokens saved for vendor ${vendor._id}. Skipping payout push.`);
    return;
  }

  const roundedAmount = Math.round(Number(amount) || 0);
  const title = `💰 Merchant Payout Settled • ₹${roundedAmount}`;
  const body = `Super Admin has transferred ₹${roundedAmount} for ${settledCount} order(s) to your registered bank / UPI account.${transactionRef ? ` Ref: ${transactionRef}` : ''}`;
  const channelId = `namba_vendor_payout_alerts_${alertSound}`;

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: {
      type: 'payout_settled',
      amount: roundedAmount.toString(),
      settledCount: settledCount.toString(),
      transactionRef: transactionRef.toString(),
      alertSound: alertSound,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      ttl: 0,
      notification: {
        channelId: channelId,
        sound: alertSound,
        defaultSound: false,
        priority: 'max',
        visibility: 'public',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          sound: `${alertSound}.caf`,
          badge: 1
        }
      }
    }
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Push] 💰 Sent payout settlement push to vendor ${vendor._id}: ${response.successCount}/${tokens.length} delivered.`);
  } catch (err) {
    console.error('[Push] Vendor payout push error:', err.message);
  }
}

module.exports = {
  sendNewOrderPushToVendor,
  sendCustomPushToVendor,
  sendQuotePushToCustomer,
  sendNewOrderPushToDriver,
  sendSilentPingPush,
  sendShopOpeningReminderPush,
  sendPayoutPushToDriver,
  sendPayoutPushToVendor,
};
