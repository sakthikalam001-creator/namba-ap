const mongoose = require('mongoose');
async function run() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    const settings = await mongoose.connection.db.collection('settings').findOne();
    const zones = await mongoose.connection.db.collection('servicezones').find({isActive: true}).toArray();
    console.log('SETTINGS_DATA:', JSON.stringify(settings));
    console.log('ZONES_DATA:', JSON.stringify(zones));
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}
run();
