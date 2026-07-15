const mongoose = require('mongoose');
const Order = require('./namba_backend/src/models/Order'); // guessing path
require('dotenv').config({ path: './namba_backend/.env' });

const check = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    const order = await Order.findOne({ displayId: 'NM-LRQ3F' });
    if (!order) {
      console.log('Order not found');
      process.exit();
    }
    console.log('Order billPhotoPath:', order.billPhotoPath);
    console.log('Order object:', order);
  } catch (err) {
    console.error(err);
  }
  process.exit();
};

check();
