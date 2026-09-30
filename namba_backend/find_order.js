const mongoose = require('mongoose');
require('dotenv').config({ path: './.env' });
const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/namba';
console.log('Connecting to', uri.split('@').pop());
mongoose.connect(uri).then(async () => {
  const Order = mongoose.connection.collection('orders');
  const o = await Order.findOne({ displayId: /GW2CL/i });
  if (!o) {
    const last = await Order.find().sort({ _id: -1 }).limit(3).toArray();
    console.log('Not found. Last orders:', last.map(x => ({ id: x._id, displayId: x.displayId, totalAmount: x.totalAmount, subTotal: x.subTotal, discount: x.discount, deliveryCharge: x.deliveryCharge, customerPlatformFee: x.customerPlatformFee, platformFee: x.platformFee, status: x.status })));
  } else {
    console.log('Order found:', JSON.stringify(o, null, 2));
  }
  process.exit(0);
}).catch(err => { console.error(err); process.exit(1); });
