require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./src/models/User');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/namba_db';

const checkAdmin = async () => {
  try {
    await mongoose.connect(MONGO_URI);
    
    const email = 'kayalbsc2000@gmail.com';
    const pwd = '123456';
    
    let admin = await User.findOne({ email });
    if (!admin) {
      console.log('Creating Kayal admin...');
      admin = await User.create({
        name: 'Kayal',
        phone: '9999999901', // Placeholder unique phone
        email: email,
        password: pwd,
        role: 'superadmin',
        city: 'Chennai'
      });
      console.log('Admin Kayal created successfully!');
    } else {
      console.log('Admin Kayal already exists. Updating role to superadmin & resetting password explicitly...');
      admin.role = 'superadmin';
      admin.password = pwd; // Will be hashed via pre-save hook
      await admin.save();
      console.log('Admin Kayal updated successfully!');
    }
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
};

checkAdmin();
