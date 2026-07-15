const mongoose = require('mongoose');
const User = require('./src/models/User');

async function check() {
  await mongoose.connect('mongodb://localhost:27017/namba_db');
  const users = await User.find({ role: 'driver' }, { name: 1, phone: 1, isOnline: 1, driverApprovalStatus: 1 });
  console.log(JSON.stringify(users, null, 2));
  await mongoose.disconnect();
}
check();
