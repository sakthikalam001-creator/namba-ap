const mongoose = require('mongoose');

async function debugOrdersAndVendors() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;

  console.log('=== VENDORS COLLECTION ===');
  const vendors = await db.collection('vendors').find({}).toArray();
  for (const v of vendors) {
    console.log(`Vendor _id: "${v._id.toString()}" | phone: "${v.phone}" | storeName: "${v.storeName}" | user: "${v.user ? v.user.toString() : 'null'}"`);
  }

  console.log('\n=== ORDERS VENDOR BREAKDOWN ===');
  const orders = await db.collection('orders').find({}).toArray();
  console.log(`Total orders in DB: ${orders.length}`);

  const vendorMap = {};
  orders.forEach(o => {
    const vStr = o.vendor ? o.vendor.toString() : 'NULL_VENDOR';
    if (!vendorMap[vStr]) {
      vendorMap[vStr] = { count: 0, statuses: {} };
    }
    vendorMap[vStr].count++;
    const s = o.status || 'UNKNOWN';
    vendorMap[vStr].statuses[s] = (vendorMap[vStr].statuses[s] || 0) + 1;
  });

  console.log(JSON.stringify(vendorMap, null, 2));

  process.exit(0);
}

debugOrdersAndVendors().catch(err => {
  console.error(err);
  process.exit(1);
});
