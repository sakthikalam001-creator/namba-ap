
const mongoose = require('./namba_backend/node_modules/mongoose');
async function check() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  const db = mongoose.connection.db;
  const users = await db.collection('users').find({}).toArray();
  console.log('=== USERS (' + users.length + ') ===');
  users.forEach(u => console.log('User ID:', u._id, '| Phone:', u.phone, '| Role:', u.role, '| Name:', u.name, '| hasPass:', !!u.password));
  
  const vendors = await db.collection('vendors').find({}).toArray();
  console.log('=== VENDORS (' + vendors.length + ') ===');
  vendors.forEach(v => console.log('Vendor ID:', v._id, '| Phone:', v.phone, '| Name:', v.storeName, '| approvalStatus:', v.approvalStatus, '| user:', v.user));
  process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
