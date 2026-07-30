const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const Vendor = require('./src/models/Vendor');

dotenv.config({ path: path.join(__dirname, '.env') });

async function check() {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db');
    console.log('[Info] Connected to MongoDB');
    
    const vendors = await Vendor.find({});
    console.log(`[Info] Found ${vendors.length} vendors:`);
    vendors.forEach(v => {
      console.log(`ID: ${v._id} | Store: ${v.storeName} | Tokens count: ${v.pushTokens ? v.pushTokens.length : 0}`);
      if (v.pushTokens && v.pushTokens.length > 0) {
        v.pushTokens.forEach(pt => {
          console.log(`  - Token: ${pt.token.substring(0, 15)}... | Platform: ${pt.platform} | LastSeen: ${pt.lastSeenAt}`);
        });
      }
    });
    
    process.exit(0);
  } catch (err) {
    console.error('[Error]', err);
    process.exit(1);
  }
}

check();
