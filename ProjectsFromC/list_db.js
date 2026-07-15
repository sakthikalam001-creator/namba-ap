const mongoose = require('mongoose');

async function listCollections() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba_db');
    const collections = await mongoose.connection.db.listCollections().toArray();
    console.log('Collections:');
    collections.forEach(c => console.log(`- ${c.name}`));
    
    // Also check if there are any users or vendors
    const count = async (name) => {
      const col = mongoose.connection.db.collection(name);
      return await col.countDocuments();
    };
    
    console.log('Counts:');
    for (const c of collections) {
      console.log(`- ${c.name}: ${await count(c.name)}`);
    }

    await mongoose.disconnect();
  } catch (err) {
    console.error(err);
  }
}

listCollections();
