const mongoose = require('mongoose');
const User = require('./src/models/User');
require('dotenv').config();

mongoose.connect('mongodb://localhost:27017/namba_db').then(async () => {
  const admins = await User.find({ role: { $in: ['admin', 'superadmin'] } });
  console.log('Admins in DB:');
  admins.forEach(a => {
    console.log(JSON.stringify(a, null, 2));
  });
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
