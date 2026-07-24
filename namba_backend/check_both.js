const mongoose = require('mongoose');
require('dotenv').config();

async function check() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db';
  await mongoose.connect(uri);
  const o1 = await mongoose.connection.db.collection('orders').findOne({ displayId: 'NM-R3G2B' });
  const o2 = await mongoose.connection.db.collection('orders').findOne({ displayId: 'NM-UZRS2' });
  console.log('NM-R3G2B Status:', o1 ? o1.status : 'null');
  console.log('NM-UZRS2 Status:', o2 ? o2.status : 'null');
  await mongoose.disconnect();
}
check().catch(console.error);
