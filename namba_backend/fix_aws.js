require('dotenv').config();
const mongoose = require('mongoose');

async function fixLocation() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;
  const result = await db.collection('vendors').updateMany(
    { storeName: 'OM Muruga Mess' },
    { $set: { 'location.coordinates': [77.7172, 11.3410] } }
  );
  console.log(result);
  await db.collection('vendors').createIndex({ location: '2dsphere' });
  console.log('Index created');
  process.exit(0);
}
fixLocation();
