const mongoose = require('mongoose'); 
mongoose.connect('mongodb://localhost:27017/namba_db').then(async () => { 
  const Vendor = require('./src/models/Vendor'); 
  const lng = 77.7172; 
  const lat = 11.3410; 
  const radius = 20000; 
  const v = await Vendor.aggregate([{ 
    $geoNear: { 
      near: { type: 'Point', coordinates: [lng, lat] }, 
      distanceField: 'distance', 
      maxDistance: radius, 
      spherical: true, 
      query: { approvalStatus: 'approved' } 
    } 
  }]); 
  console.log(JSON.stringify(v, null, 2)); 
  process.exit(0); 
});
