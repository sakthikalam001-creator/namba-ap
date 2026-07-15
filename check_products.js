const mongoose = require('mongoose');
async function run() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    const products = await mongoose.connection.db.collection('products').find({}).toArray();
    console.log('PRODUCTS_COUNT:', products.length);
    console.log('PRODUCTS_DATA:', JSON.stringify(products));
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}
run();
