const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost:27017/namba').then(async () => {
  const vendor = await mongoose.connection.db.collection('vendors').findOne({_id: new mongoose.Types.ObjectId('6a57aefb16962c32adc0341c')});
  console.log("VENDOR DATA:");
  console.log(JSON.stringify(vendor, null, 2));
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
