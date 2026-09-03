const mongoose = require('mongoose');
const dotenv = require('dotenv');
dotenv.config();

async function check() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/namba';
  console.log('URI:', uri);
  await mongoose.connect(uri);
  const User = mongoose.model('User', new mongoose.Schema({}, { strict: false }));
  const users = await User.find({ role: 'driver' });
  console.log('DRIVERS_COUNT:', users.length);
  for (const u of users) {
    console.log('DRIVER:', u.name, u.phone, 'DOCS:', JSON.stringify(u.documents));
  }
  process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
