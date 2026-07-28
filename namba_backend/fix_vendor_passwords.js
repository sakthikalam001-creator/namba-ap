// Test script to verify vendor login and reset password if needed
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

async function fixVendorPasswords() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;

  const vendors = await db.collection('vendors').find({}).toArray();
  
  for (const v of vendors) {
    const user = await db.collection('users').findOne({ _id: v.user });
    if (!user) {
      console.log('SKIP - no user for vendor:', v.storeName);
      continue;
    }

    // Set a known password for testing: vendor123
    const salt = await bcrypt.genSalt(10);
    const hashed = await bcrypt.hash('vendor123', salt);
    
    await db.collection('users').updateOne(
      { _id: user._id },
      { $set: { password: hashed } }
    );
    
    console.log('FIXED - Store:', v.storeName, '| Phone:', v.phone, '| Password set to: vendor123');
  }
  
  process.exit(0);
}

fixVendorPasswords().catch(err => { console.error(err); process.exit(1); });
