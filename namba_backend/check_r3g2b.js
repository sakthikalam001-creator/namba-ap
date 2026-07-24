const mongoose = require('mongoose');
require('dotenv').config();

async function check() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db';
  await mongoose.connect(uri);
  const o = await mongoose.connection.db.collection('orders').findOne({ displayId: 'NM-R3G2B' });
  console.log('--- NM-R3G2B Details ---');
  console.log('ID:', o ? o._id : 'Not Found');
  console.log('Status:', o ? o.status : 'N/A');
  console.log('TotalAmount:', o ? o.totalAmount : 'N/A');
  console.log('SubTotal:', o ? o.subTotal : 'N/A');
  console.log('OrderType:', o ? o.orderType : 'N/A');
  await mongoose.disconnect();
}
check().catch(console.error);
