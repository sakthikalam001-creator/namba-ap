const mongoose = require('mongoose');
const User = require('./src/models/User');
const Vendor = require('./src/models/Vendor');
const dotenv = require('dotenv');

dotenv.config({ path: './.env' });

async function seed() {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db');
    console.log('Connected to DB successfully');

    const phone = '9876543212';
    
    // Check if user already exists
    let user = await User.findOne({ phone });
    if (user) {
      console.log('User already exists, deleting first to reset...');
      await User.deleteOne({ phone });
      await Vendor.deleteOne({ phone });
    }

    // Create User
    user = await User.create({
      name: 'Namba Test Owner',
      phone: phone,
      email: 'testvendor@namba.in',
      role: 'vendor',
      password: 'password', // will be hashed by mongoose pre hook
      city: 'Erode',
    });
    console.log('Created User:', user);

    // Create Vendor
    const vendor = await Vendor.create({
      user: user._id,
      storeName: 'OM Muruga Mess',
      ownerName: 'Namba Test Owner',
      phone: phone,
      category: 'Food',
      address: '123 Main Street, Erode',
      approvalStatus: 'approved',
      approvedAt: new Date(),
      isOpen: true,
      subscriptionPlan: 'Premium',
      isSubscribed: true,
      trialExpiry: new Date('2030-01-01'),
      subscriptionExpiry: new Date('2030-01-01'),
      location: {
        type: 'Point',
        coordinates: [77.7172, 11.3410],
        formattedAddress: '123 Main Street, Erode',
        city: 'Erode',
        pincode: '638001'
      },
      permissions: {
        allowAutoAccept: true,
        allowSurgeBoost: true,
        allowExtraWait: true
      }
    });
    console.log('Created Vendor profile:', vendor);

    console.log('Seeding Done successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Seeding error:', err);
    process.exit(1);
  }
}

seed();
