const mongoose = require('mongoose');

const mongoUri = 'mongodb://localhost:27017/namba_db';

async function listCollections() {
  try {
    await mongoose.connect(mongoUri);
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('Collections:', collections.map(c => c.name));
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

listCollections();
