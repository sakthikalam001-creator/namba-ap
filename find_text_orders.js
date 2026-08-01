const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost:27017/namba').then(async () => {
  const order = await mongoose.connection.db.collection('orders').findOne({ displayId: 'NM-47UAE' });
  console.log(JSON.stringify(order, null, 2));
  process.exit(0);
});
