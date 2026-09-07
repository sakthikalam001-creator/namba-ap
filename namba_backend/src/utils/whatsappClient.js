const { default: makeWASocket, useMultiFileAuthState, DisconnectReason } = require('@whiskeysockets/baileys');
const path = require('path');
const fs = require('fs');
const qrcode = require('qrcode-terminal');
const pino = require('pino');

let sock = null;
let isConnected = false;
let connectedPhone = null;
let latestQr = null;
let lastDisconnectReason = null;
let isInitializing = false;

const getAuthFolder = () => path.join(__dirname, '../../whatsapp_auth_info');

const initWhatsApp = async () => {
  if (isInitializing) return;
  isInitializing = true;

  try {
    const authFolder = getAuthFolder();
    if (!fs.existsSync(authFolder)) {
      fs.mkdirSync(authFolder, { recursive: true });
    }

    const { state, saveCreds } = await useMultiFileAuthState(authFolder);

    sock = makeWASocket({
      auth: state,
      printQRInTerminal: false,
      logger: pino({ level: 'silent' }),
      browser: ['Namba Delivery', 'Chrome', '1.0.0'],
    });

    sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        latestQr = qr;
        console.log(`\n====================================================`);
        console.log(`📱 SCAN THIS QR CODE OR OPEN http://<HOST>:5000/whatsapp:`);
        console.log(`====================================================\n`);
        try {
          qrcode.generate(qr, { small: true });
        } catch (_) {}
        console.log(`\n====================================================\n`);
      }

      if (connection === 'close') {
        isConnected = false;
        connectedPhone = null;
        const statusCode = lastDisconnect?.error?.output?.statusCode;
        lastDisconnectReason = lastDisconnect?.error?.message || 'Connection closed';
        const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

        console.log(`[WhatsApp Client] Connection closed. Reason:`, lastDisconnectReason);
        if (shouldReconnect) {
          console.log(`[WhatsApp Client] Reconnecting in 5 seconds...`);
          setTimeout(() => {
            isInitializing = false;
            initWhatsApp();
          }, 5000);
        } else {
          console.log(`[WhatsApp Client] Logged out. Resetting credentials...`);
          latestQr = null;
          try {
            fs.rmSync(authFolder, { recursive: true, force: true });
          } catch (_) {}
          setTimeout(() => {
            isInitializing = false;
            initWhatsApp();
          }, 3000);
        }
      } else if (connection === 'open') {
        isConnected = true;
        latestQr = null;
        lastDisconnectReason = null;
        try {
          connectedPhone = sock.user ? sock.user.id.split(':')[0] : 'Linked';
        } catch (_) {
          connectedPhone = 'Linked';
        }
        console.log(`\n[WhatsApp Client] 🟢 SUCCESS! WhatsApp Client connected successfully!`);
        console.log(`[WhatsApp Client] Number linked: ${connectedPhone}\n`);
      }
    });

    sock.ev.on('creds.update', saveCreds);

  } catch (err) {
    console.error('[WhatsApp Client] Initialization error:', err.message);
    isConnected = false;
    setTimeout(() => {
      isInitializing = false;
      initWhatsApp();
    }, 10000);
  } finally {
    isInitializing = false;
  }
};

// Send message via linked whatsapp connection
const sendWhatsAppDirect = async (phone, message) => {
  if (!isConnected || !sock) {
    console.warn(`[WhatsApp Client] ⚠️ Cannot send message. Client is not connected.`);
    return false;
  }

  try {
    let formattedPhone = phone.toString().trim().replace(/\D/g, '');
    if (!formattedPhone.startsWith('91') && formattedPhone.length === 10) {
      formattedPhone = `91${formattedPhone}`;
    }
    const jid = `${formattedPhone}@s.whatsapp.net`;
    
    await sock.sendMessage(jid, { text: message });
    console.log(`[WhatsApp Client] ✅ Message sent successfully to +${formattedPhone}`);
    return true;
  } catch (err) {
    console.error(`[WhatsApp Client] ❌ Send message failed:`, err.message);
    return false;
  }
};

// Request 8-digit Pairing code (Alternative to QR code scan)
const requestPairing = async (phoneNumber) => {
  if (isConnected) {
    return { success: false, error: 'WhatsApp is already connected as ' + (connectedPhone || 'Linked device') };
  }
  if (!sock) {
    return { success: false, error: 'WhatsApp service is not ready. Please wait a few seconds and try again.' };
  }

  try {
    let cleanPhone = String(phoneNumber).replace(/\D/g, '');
    if (cleanPhone.length === 10) {
      cleanPhone = `91${cleanPhone}`;
    }
    if (cleanPhone.length < 10) {
      return { success: false, error: 'Please enter a valid 10-digit phone number' };
    }

    const rawCode = await sock.requestPairingCode(cleanPhone);
    // Format code as ABCD-EFGH for better readability
    const formattedCode = rawCode?.match(/.{1,4}/g)?.join('-') || rawCode;
    console.log(`[WhatsApp Client] 🔑 Pairing code generated: ${formattedCode} for +${cleanPhone}`);
    
    return {
      success: true,
      pairingCode: formattedCode,
      rawCode,
      phone: cleanPhone,
    };
  } catch (err) {
    console.error('[WhatsApp Client] Pairing code error:', err.message);
    return {
      success: false,
      error: err.message || 'Failed to generate pairing code',
    };
  }
};

// Disconnect and reset WhatsApp session
const disconnectAndReset = async () => {
  console.log('[WhatsApp Client] Resetting session...');
  try {
    if (sock) {
      try {
        await sock.logout();
      } catch (_) {}
      try {
        sock.end(undefined);
      } catch (_) {}
    }
  } catch (_) {}

  isConnected = false;
  connectedPhone = null;
  latestQr = null;

  try {
    const authFolder = getAuthFolder();
    if (fs.existsSync(authFolder)) {
      fs.rmSync(authFolder, { recursive: true, force: true });
    }
  } catch (e) {
    console.error('[WhatsApp Client] Error clearing auth folder:', e.message);
  }

  setTimeout(() => {
    isInitializing = false;
    initWhatsApp();
  }, 2000);

  return { success: true, message: 'WhatsApp session cleared. Refreshing in 2 seconds...' };
};

const getWhatsAppStatus = () => {
  return {
    isConnected,
    connectedPhone,
    hasQr: !!latestQr,
    latestQr,
    lastDisconnectReason,
  };
};

// Initialize on startup
initWhatsApp();

module.exports = {
  sendWhatsAppDirect,
  isWhatsAppConnected: () => isConnected,
  getWhatsAppStatus,
  requestPairing,
  disconnectAndReset,
};
