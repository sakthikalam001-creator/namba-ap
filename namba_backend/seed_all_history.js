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

  const vendors = [
    '69d0c1e6783ca49b0ee68469', // OM Muruga Mess
    '69d0c21b783ca49b0ee6846e', // Nelai Store
    '69d4aa645a9966f3f63df870'  // venkatewara Store
  ];

  const mockOrders = [];
  vendors.forEach((vendorId, index) => {
    mockOrders.push({
      customer: { name: 'Customer ' + (index + 1), phone: '+91 900000000' + index },
      vendor: vendorId,
      items: [{ productName: 'Mock Item', quantity: 1, price: 100 }],
      totalAmount: 100,
      status: 'Delivered',
      paymentMethod: 'COD',
      paymentStatus: 'Pending',
      orderType: 'Cart',
      displayId: 'NM-HIST-' + index,
      createdAt: new Date()
    });
  });

  await Order.insertMany(mockOrders);
  console.log('✅ Seeded history orders for ALL vendors');
  process.exit();
}

seed();
