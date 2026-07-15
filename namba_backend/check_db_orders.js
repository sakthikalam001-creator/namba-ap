const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');

// Load env vars
dotenv.config();

const OrderSchema = new mongoose.Schema({}, { strict: false });
const Order = mongoose.model('Order', OrderSchema);

const checkOrders = async () => {
  try {
    const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/namba';
    console.log(`Connecting to: ${mongoUri}`);
    await mongoose.connect(mongoUri);
    const count = await Order.countDocuments();
    console.log(`Total Orders in Database: ${count}`);
    
    if (count > 0) {
        const sample = await Order.findOne();
        console.log('Sample Order ID:', sample._id);
    }
    
    process.exit(0);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
};

checkOrders();
