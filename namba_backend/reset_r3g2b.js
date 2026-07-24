const mongoose = require('mongoose');
require('dotenv').config();

async function reset() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db';
  await mongoose.connect(uri);
  await mongoose.connection.db.collection('orders').updateOne(
    { displayId: 'NM-R3G2B' },
    { $set: { status: 'Pending', totalAmount: 0, subTotal: 0, discount: 0 } }
  );
  console.log('Reset NM-R3G2B to Pending');
  await mongoose.disconnect();
}
reset().catch(console.error);
