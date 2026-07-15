const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');

const mongoUri = 'mongodb://localhost:27017/namba_db';
const jsonPath = 'D:/New folder (2)/namba_shared_db.json';

async function clearAll() {
  try {
    // 1. Clear MongoDB
    console.log('Connecting to MongoDB...');
    await mongoose.connect(mongoUri);
    console.log('Clearing orders collection...');
    await mongoose.connection.db.collection('orders').deleteMany({});
    console.log('MongoDB orders cleared.');

    // 2. Clear JSON File
    console.log('Clearing JSON file...');
    fs.writeFileSync(jsonPath, '[]');
    console.log('JSON file cleared.');

    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

clearAll();
