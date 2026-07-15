const mongoose = require('mongoose');
const Order = require('./src/models/Order');
require('dotenv').config();

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
