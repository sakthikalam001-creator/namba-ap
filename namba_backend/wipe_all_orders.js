const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '.env') });

async function wipe() {
  try {
    // 1. Wipe MongoDB orders
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB:', process.env.MONGODB_URI);
    const db = mongoose.connection.db;
    const result = await db.collection('orders').deleteMany({});
    console.log(`Wiped ${result.deletedCount} orders from MongoDB 'orders' collection.`);
    
    // Also check other potential databases
    const adminConn = await mongoose.createConnection('mongodb://localhost:27017/admin').asPromise();
    const dbs = await adminConn.db.admin().listDatabases();
    for (const dbInfo of dbs.databases) {
        const name = dbInfo.name;
        if (['admin', 'local', 'config'].includes(name)) continue;
        const conn = await mongoose.createConnection(`mongodb://localhost:27017/${name}`).asPromise();
        const r = await conn.db.collection('orders').deleteMany({});
        if (r.deletedCount > 0) {
            console.log(`Wiped ${r.deletedCount} orders from ${name}.orders`);
        }
        await conn.close();
    }
    await adminConn.close();
    await mongoose.disconnect();

    // 2. Wipe Shared DB JSON
    const tempPath = process.env.TEMP || process.env.TMP || '/tmp';
    const sharedDbPath = path.join(tempPath, 'namba_shared_db.json');
    if (fs.existsSync(sharedDbPath)) {
        fs.writeFileSync(sharedDbPath, JSON.stringify([]));
        console.log(`Wiped shared_db at ${sharedDbPath}`);
    }

    console.log('✅ ALL ORDERS WIPED SUCCESSFULLY.');
  } catch (err) {
    console.error('Error during wipe:', err);
  } finally {
    process.exit(0);
  }
}

wipe();
