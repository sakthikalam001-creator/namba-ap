const mongoose = require('mongoose');
const dotenv = require('dotenv');
dotenv.config();

async function query() {
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/namba_db');
  console.log('Connected to DB');
  
  require('./src/models/User');
  require('./src/models/Vendor');
  const Order = require('./src/models/Order');
  const order = await Order.findOne({ displayId: 'NM-5ZGPS' })
    .populate('customer')
    .populate('vendor')
    .populate('driver');
  
  console.log(JSON.stringify(order, null, 2));
  
  await mongoose.disconnect();
}

query();
