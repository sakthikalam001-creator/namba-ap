const mongoose = require('mongoose');

async function checkDrivers() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    const UserSchema = new mongoose.Schema({}, { strict: false });
    const User = mongoose.model('User', UserSchema);
    
    const total = await User.countDocuments({ role: 'driver' });
    const online = await User.countDocuments({ role: 'driver', isOnline: true });
    const approved = await User.countDocuments({ role: 'driver', driverApprovalStatus: 'approved' });
    const pending = await User.countDocuments({ role: 'driver', driverApprovalStatus: 'pending' });
    
    console.log(`Total Drivers: ${total}`);
    console.log(`Online Drivers: ${online}`);
    console.log(`Approved Drivers: ${approved}`);
    console.log(`Pending Approval: ${pending}`);
    
    if (online === 0) {
      console.log('TIP: Drivers need to go online in the app!');
    }
    
    await mongoose.disconnect();
  } catch (err) {
    console.error(err);
  }
}

checkDrivers();
