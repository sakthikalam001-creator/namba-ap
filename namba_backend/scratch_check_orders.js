const mongoose = require('mongoose');
const Order = require('./src/models/Order');
const User = require('./src/models/User');
const dotenv = require('dotenv');

dotenv.config();

async function check() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba');
  console.log('Connected to DB');
  
  const orders = await Order.find().sort({ createdAt: -1 }).limit(5).populate('customer', 'name phone');
  console.log('Last 5 orders:');
  orders.forEach(o => {
    console.log(`ID: ${o._id}, Display: ${o.displayId}, Status: ${o.status}, Customer: ${o.customer ? o.customer.phone : 'N/A'}, Name: ${o.customer ? o.customer.name : 'N/A'}`);
  });
  
  process.exit(0);
}

check();
