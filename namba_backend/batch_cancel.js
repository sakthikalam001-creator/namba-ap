const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const Order = require('./src/models/Order');

async function run() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba');
    console.log('Connected.');

    const activeStatuses = ['Pending', 'Accepted', 'Preparing', 'Ready', 'Assigned', 'HandedOver', 'PickedUp', 'OutForDelivery', 'Confirmed', 'PaymentPending'];

    const activeOrders = await Order.find({ status: { $in: activeStatuses } });
    console.log(`Found ${activeOrders.length} active orders to cancel.`);

    if (activeOrders.length === 0) {
      console.log('No active orders to cancel.');
      process.exit(0);
    }

    const result = await Order.updateMany(
      { status: { $in: activeStatuses } },
      {
        $set: {
          status: 'Cancelled',
          cancelledBy: 'Admin',
          cancellationReason: 'Admin Batch Cancel'
        }
      }
    );

    console.log(`Success! Updated ${result.modifiedCount} orders to Cancelled.`);
    process.exit(0);
  } catch (error) {
    console.error('Error during batch cancel:', error);
    process.exit(1);
  }
}

run();
