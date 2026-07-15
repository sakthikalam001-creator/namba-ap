const mongoose = require('mongoose');

async function checkOnlineDriver() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    const UserSchema = new mongoose.Schema({}, { strict: false });
    const User = mongoose.model('User', UserSchema);
    
    const driver = await User.findOne({ role: 'driver', isOnline: true });
    if (driver) {
      console.log(`Online Driver: ${driver.name} (${driver.phone}) ID: ${driver._id}`);
    } else {
      console.log('No drivers are online.');
    }
    
    await mongoose.disconnect();
  } catch (err) {
    console.error(err);
  }
}

checkOnlineDriver();
