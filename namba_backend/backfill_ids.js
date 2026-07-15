const mongoose = require('mongoose');
const Order = require('./src/models/Order');

async function backfill() {
  await mongoose.connect('mongodb://localhost:27017/namba_db');
  const orders = await Order.find({ displayId: { $exists: false } });
  console.log(`Found ${orders.length} orders to backfill.`);
  
  for (let order of orders) {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let result = '';
    for (let i = 0; i < 5; i++) {
        result += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    order.displayId = `NM-${result}`;
    await order.save();
    console.log(`Backfilled Order ${order._id} with ${order.displayId}`);
  }
  process.exit();
}

backfill();
