
const mongoose = require('./namba_backend/node_modules/mongoose');
async function check() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;
  const vendorUser = await db.collection('users').findOne({ phone: '7530032959', role: 'vendor' });
  console.log('Vendor User:', vendorUser);
  process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
