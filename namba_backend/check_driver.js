const mongoose = require('mongoose');
const User = require('./src/models/User');
require('dotenv').config();

mongoose.connect('mongodb://localhost:27017/namba').then(async () => {
  console.log('--- Database Connected ---');
  const driverId = '6a59ff9ced027653b602006f';
  console.log(`Searching for driver ID: ${driverId}`);
  
  const user = await User.findById(driverId);
  if (!user) {
    console.log('❌ Driver not found by ID! Finding all drivers...');
    const allDrivers = await User.find({ role: 'driver' }).select('_id name phone role');
    console.log('All drivers:', allDrivers);
  } else {
    console.log('✅ Driver found:', {
      _id: user._id,
      name: user.name,
      phone: user.phone,
      role: user.role,
      isOnline: user.isOnline,
      driverApprovalStatus: user.driverApprovalStatus
    });
  }
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
