const axios = require('axios');

/**
 * Sends a real WhatsApp message using configured environment variables.
 * Falls back to console log simulation if not configured.
 * @param {string} phone 10-digit phone number (without +91)
 * @param {string} message The text message to send
 */
const sendWhatsAppMessage = async (phone, message) => {
  const url = process.env.WHATSAPP_API_URL;
  const token = process.env.WHATSAPP_API_TOKEN;

  // Format phone to include 91 (India) country code if not present
  let formattedPhone = phone.trim();
  if (!formattedPhone.startsWith('91') && formattedPhone.length === 10) {
    formattedPhone = `91${formattedPhone}`;
  }

  if (!url) {
    console.log(`\n================= WHATSAPP MOCK GATEWAY =================`);
    console.log(`[WhatsApp API] (NOT CONFIGURED - Set WHATSAPP_API_URL in .env)`);
    console.log(`To: +${formattedPhone}`);
    console.log(`Message: ${message}`);
    console.log(`====================================================\n`);
    return false;
  }

  try {
    console.log(`[WhatsApp API] Sending real message to +${formattedPhone}...`);
    
    // Support various common request formats based on the provider
    const payload = {
      to: formattedPhone,
      phone: formattedPhone, // some APIs use phone instead of to
      message: message,
      body: message,         // some APIs use body instead of message
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
    console.log(`[WhatsApp API] Response status: ${res.status} | Data:`, res.data);
    return true;
  } catch (err) {
    console.error(`[WhatsApp API] ❌ Failed to send message to +${formattedPhone}:`, err.message);
    if (err.response) {
      console.error(`[WhatsApp API] Error Response Data:`, err.response.data);
    }
    return false;
  }
};

module.exports = { sendWhatsAppMessage };
