const { default: makeWASocket, useMultiFileAuthState, DisconnectReason } = require('@whiskeysockets/baileys');
const path = require('path');
const fs = require('fs');
const qrcode = require('qrcode-terminal');
const pino = require('pino');

let sock = null;
let isConnected = false;

const initWhatsApp = async () => {
  try {
    const authFolder = path.join(__dirname, '../../whatsapp_auth_info');
    if (!fs.existsSync(authFolder)) {
      fs.mkdirSync(authFolder, { recursive: true });
    }

    const { state, saveCreds } = await useMultiFileAuthState(authFolder);

    sock = makeWASocket({
      auth: state,
      printQRInTerminal: false, // We will print it ourselves with clean formatting
      logger: pino({ level: 'silent' }), // Suppress detailed logging
    });

    sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        console.log(`\n====================================================`);
        console.log(`📱 SCAN THIS QR CODE TO CONNECT YOUR WHATSAPP NUMBER:`);
        console.log(`====================================================\n`);
        qrcode.generate(qr, { small: true });
        console.log(`\n====================================================\n`);
      }

      if (connection === 'close') {
        isConnected = false;
        const shouldReconnect = lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
        console.log(`[WhatsApp Client] Connection closed. Reason:`, lastDisconnect?.error?.message);
        if (shouldReconnect) {
          console.log(`[WhatsApp Client] Reconnecting...`);
          setTimeout(initWhatsApp, 5000);
        } else {
          console.log(`[WhatsApp Client] Logged out. Delete "whatsapp_auth_info" folder and scan again.`);
        }
      } else if (connection === 'open') {
        isConnected = true;
        console.log(`\n[WhatsApp Client] 🟢 SUCCESS! WhatsApp Client connected successfully!`);
        console.log(`[WhatsApp Client] Number linked: ${sock.user.id.split(':')[0]}\n`);
      }
    });

    sock.ev.on('creds.update', saveCreds);

  } catch (err) {
    console.error('[WhatsApp Client] Initialization error:', err.message);
    setTimeout(initWhatsApp, 10000);
  }
};

// Send message via linked whatsapp connection
const sendWhatsAppDirect = async (phone, message) => {
  if (!isConnected || !sock) {
    console.warn(`[WhatsApp Client] ⚠️ Cannot send message. Client is not connected.`);
    return false;
  }

  try {
    let formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('91') && formattedPhone.length === 10) {
      formattedPhone = `91${formattedPhone}`;
    }
    const jid = `${formattedPhone}@s.whatsapp.net`;
    
    await sock.sendMessage(jid, { text: message });
    console.log(`[WhatsApp Client] Message sent successfully to +${formattedPhone}`);
    return true;
  } catch (err) {
    console.error(`[WhatsApp Client] ❌ Send message failed:`, err.message);
    return false;
  }
};

// Initialize on startup
initWhatsApp();

module.exports = {
  sendWhatsAppDirect,
  isWhatsAppConnected: () => isConnected,
};
