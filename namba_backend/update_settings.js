const mongoose = require('mongoose');
async function run() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    // Set a very large radius and a center in Erode
    const result = await mongoose.connection.db.collection('settings').updateOne({}, { 
      $set: { 
        serviceCenterLat: 11.3410, 
        serviceCenterLng: 77.7172, 
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
