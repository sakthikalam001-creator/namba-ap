const mongoose = require('mongoose');
const User = require('./src/models/User');
const Vendor = require('./src/models/Vendor');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: './.env' });

async function check() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to DB');
  
  const vendors = await Vendor.find({});
  console.log('Total Vendors:', vendors.length);
  vendors.forEach(v => {
    console.log(`Vendor: "${v.storeName}" | Phone: "${v.phone}" | Status: "${v.approvalStatus}"`);
  });
  
  const users = await User.find({ role: 'vendor' });
  console.log('Total Vendor Users:', users.length);
  users.forEach(u => {
    console.log(`User: "${u.name}" | Phone: "${u.phone}"`);
  });

  process.exit();
}

check();
