const mongoose = require('mongoose');
async function run() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    const users = await mongoose.connection.db.collection('users').find({ role: 'customer' }).toArray();
    console.log('CUSTOMERS_DATA:', JSON.stringify(users));
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}
run();
