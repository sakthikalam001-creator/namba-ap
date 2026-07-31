const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost:27017/namba').then(async () => {
  const list = await mongoose.connection.db.collection('vendors').find({}).toArray();
  console.log(JSON.stringify(list, null, 2));
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
