const mongoose = require('mongoose');
const dotenv = require('dotenv');
dotenv.config();

async function query() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db');
  console.log('Connected to DB');
  
  const Order = require('./src/models/Order');
  const orders = await Order.find({});
  console.log('Orders found in DB:', orders.length);
  orders.forEach(o => {
    console.log(`id: ${o._id}, displayId: ${o.displayId}, status: ${o.status}, storeName: ${o.storeName}`);
  });
  
  await mongoose.disconnect();
}

query();
