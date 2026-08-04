const { sendWhatsAppDirect, isWhatsAppConnected } = require('./whatsappClient');
const axios = require('axios');

/**
 * Sends a WhatsApp message.
 * Tries the free direct self-hosted client first.
 * Falls back to third-party URL if configured, and finally console simulation.
 * @param {string} phone 10-digit phone number
 * @param {string} message The text message to send
 */
const sendWhatsAppMessage = async (phone, message) => {
  // Format phone to include 91 (India) country code if not present
  let formattedPhone = phone.trim();
  if (!formattedPhone.startsWith('91') && formattedPhone.length === 10) {
    formattedPhone = `91${formattedPhone}`;
  }

  // Channel 1: Free Self-Hosted direct WhatsApp connection
  if (isWhatsAppConnected()) {
    try {
      const success = await sendWhatsAppDirect(phone, message);
      if (success) return true;
    } catch (directErr) {
      console.error(`[WhatsApp Client] Direct send failed, trying fallbacks:`, directErr.message);
    }
  }

  // Channel 2: Fallback to third-party URL (if configured)
  const url = process.env.WHATSAPP_API_URL;
  const token = process.env.WHATSAPP_API_TOKEN;

  if (url) {
    try {
      console.log(`[WhatsApp API] Falling back to third-party API for +${formattedPhone}...`);
      
      const payload = {
        to: formattedPhone,
        phone: formattedPhone,
        message: message,
        body: message,
      };

      if (token) {
        payload.token = token;
        payload.apikey = token;
      }

      const headers = {
        'Content-Type': 'application/json',
      };
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
        headers['apikey'] = token;
      }

      const res = await axios.post(url, payload, { headers, timeout: 10000 });
      console.log(`[WhatsApp API] Fallback API response: ${res.status}`);
      return true;
    } catch (err) {
      console.error(`[WhatsApp API] Fallback API failed:`, err.message);
    }
  }

  // Channel 3: Fallback to Console Mock Logging
  console.log(`\n================= WHATSAPP MOCK GATEWAY =================`);
  console.log(`To: +${formattedPhone}`);
  console.log(`Message: ${message}`);
  console.log(`====================================================\n`);
  return false;
};

module.exports = { sendWhatsAppMessage };
