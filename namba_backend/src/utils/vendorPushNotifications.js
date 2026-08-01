const path = require('path');
const VENDOR_ORDER_ALERT_CHANNEL_ID = 'namba_vendor_call_alerts_v3';
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
        title: `New list order received #${displayId}`,
        body: `${customerName} sent a shopping list. Review it and send a quote.`,
      };
    case 'Photo':
      return {
        title: `New photo order received #${displayId}`,
        body: `${customerName} uploaded item photos. Review the order and send a quote.`,
      };
    default: // 'Cart' or anything else
      return {
        title: `New order received #${displayId}`,
        body: `${customerName} placed a cart order. Amount: Rs. ${amount.toFixed(0)}. Tap to review.`,
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

  // ✅ High Priority FCM Message with System Notification + Data Payload.
  // Google Play Services delivers this INSTANTLY (0ms delay) even when user is using other apps (WhatsApp, YouTube, Games).
  // Displays a heads-up / lock-screen alert on the vendor order alert channel.
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
      notifTitle: title,
      notifBody: body,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'namba_vendor_call_alerts_v3',
        sound: 'new_order_alert',
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
          sound: 'new_order_alert.wav',
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
    console.log(`[Push] Sent ${response.successCount}/${tokens.length} pushes for order #${displayId} (type: ${orderType})`);

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

module.exports = {
  sendNewOrderPushToVendor,
};
