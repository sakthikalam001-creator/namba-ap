const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

async function checkAll() {
  try {
    const adminConn = await mongoose.createConnection('mongodb://localhost:27017/admin').asPromise();
    const adminDb = adminConn.db;
    const dbs = await adminDb.admin().listDatabases();
    console.log('Databases:', dbs.databases.map(d => d.name));
    
    for (const dbInfo of dbs.databases) {
        const name = dbInfo.name;
        if (['admin', 'local', 'config'].includes(name)) continue;
        
        const conn = await mongoose.createConnection(`mongodb://localhost:27017/${name}`).asPromise();
        const collections = await conn.db.listCollections().toArray();
        for (const coll of collections) {
            const count = await conn.db.collection(coll.name).countDocuments();
            if (count > 0) {
                console.log(`- ${name}.${coll.name}: ${count}`);
            }
        }
        await conn.close();
    }
    await adminConn.close();
  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit(0);
  }
}

checkAll();
