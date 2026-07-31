const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost:27017/namba_db').then(async () => {
  const { ObjectId } = require('mongodb');
  const v = await mongoose.connection.db.collection('vendors').findOne({_id: new ObjectId('6a57aefb16962c32adc0341c')});
  console.log(JSON.stringify(v, null, 2));
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
