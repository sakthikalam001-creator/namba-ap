const mongoose = require('mongoose');
const User = require('./src/models/User');
require('dotenv').config();

mongoose.connect('mongodb://localhost:27017/namba_db').then(async () => {
  console.log('Checking drivers in DB...');
  
  const drivers = await User.find({ role: 'driver' }).select('name phone isOnline driverApprovalStatus');
  console.log(JSON.stringify(drivers, null, 2));

  // Reset them to offline for testing
  await User.updateMany({ role: 'driver' }, { $set: { isOnline: false } });
  console.log('Reset all drivers to offline (isOnline: false).');
  
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
