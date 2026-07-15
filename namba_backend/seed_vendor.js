const mongoose = require('mongoose');

async function seed() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  console.log('Connected to MongoDB');

  const Vendor = mongoose.model('Vendor', new mongoose.Schema({
    storeName: String,
    ownerName: String,
    category: String,
    location: {
      type: { type: String, default: 'Point' },
      coordinates: [Number]
    },
    isOpen: { type: Boolean, default: true }
  }));

  // Clean old
  await Vendor.deleteMany({});

  // Seed one Vendor with the ID matched in our Flutter Apps
  const result = await Vendor.create({
    _id: new mongoose.Types.ObjectId('69cb51b1a8b65d2e86c60488'),
    storeName: 'Chennai Super Grocery',
    ownerName: 'Admin',
    category: 'Grocery',
    location: {
      type: 'Point',
      coordinates: [80.2707, 13.0827] // Chennai coordinates
    },
    isOpen: true
  });

  console.log('Seeded Vendor:', result.storeName, result._id);
  process.exit(0);
}

seed().catch(err => {
  console.error(err);
  process.exit(1);
});
