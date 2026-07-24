const mongoose = require('mongoose');
require('dotenv').config();

async function fix() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db';
  console.log('Connecting to:', uri);
  await mongoose.connect(uri);
  const result = await mongoose.connection.db.collection('orders').updateMany(
    { status: 'PaymentPending' },
    { $set: { status: 'Pending' } }
  );
  console.log('Successfully updated existing PaymentPending orders count:', result.modifiedCount);
  await mongoose.disconnect();
}
fix().catch(console.error);
