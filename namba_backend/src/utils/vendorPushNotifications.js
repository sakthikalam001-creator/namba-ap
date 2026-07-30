const path = require('path');
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
        title: `\u{1F4DD} \u0BAA\u0BC1\u0BA4\u0BBF\u0BAA\u0BCD LIST ORDER! #${displayId}`,
        body: `${customerName} shopping list \u0B85\u0BA9\u0BC1\u0BAA\u0BCD\u0BAA\u0BBF\u0BA9\u0BBE\u0B99\u0BCD\u0B95 \u2014 confirm \u0BAA\u0BA3\u0BCD\u0BA3\u0BC1\u0B99\u0BCD\u0B95!`,
      };
    case 'Photo':
      return {
        title: `\u{1F4F8} \u0BAA\u0BC1\u0BA4\u0BBF\u0BAA\u0BCD PHOTO ORDER! #${displayId}`,
        body: `${customerName} photo order \u0B85\u0BA9\u0BC1\u0BAA\u0BCD\u0BAA\u0BBF\u0BA9\u0BBE\u0B99\u0BCD\u0B95 \u2014 \u0BAA\u0BBE\u0BB0\u0BCD\u0BA4\u0BCD\u0BA4\u0BC1 quote \u0B95\u0BCA\u0B9F\u0BC1\u0B99\u0BCD\u0B95!`,
      };
    default: // 'Cart' or anything else
      return {
        title: `\u{1F6D2} \u0BAA\u0BC1\u0BA4\u0BBF\u0BAA\u0BCD CART ORDER! #${displayId}`,
        body: `${customerName} cart order \u0BAA\u0BA3\u0BCD\u0BA3\u0BBE\u0B99\u0BCD\u0B95 \u2022 \u20B9${amount.toFixed(0)}`,
      };
  }
}

async function sendNewOrderPushToVendor(vendor, order, extra = {}) {
  const admin = getFirebaseAdmin();
  const tokens = uniqueTokens(vendor);
  if (!admin || tokens.length === 0) return;

  const orderId = order._id.toString();
  const displayId = order.displayId || orderId.slice(-6).toUpperCase();
  const amount = Number(order.totalAmount || extra.amount || 0);
  const orderType = order.orderType || extra.orderType || 'Cart';
  const customerName = extra.customerName || 'Customer';

  const { title, body } = buildOrderPushContent(orderType, displayId, customerName, amount);

  // ✅ DATA-ONLY message (no top-level `notification` field).
  // When app is killed, Android delivers data-only FCM to our background handler isolate.
  // The handler shows the notification with our custom channel (custom sound + full-screen intent).
  // If we use notification+data (mixed), Android system shows it with default sound/channel
  // and ignores our custom sound — even if channelId is set.
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
        channelId: 'namaba_vendor_loud_ringtone_v15',
        sound: 'new_order_alert',
        priority: 'max',
        visibility: 'public',
      },
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
