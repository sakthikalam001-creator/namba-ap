const mongoose = require('mongoose');
require('dotenv').config();

const MONGO_URI = 'mongodb://localhost:27017/namba_db'; 

const OrderSchema = new mongoose.Schema({
  displayId: String,
  status: String,
  vendor: mongoose.Schema.Types.ObjectId,
  customer: mongoose.Schema.Types.ObjectId,
  driver: mongoose.Schema.Types.ObjectId,
  orderType: String,
  createdAt: Date
});

const Order = mongoose.model('Order', OrderSchema);

async function checkOrders() {
  await mongoose.connect(MONGO_URI);
  console.log('--- DB ORDER CHECK ---');
  
  const idsToCheck = ['NM-09913', 'NM-50931'];
  
  for (const id of idsToCheck) {
    const order = await Order.findOne({ displayId: id });
    if (order) {
      console.log(`✅ Order ${id} found: Status=${order.status}, CreatedAt=${order.createdAt}`);
    } else {
      console.log(`❌ Order ${id} NOT FOUND in DB`);
    }
  }

  const allActive = await Order.find({ 
    status: { $in: ['Pending', 'Accepted', 'Preparing', 'Ready', 'Assigned', 'PickedUp', 'OutForDelivery'] } 
  });
  console.log(`\nFound ${allActive.length} active orders in total:`);
  allActive.sort((a, b) => b.createdAt - a.createdAt);
  allActive.forEach(o => console.log(`- ${o.displayId}: ${o.status} (Created: ${o.createdAt})`));
  
  await mongoose.disconnect();
}

checkOrders().catch(console.error);
