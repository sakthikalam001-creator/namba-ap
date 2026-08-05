const mongoose = require('./namba_backend/node_modules/mongoose');
const User = require('./namba_backend/src/models/User');

mongoose.connect('mongodb://127.0.0.1:27017/namba').then(async () => {
  const driver = await User.findById('6a59ff9ced027653b602006f').select('+password');
  console.log('DRIVER_VIKASH:', {
    id: driver._id,
    name: driver.name,
    phone: driver.phone,
    role: driver.role,
    hasPassword: !!driver.password,
    approvalStatus: driver.approvalStatus
  });
  process.exit();
}).catch(err => {
  console.error(err);
  process.exit(1);
});
