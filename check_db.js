const mongoose = require('mongoose');

async function check() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;

  const vendors = await db.collection('vendors').find({}).toArray();
  console.log('========== VENDORS (' + vendors.length + ') ==========');
  vendors.forEach(v => {
    console.log(`Vendor ID: ${v._id} | Phone: ${v.phone} | Name: ${v.storeName} | PushTokens: ${v.pushTokens ? v.pushTokens.length : 0}`);
  });

  const orders = await db.collection('orders').find({}).toArray();
  console.log('\n========== ORDERS (' + orders.length + ') ==========');
  orders.forEach(o => {
    console.log(`Order ID: ${o._id} | DisplayID: ${o.displayId} | Status: ${o.status} | Vendor: ${o.vendor} | Customer: ${o.customer}`);
  });

  process.exit(0);
}

check().catch(err => {
  console.error(err);
  process.exit(1);
});
