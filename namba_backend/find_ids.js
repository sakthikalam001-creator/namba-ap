const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

async function findIds() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;
    
    const vendor = await db.collection('vendors').findOne({ storeName: /Muruga/i });
    const customer = await db.collection('users').findOne({ role: 'customer' });
    
    console.log('Vendor:', vendor ? vendor._id : 'Not found');
    console.log('Customer:', customer ? customer._id : 'Not found');
  } catch (err) {
    console.error(err);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

findIds();
