const path = require('path');
const VENDOR_ORDER_ALERT_CHANNEL_ID = 'namba_vendor_call_alerts_v19';
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
function buildOrderPushContent(orderType, displayId, customerName, amount) {
  switch (orderType) {
    case 'Text':
      return {
        title: `🚨 NEW LIST ORDER #${displayId}`,
        body: `${customerName} sent a shopping list order. Tap to review and send quote!`,
      };
    case 'Photo':
      return {
        title: `🚨 NEW PHOTO ORDER #${displayId}`,
        body: `${customerName} uploaded item photos. Tap to review and send quote!`,
      };
    default: // 'Cart' or anything else
      return {
        title: `🚨 NEW ORDER RECEIVED #${displayId}`,
        body: `${customerName} placed a new order. Tap to review and accept!`,
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

  const { title, body } = buildOrderPushContent(orderType, displayId, customerName, amount);

  const message = {
    tokens,
    data: {
      type: 'new_order',
      orderId,
      displayId: displayId.toString(),
      amount: amount.toString(),
      customerName,
      orderType,
      alertSound: 'new_order_alert',
      notifTitle: title,
      notifBody: body,
    },
    android: {
      priority: 'high',
      ttl: 0,
    },
    apns: {
      payload: {
        aps: {
          sound: 'new_order_alert.caf',
          badge: 1,
        },
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
        channelId: 'namba_vendor_call_alerts_v19',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
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

async function sendQuotePushToCustomer(customerUser, order) {
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
  const totalAmount = Math.round(order.totalAmount || 0);

  const title = `🧾 Bill Quote Received #${displayId}`;
  const body = `Price Quote: ₹${totalAmount}. Tap to view quote details & proceed to payment!`;

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
      totalAmount: totalAmount.toString(),
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'namba_customer_order_alerts',
        sound: 'new_order_alert',
        defaultSound: false,
        priority: 'max',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'new_order_alert.caf',
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
  const amount = Number(order.totalAmount || extra.amount || 0);

  const title = `🚨 NEW ORDER ASSIGNED #${displayId}`;
  const body = `Pickup: ${vendorName} — ₹${amount}. Tap to review and accept delivery order!`;

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
      amount: amount.toString(),
      paymentMethod: order.paymentMethod || 'COD',
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'namba_delivery_order_alerts_v20',
        sound: 'new_order_alert',
        defaultSound: false,
        priority: 'max',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'new_order_alert.caf',
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

module.exports = {
  sendNewOrderPushToVendor,
  sendCustomPushToVendor,
  sendQuotePushToCustomer,
  sendNewOrderPushToDriver,
  sendSilentPingPush,
};
