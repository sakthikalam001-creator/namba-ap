const mongoose = require('mongoose');
async function run() {
  await mongoose.connect('mongodb://localhost:27017/namba_db');
  const products = await mongoose.connection.db.collection('products').find({}).toArray();
  for (const p of products) {
    console.log(`Product: ${p.name}, Price: ${p.price}, VendorPrice: ${p.vendorPrice}, ID: ${p._id}`);
  }
  process.exit(0);
}
run();
