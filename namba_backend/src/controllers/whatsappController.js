const { 
  getWhatsAppStatus, 
  requestPairing, 
  disconnectAndReset, 
  sendWhatsAppMessage 
} = require('../utils/whatsapp');

// GET /api/v1/auth/whatsapp/status
exports.getWhatsAppStatus = async (req, res) => {
  try {
    const status = getWhatsAppStatus();
    res.status(200).json({ success: true, ...status });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// POST /api/v1/auth/whatsapp/pair
exports.requestWhatsAppPairing = async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }
    const result = await requestPairing(phone);
    if (result.success) {
      return res.status(200).json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// POST /api/v1/auth/whatsapp/logout
exports.disconnectWhatsApp = async (req, res) => {
  try {
    const result = await disconnectAndReset();
    res.status(200).json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// POST /api/v1/auth/whatsapp/test-send
exports.testSendWhatsApp = async (req, res) => {
  try {
    const { phone, message } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }
    const msg = message || '✅ Hello from Namba Delivery! WhatsApp Gateway is fully operational.';
    const success = await sendWhatsAppMessage(phone, msg);
    if (success) {
      res.status(200).json({ success: true, message: 'Message sent successfully to +' + phone });
    } else {
      res.status(400).json({ success: false, error: 'Failed to send. WhatsApp client is not connected.' });
    }
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};

// GET /whatsapp or GET /whatsapp-manager (HTML UI)
exports.renderWhatsAppManager = (req, res) => {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Namba WhatsApp Gateway Manager</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=JetBrains+Mono:wght@600;800&display=swap" rel="stylesheet">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
  <style>
    :root {
      --primary: #4F46E5;
      --primary-hover: #4338CA;
      --success: #10B981;
      --warning: #F59E0B;
      --danger: #EF4444;
      --bg: #F8FAFC;
      --card-bg: #FFFFFF;
      --text: #0F172A;
      --text-muted: #64748B;
      --border: #E2E8F0;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 16px;
    }
    .container {
      width: 100%;
      max-width: 540px;
    }
    .header {
      text-align: center;
      margin-bottom: 24px;
    }
    .logo-badge {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      background: linear-gradient(135deg, #4F46E5, #7C3AED);
      color: white;
      padding: 10px 20px;
      border-radius: 999px;
      font-weight: 700;
      font-size: 17px;
      box-shadow: 0 4px 14px rgba(79, 70, 229, 0.35);
      margin-bottom: 12px;
    }
    .title {
      font-size: 26px;
      font-weight: 800;
      color: #1E293B;
    }
    .subtitle {
      font-size: 14px;
      color: var(--text-muted);
      margin-top: 4px;
    }
    .card {
      background: var(--card-bg);
      border-radius: 24px;
      padding: 28px 24px;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.03);
      border: 1px solid var(--border);
      margin-bottom: 20px;
      transition: all 0.3s ease;
    }
    .status-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 18px;
      border-radius: 16px;
      margin-bottom: 22px;
      font-weight: 600;
      font-size: 15px;
    }
    .status-bar.connected {
      background: #ECFDF5;
      color: #065F46;
      border: 1px solid #A7F3D0;
    }
    .status-bar.disconnected {
      background: #FEF2F2;
      color: #991B1B;
      border: 1px solid #FECACA;
    }
    .status-indicator {
      display: inline-block;
      width: 10px;
      height: 10px;
      border-radius: 50%;
      margin-right: 8px;
    }
    .connected .status-indicator {
      background: #10B981;
      box-shadow: 0 0 0 4px rgba(16, 185, 129, 0.25);
      animation: pulse 2s infinite;
    }
    .disconnected .status-indicator {
      background: #EF4444;
    }
    @keyframes pulse {
      0% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.6); }
      70% { box-shadow: 0 0 0 8px rgba(16, 185, 129, 0); }
      100% { box-shadow: 0 0 0 0 rgba(16, 185, 129, 0); }
    }
    .tabs {
      display: flex;
      background: #F1F5F9;
      border-radius: 14px;
      padding: 4px;
      margin-bottom: 20px;
    }
    .tab-btn {
      flex: 1;
      padding: 10px;
      text-align: center;
      border-radius: 10px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      border: none;
      background: transparent;
      color: var(--text-muted);
      transition: all 0.2s;
    }
    .tab-btn.active {
      background: white;
      color: var(--primary);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    }
    .tab-content { display: none; }
    .tab-content.active { display: block; }
    .qr-wrapper {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px;
      background: #FAFAFA;
      border-radius: 18px;
      border: 2px dashed #E2E8F0;
      margin-bottom: 18px;
    }
    #qrcode-box {
      width: 256px;
      height: 256px;
      background: white;
      padding: 12px;
      border-radius: 14px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.06);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    #qrcode-box img, #qrcode-box canvas {
      width: 100% !important;
      height: 100% !important;
    }
    .instructions {
      background: #F8FAFC;
      border-radius: 14px;
      padding: 16px;
      font-size: 13.5px;
      line-height: 1.6;
      color: #334155;
      border: 1px solid var(--border);
    }
    .instructions ol {
      padding-left: 20px;
    }
    .instructions li {
      margin-bottom: 6px;
    }
    .instructions b {
      color: #0F172A;
    }
    .form-group {
      margin-bottom: 16px;
    }
    .form-group label {
      display: block;
      font-size: 13px;
      font-weight: 700;
      color: #475569;
      margin-bottom: 6px;
    }
    .input-field {
      width: 100%;
      padding: 12px 16px;
      border-radius: 12px;
      border: 1.5px solid var(--border);
      font-size: 15px;
      font-family: inherit;
      outline: none;
      transition: border-color 0.2s;
    }
    .input-field:focus {
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.15);
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      width: 100%;
      padding: 14px 20px;
      border-radius: 14px;
      font-size: 15px;
      font-weight: 700;
      font-family: inherit;
      cursor: pointer;
      border: none;
      transition: all 0.2s;
    }
    .btn-primary {
      background: var(--primary);
      color: white;
    }
    .btn-primary:hover {
      background: var(--primary-hover);
    }
    .btn-danger {
      background: #FEE2E2;
      color: #DC2626;
      border: 1px solid #FCA5A5;
      margin-top: 12px;
    }
    .btn-danger:hover {
      background: #FCA5A5;
    }
    .code-display {
      background: #F1F5F9;
      padding: 18px;
      border-radius: 14px;
      text-align: center;
      margin: 16px 0;
      border: 2px dashed #CBD5E1;
    }
    .code-display .code-val {
      font-family: 'JetBrains Mono', monospace;
      font-size: 32px;
      font-weight: 800;
      letter-spacing: 6px;
      color: var(--primary);
    }
    .test-box {
      background: #EEF2FF;
      border: 1px solid #C7D2FE;
      border-radius: 16px;
      padding: 18px;
      margin-top: 18px;
    }
    .alert-msg {
      padding: 12px 16px;
      border-radius: 10px;
      font-size: 13.5px;
      font-weight: 600;
      margin-top: 12px;
      display: none;
    }
    .alert-success { background: #ECFDF5; color: #065F46; border: 1px solid #A7F3D0; }
    .alert-error { background: #FEF2F2; color: #991B1B; border: 1px solid #FECACA; }
    .footer {
      text-align: center;
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 16px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo-badge">
        <span>🚀</span> Namba WhatsApp Gateway
      </div>
      <h1 class="title">WhatsApp Connection Manager</h1>
      <p class="subtitle">Directly links your WhatsApp number to send OTPs and customer alerts</p>
    </div>

    <div class="card">
      <div id="statusBar" class="status-bar disconnected">
        <div><span class="status-indicator"></span><span id="statusText">Checking status...</span></div>
        <span id="phoneTag" style="font-size: 13px; opacity: 0.85;"></span>
      </div>

      <!-- DISCONNECTED VIEW -->
      <div id="disconnectedView">
        <div class="tabs">
          <button class="tab-btn active" onclick="switchTab('qrTab')">📷 Scan QR Code</button>
          <button class="tab-btn" onclick="switchTab('pairTab')">📱 Phone Pairing Code</button>
        </div>

        <!-- TAB 1: QR CODE -->
        <div id="qrTab" class="tab-content active">
          <div class="qr-wrapper">
            <div id="qrcode-box">
              <div id="qrPlaceholder" style="text-align: center; color: #94A3B8; font-size: 13px;">
                ⏳ Generating live QR code...<br><span style="font-size: 11px;">Refreshes automatically</span>
              </div>
            </div>
            <p style="font-size: 12px; color: var(--text-muted); margin-top: 12px;">
              🔄 Live updating every 3 seconds
            </p>
          </div>

          <div class="instructions">
            <b>How to connect via QR Code (QR குறியீட்டை ஸ்கேன் செய்வது எப்படி):</b>
            <ol>
              <li>Open <b>WhatsApp</b> on your mobile phone (உங்கள் மொபைலில் வாட்ஸ்அப் திறக்கவும்).</li>
              <li>Tap <b>Menu (⋮)</b> or <b>Settings</b> &rarr; <b>Linked Devices</b> (இணைக்கப்பட்ட சாதனங்கள்).</li>
              <li>Tap <b>Link a device</b> (சாதனத்தை இணைக்கவும்).</li>
              <li>Point your phone camera at the QR code above to scan.</li>
            </ol>
          </div>
        </div>

        <!-- TAB 2: PAIRING CODE -->
        <div id="pairTab" class="tab-content">
          <div class="form-group">
            <label>Your WhatsApp Mobile Number (உங்கள் வாட்ஸ்அப் மொபைல் எண்)</label>
            <div style="display: flex; gap: 8px;">
              <input type="text" value="+91" readonly style="width: 60px; text-align: center; background: #F1F5F9; font-weight: 700;" class="input-field">
              <input type="tel" id="pairPhoneInput" class="input-field" placeholder="e.g. 9884488178" maxlength="10">
            </div>
          </div>
          <button class="btn btn-primary" onclick="generatePairingCode()" id="pairBtn">
            🔑 Get 8-Digit Pairing Code
          </button>

          <div id="pairingCodeBox" style="display: none;">
            <div class="code-display">
              <div style="font-size: 12px; color: #64748B; margin-bottom: 6px; font-weight: 700;">YOUR PAIRING CODE</div>
              <div class="code-val" id="pairingCodeVal">----</div>
              <div style="font-size: 11px; color: #64748B; margin-top: 6px;">Expires in 60 seconds</div>
            </div>

            <div class="instructions">
              <b>How to enter pairing code on WhatsApp:</b>
              <ol>
                <li>Open <b>WhatsApp</b> &rarr; <b>Linked Devices</b> &rarr; <b>Link a Device</b>.</li>
                <li>Tap <b>"Link with phone number instead"</b> at the bottom.</li>
                <li>Enter the 8-digit code shown above. Done!</li>
              </ol>
            </div>
          </div>

          <div id="pairAlert" class="alert-msg"></div>
        </div>
      </div>

      <!-- CONNECTED VIEW -->
      <div id="connectedView" style="display: none;">
        <div style="text-align: center; padding: 10px 0 20px;">
          <div style="font-size: 48px; margin-bottom: 8px;">🎉</div>
          <h2 style="font-size: 20px; font-weight: 800; color: #065F46;">WhatsApp is Connected!</h2>
          <p style="font-size: 14px; color: #475569; margin-top: 4px;">
            Customer PINs and notifications are now delivering via your WhatsApp number in real-time.
          </p>
        </div>

        <!-- TEST MESSAGE TOOL -->
        <div class="test-box">
          <h3 style="font-size: 15px; font-weight: 800; color: #3730A3; margin-bottom: 12px;">
            📲 Send Test WhatsApp Message
          </h3>
          <div class="form-group">
            <label>Recipient Phone Number (10 digits)</label>
            <input type="tel" id="testPhoneInput" class="input-field" placeholder="e.g. 9884488178" maxlength="10">
          </div>
          <div class="form-group">
            <label>Test Message</label>
            <input type="text" id="testMsgInput" class="input-field" value="Namba Delivery: Your Test OTP PIN is 998811. Valid for 10 minutes.">
          </div>
          <button class="btn btn-primary" onclick="sendTestMessage()" id="testBtn">
            🚀 Send Test Message
          </button>
          <div id="testAlert" class="alert-msg"></div>
        </div>

        <button class="btn btn-danger" onclick="disconnectSession()" id="logoutBtn">
          🔌 Disconnect / Link Another Number
        </button>
      </div>

    </div>

    <div class="footer">
      Namba Delivery Platform &bull; Self-Hosted WhatsApp Web Engine
    </div>
  </div>

  <script>
    let currentQr = '';
    let isConnectedState = false;

    function switchTab(tabId) {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      if (tabId === 'qrTab') {
        document.querySelectorAll('.tab-btn')[0].classList.add('active');
        document.getElementById('qrTab').classList.add('active');
      } else {
        document.querySelectorAll('.tab-btn')[1].classList.add('active');
        document.getElementById('pairTab').classList.add('active');
      }
    }

    async function pollStatus() {
      try {
        const res = await fetch('/api/v1/auth/whatsapp/status');
        const data = await res.json();

        if (data.isConnected) {
          isConnectedState = true;
          document.getElementById('statusBar').className = 'status-bar connected';
          document.getElementById('statusText').innerText = '🟢 Connected & Live';
          document.getElementById('phoneTag').innerText = '+' + (data.connectedPhone || 'Linked');
          document.getElementById('disconnectedView').style.display = 'none';
          document.getElementById('connectedView').style.display = 'block';
        } else {
          isConnectedState = false;
          document.getElementById('statusBar').className = 'status-bar disconnected';
          document.getElementById('statusText').innerText = '🔴 Disconnected / Waiting to Link';
          document.getElementById('phoneTag').innerText = '';
          document.getElementById('disconnectedView').style.display = 'block';
          document.getElementById('connectedView').style.display = 'none';

          if (data.latestQr && data.latestQr !== currentQr) {
            currentQr = data.latestQr;
            renderQr(data.latestQr);
          }
        }
      } catch (err) {
        console.error('Status poll error:', err);
      }
    }

    function renderQr(qrText) {
      const box = document.getElementById('qrcode-box');
      box.innerHTML = '';
      try {
        new QRCode(box, {
          text: qrText,
          width: 232,
          height: 232,
          colorDark: '#000000',
          colorLight: '#ffffff',
          correctLevel: QRCode.CorrectLevel.M
        });
      } catch (e) {
        console.error('QR Render Error:', e);
      }
    }

    async function generatePairingCode() {
      const phone = document.getElementById('pairPhoneInput').value.trim();
      const alertBox = document.getElementById('pairAlert');
      const btn = document.getElementById('pairBtn');

      if (phone.length < 10) {
        showAlert(alertBox, 'Please enter a valid 10-digit mobile number', 'error');
        return;
      }

      btn.disabled = true;
      btn.innerText = '⏳ Requesting code...';
      alertBox.style.display = 'none';

      try {
        const res = await fetch('/api/v1/auth/whatsapp/pair', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ phone: phone })
        });
        const data = await res.json();
        btn.disabled = false;
        btn.innerText = '🔑 Get 8-Digit Pairing Code';

        if (data.success && data.pairingCode) {
          document.getElementById('pairingCodeVal').innerText = data.pairingCode;
          document.getElementById('pairingCodeBox').style.display = 'block';
          showAlert(alertBox, 'Pairing code generated! Enter it on your phone WhatsApp.', 'success');
        } else {
          showAlert(alertBox, data.error || 'Failed to generate pairing code. Please try again.', 'error');
        }
      } catch (e) {
        btn.disabled = false;
        btn.innerText = '🔑 Get 8-Digit Pairing Code';
        showAlert(alertBox, 'Network error. Please try again.', 'error');
      }
    }

    async function sendTestMessage() {
      const phone = document.getElementById('testPhoneInput').value.trim();
      const message = document.getElementById('testMsgInput').value.trim();
      const alertBox = document.getElementById('testAlert');
      const btn = document.getElementById('testBtn');

      if (phone.length < 10) {
        showAlert(alertBox, 'Enter a valid 10-digit recipient phone number', 'error');
        return;
      }

      btn.disabled = true;
      btn.innerText = '⏳ Sending...';
      alertBox.style.display = 'none';

      try {
        const res = await fetch('/api/v1/auth/whatsapp/test-send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ phone, message })
        });
        const data = await res.json();
        btn.disabled = false;
        btn.innerText = '🚀 Send Test Message';

        if (data.success) {
          showAlert(alertBox, '✅ Message delivered successfully to +' + phone, 'success');
        } else {
          showAlert(alertBox, '❌ ' + (data.error || 'Send failed'), 'error');
        }
      } catch (e) {
        btn.disabled = false;
        btn.innerText = '🚀 Send Test Message';
        showAlert(alertBox, 'Network error while sending', 'error');
      }
    }

    async function disconnectSession() {
      if (!confirm('Are you sure you want to disconnect WhatsApp? You will need to scan or pair again to reconnect.')) return;

      const btn = document.getElementById('logoutBtn');
      btn.disabled = true;
      btn.innerText = '🔌 Disconnecting...';

      try {
        await fetch('/api/v1/auth/whatsapp/logout', { method: 'POST' });
        setTimeout(pollStatus, 1500);
      } catch (e) {
        console.error(e);
      }
    }

    function showAlert(box, msg, type) {
      box.innerText = msg;
      box.className = 'alert-msg alert-' + type;
      box.style.display = 'block';
    }

    // Initial check and start polling every 3s
    pollStatus();
    setInterval(pollStatus, 3000);
  </script>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html');
  res.send(html);
};
