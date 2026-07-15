const mongoose = require('mongoose');
const Order = require('./src/models/Order');
require('dotenv').config();

async function checkOrder() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba');
  const order = await Order.findOne({ displayId: 'NM-DBA57' });
  if (order) {
    console.log('Order Items:', JSON.stringify(order.items, null, 2));
    console.log('Delivery Address Formatted:', order.deliveryAddressFormatted);
  } else {
    const order2 = await Order.findById('NM-DBA57').catch(() => null);
    if (order2) {
        console.log('Order Items:', JSON.stringify(order2.items, null, 2));
    } else {
        console.log('Order not found');
    }
  }
  process.exit();
}

checkOrder();
