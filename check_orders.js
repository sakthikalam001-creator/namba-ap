const mongoose = require('mongoose');
const User = require('../src/models/User');
const Order = require('../src/models/Order');
require('dotenv').config();

const check = async () => {
  await mongoose.connect(process.env.MONGO_URI);
  
  const arun = await User.findOne({ name: /arun/i });
  if (!arun) {
    console.log('Arun not found');
    process.exit();
  }
  console.log('Arun ID:', arun._id);
  
  const deliveredOrders = await Order.countDocuments({ 
    driver: arun._id, 
    status: 'Delivered' 
  });
  console.log('Delivered Orders count:', deliveredOrders);
  
  const allOrders = await Order.countDocuments({ 
    driver: arun._id
  });
  console.log('All Orders count for Arun:', allOrders);

  const statuses = await Order.distinct('status', { driver: arun._id });
  console.log('Order statuses for Arun:', statuses);

  process.exit();
};

check();
