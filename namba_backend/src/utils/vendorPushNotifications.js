let firebaseAdmin = null;
let firebaseInitialized = false;

function loadServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    return require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
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

async function sendNewOrderPushToVendor(vendor, order, extra = {}) {
  const admin = getFirebaseAdmin();
  const tokens = uniqueTokens(vendor);
  if (!admin || tokens.length === 0) return;

  const orderId = order._id.toString();
  const displayId = order.displayId || orderId.slice(-6).toUpperCase();
  const amount = Number(order.totalAmount || extra.amount || 0);

  const message = {
    tokens,
    notification: {
      title: 'New order received',
      body: `Order #${displayId} - Rs.${amount.toFixed(0)}`,
    },
    data: {
      type: 'new_order',
      orderId,
      displayId: displayId.toString(),
      amount: amount.toString(),
      customerName: extra.customerName || 'Customer',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'namaba_vendor_orders_v4',
        priority: 'max',
        visibility: 'public',
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
      headers: {
        'apns-priority': '10',
      },
    },
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  if (response.failureCount > 0) {
    const failedTokens = response.responses
      .map((item, index) => ({ item, token: tokens[index] }))
      .filter(({ item }) => !item.success)
      .map(({ token }) => token);

    if (failedTokens.length > 0) {
      vendor.pushTokens = (vendor.pushTokens || []).filter((entry) => !failedTokens.includes(entry.token));
      await vendor.save();
    }
  }
}

module.exports = {
  sendNewOrderPushToVendor,
};
