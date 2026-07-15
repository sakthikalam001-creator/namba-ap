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
      customer: { name: 'Manoj Kumar', phone: '+91 9123456789' },
      vendor: vendorId,
      items: [{ productName: 'Milk 1L', quantity: 2, price: 60 }],
      totalAmount: 120,
      status: 'Delivered',
      paymentMethod: 'COD',
      paymentStatus: 'Pending',
      orderType: 'Cart',
      displayId: 'NM-HIST1',
      createdAt: new Date(Date.now() - 86400000) // 1 day ago
    },
    {
      customer: { name: 'Anitha S', phone: '+91 9876543210' },
      vendor: vendorId,
      items: [{ productName: 'Fresh Fruits Pack', quantity: 1, price: 250 }],
      totalAmount: 250,
      status: 'Delivered',
      paymentMethod: 'UPI',
      paymentStatus: 'Completed',
      orderType: 'Cart',
      displayId: 'NM-HIST2',
      createdAt: new Date(Date.now() - 172800000) // 2 days ago
    }
  ];

  await Order.insertMany(mockOrders);
  console.log('✅ Seeded 2 history orders for venkatewara Store');
  process.exit();
}

seed();
