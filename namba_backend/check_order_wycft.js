const mongoose = require('mongoose');
const Order = require('./src/models/Order');
const User = require('./src/models/User');

async function check() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_ecosystem');
    console.log('Connected to DB');

    const order = await Order.findOne({ displayId: 'NM-PBZHH' });
    if (!order) {
      console.log('Order NM-PBZHH not found');
      return;
    }

    console.log('Order Details:');
    console.log('ID:', order._id);
    console.log('Display ID:', order.displayId);
    console.log('Status:', order.status);
    console.log('Driver:', order.driver);
    
    if (order.driver) {
        const driver = await User.findById(order.driver);
        console.log('Driver Details:', driver ? driver.name : 'Unknown');
    }

  } catch (err) {
    console.error(err);
  } finally {
    await mongoose.disconnect();
  }
}

check();
