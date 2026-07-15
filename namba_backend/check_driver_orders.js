const mongoose = require('mongoose');
const Order = require('./src/models/Order');

async function check() {
  await mongoose.connect('mongodb://localhost:27017/namba_db');
  const driverId = '69d5efb4581e5e14b3605920'; // Arun's ID from json
  const orders = await Order.find({ driver: driverId });
  console.log(JSON.stringify(orders, null, 2));
  await mongoose.disconnect();
}
check();
