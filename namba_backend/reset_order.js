const mongoose = require('mongoose');
require('dotenv').config();

async function reset() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db';
  await mongoose.connect(uri);
  await mongoose.connection.db.collection('orders').updateOne(
    { displayId: 'NM-UZRS2' },
    { $set: { status: 'Pending', totalAmount: 0, subTotal: 0 } }
  );
  console.log('Reset NM-UZRS2 to Pending for step-by-step testing');
  await mongoose.disconnect();
}
reset().catch(console.error);
