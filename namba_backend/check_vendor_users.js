const mongoose = require('mongoose');
const { User } = require('./src/models/User');

async function check() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  
  // Find all vendor users
  const vendors = await mongoose.connection.db.collection('vendors').find({}).toArray();
  const vendorUserIds = vendors.map(v => v.user ? v.user.toString() : null).filter(Boolean);
  
  console.log('=== VENDOR USER IDs ===');
  vendors.forEach(v => {
    console.log('VendorID:', v._id.toString(), '| UserID:', v.user ? v.user.toString() : 'NULL', '| Phone:', v.phone, '| Store:', v.storeName);
  });

  console.log('\n=== USERS LOOKUP ===');
  for (const v of vendors) {
    const userByPhone = await mongoose.connection.db.collection('users').findOne({ phone: v.phone });
    const userById = v.user ? await mongoose.connection.db.collection('users').findOne({ _id: v.user }) : null;
    console.log('Store:', v.storeName, '| Phone:', v.phone);
    console.log('  UserByPhone:', userByPhone ? JSON.stringify({id: userByPhone._id, role: userByPhone.role, hasPass: !!userByPhone.password}) : 'NOT FOUND');
    console.log('  UserByID:', userById ? JSON.stringify({id: userById._id, phone: userById.phone, role: userById.role, hasPass: !!userById.password}) : 'NOT FOUND');
  }
  
  process.exit(0);
}

check().catch(err => { console.error(err); process.exit(1); });
