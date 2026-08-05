const mongoose = require('./namba_backend/node_modules/mongoose');
const User = require('./namba_backend/src/models/User');

mongoose.connect('mongodb://127.0.0.1:27017/namba').then(async () => {
  const result = await User.updateMany(
    { role: 'driver' },
    { $set: { approvalStatus: 'approved', isAvailable: false } }
  );
  console.log('DRIVERS_APPROVED_COUNT:', result.modifiedCount);
  
  const drivers = await User.find({ role: 'driver' }).select('name phone approvalStatus isAvailable');
  console.log('UPDATED_DRIVERS:', drivers);
  process.exit();
}).catch(err => {
  console.error(err);
  process.exit(1);
});
