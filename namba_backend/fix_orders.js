const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

// Define a minimal schema to work with
const OrderSchema = new mongoose.Schema({}, { strict: false });
const Order = mongoose.model('Order', OrderSchema);

async function fix() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to DB:', process.env.MONGODB_URI);
    
    const orders = await Order.find({}).sort({ createdAt: -1 });
    console.log(`Total orders found: ${orders.length}`);
    
    if (orders.length > 1) {
      const toKeep = orders[0];
      console.log(`Keeping the latest order: ${toKeep._id} (Display ID: ${toKeep.displayId})`);
      
      const result = await Order.deleteMany({ _id: { $ne: toKeep._id } });
      console.log(`Successfully deleted ${result.deletedCount} duplicate/test orders.`);
    } else {
      console.log('No action needed. Current order count is 1 or less.');
    }
  } catch (err) {
    console.error('Error during database cleanup:', err);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

fix();
