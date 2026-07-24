require('dotenv').config();
const mongoose = require('mongoose');
async function run() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;
  const result = await db.collection('vendors').updateMany(
    { storeName: 'OM Muruga Mess' },
    { $set: { 'location.coordinates': [77.68268679903626, 11.337584613937478] } }
  );
  console.log(result);
  process.exit(0);
}
run();
