const mongoose = require('mongoose');

async function checkOrders() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    const OrderSchema = new mongoose.Schema({}, { strict: false });
    const Order = mongoose.model('Order', OrderSchema);
    
    const orders = await Order.find({}).select('displayId status').sort({ createdAt: -1 }).limit(10);
    console.log('Recent Orders:');
    orders.forEach(o => {
      console.log(`- ${o.displayId}: ${o.status}`);
    });
    
    await mongoose.disconnect();
  } catch (err) {
    console.error(err);
  }
}

checkOrders();
