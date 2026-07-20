const mongoose = require('mongoose');

async function cleanOrders() {
  await mongoose.connect('mongodb://localhost:27017/namba_db');
  const db = mongoose.connection.db;
  const col = db.collection('orders');
  
  const updateOp = {};
  updateOp['$set'] = {
    'deliveryCoordinates.coordinates': [77.7172, 11.3410]
  };

  const res = await col.updateMany(
    { 'deliveryCoordinates.coordinates': 80.2707 },
    updateOp
  );

  console.log('Successfully updated Chennai orders in DB:', res);
  process.exit();
}

cleanOrders();
