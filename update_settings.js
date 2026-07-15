const mongoose = require('mongoose');
async function run() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    // Set a very large radius and a center in Chennai (typical for user)
    const result = await mongoose.connection.db.collection('settings').updateOne({}, { 
      $set: { 
        serviceCenterLat: 13.0827, 
        serviceCenterLng: 80.2707, 
        maxServiceRadiusKm: 1000 
      } 
    });
    console.log('Updated settings:', result);
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}
run();
