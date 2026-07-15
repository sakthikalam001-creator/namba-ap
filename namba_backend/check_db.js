const mongoose = require('mongoose');
const User = require('./src/models/User');
require('dotenv').config();

mongoose.connect(process.env.MONGODB_URI).then(async () => {
  const drivers = await User.find({ role: 'driver' });
  console.log('Drivers in DB:', drivers.length);
  console.log(drivers);
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
