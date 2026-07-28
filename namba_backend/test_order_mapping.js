const mongoose = require('mongoose');

async function testOrderMapping() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;

  const vendorId = '6a57aefb16962c32adc0341c';
  const orders = await db.collection('orders').find({
    $or: [{ vendor: vendorId }, { vendor: new mongoose.Types.ObjectId(vendorId) }],
    status: { $ne: 'Cart' }
  }).toArray();

  console.log(`Found ${orders.length} orders for OM Muruga Mess`);

  let errors = 0;
  orders.forEach((ao, index) => {
    try {
      const id = ao._id ? ao._id.toString() : '';
      const displayId = ao.displayId || `NM-${id.substring(id.length > 5 ? id.length - 5 : 0).toUpperCase()}`;
      const customer = ao.customer || {};
      const items = ao.items || [];
      const totalAmount = ((parseFloat(ao.subTotal) || 0) > 0)
        ? (parseFloat(ao.subTotal) || 0) - (parseFloat(ao.discount) || 0)
        : (((parseFloat(ao.totalAmount) || 0) > 0) ? (parseFloat(ao.totalAmount) || 0) - (parseFloat(ao.customerPlatformFee) || 0) : 0);
      const createdAt = ao.createdAt ? new Date(ao.createdAt).toISOString() : new Date().toISOString();
      const status = ao.status || 'Pending';
      // Test parse
    } catch (err) {
      console.error(`Error on order index ${index} (ID: ${ao._id}):`, err.message);
      errors++;
    }
  });

  console.log(`Test completed. Errors: ${errors}`);
  process.exit(0);
}

testOrderMapping().catch(err => { console.error(err); process.exit(1); });
