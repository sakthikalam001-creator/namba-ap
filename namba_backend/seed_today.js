const mongoose = require('mongoose');
const MONGODB_URI = 'mongodb://localhost:27017/namba_db';

const OrderSchema = new mongoose.Schema({
  customer: {
    name: String,
    phone: String
  },
  vendor: mongoose.Schema.Types.ObjectId,
  items: Array,
  totalAmount: Number,
  status: String,
  paymentMethod: String,
  paymentStatus: String,
  orderType: String,
  displayId: String,
  createdAt: { type: Date, default: Date.now }
});

const Order = mongoose.model('Order', OrderSchema);

async function seed() {
  await mongoose.connect(MONGODB_URI);
  console.log('Connected to DB');

  const vendorId = '69d4aa645a9966f3f63df870'; // venkatewara Store

  const mockOrders = [
    {
      customer: { name: 'Rajesh K', phone: '+91 9998887776' },
      vendor: vendorId,
      items: [{ productName: 'Fresh Bread', quantity: 1, price: 40 }],
      totalAmount: 40,
      status: 'Delivered',
      paymentMethod: 'COD',
      paymentStatus: 'Pending',
      orderType: 'Cart',
      displayId: 'NM-TODAY1',
      createdAt: new Date() // TODAY
    }
  ];

  await Order.insertMany(mockOrders);
  console.log('✅ Seeded 1 TODAY order for venkatewara Store');
  process.exit();
}

seed();
