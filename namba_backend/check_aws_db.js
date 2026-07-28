const mongoose = require('mongoose');

async function check() {
  try {
    await mongoose.connect('mongodb://100.50.39.221:27017/namba_db', {
      serverSelectionTimeoutMS: 5000
    });
    console.log('Connected to AWS MongoDB');
    const Vendor = mongoose.model('Vendor', new mongoose.Schema({}, { strict: false }));
    const v = await Vendor.findOne({ _id: '6a57aefb16962c32adc0341c' });
    console.log('Vendor:', v);
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    mongoose.disconnect();
  }
}
check();
