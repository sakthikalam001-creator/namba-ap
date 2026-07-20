const mongoose = require('mongoose');
const User = require('./src/models/User');

async function run() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba');
    
    const existing = await User.findOne({ phone: '9750432981' });
    if (existing) {
      console.log('Test customer (samuvel) already exists on AWS!');
      process.exit(0);
    }
    
    const user = await User.create({
      name: 'samuvel',
      phone: '9750432981',
      email: 'samuvel@test.com',
      role: 'customer',
      city: 'Erode',
      isActive: true
    });
    
    console.log('Test customer created successfully on AWS:', user.name);
    process.exit(0);
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
}
run();
