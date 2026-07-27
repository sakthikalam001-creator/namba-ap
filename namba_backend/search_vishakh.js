const mongoose = require('mongoose');
const fs = require('fs');

async function search() {
  const conn = await mongoose.createConnection('mongodb://localhost:27017/admin').asPromise();
  const admin = conn.db.admin();
  const dbs = await admin.listDatabases();
  for (const dbInfo of dbs.databases) {
    const name = dbInfo.name;
    if (['admin', 'local', 'config'].includes(name)) continue;
    const dbConn = await mongoose.createConnection('mongodb://localhost:27017/' + name).asPromise();
    const collections = await dbConn.db.listCollections().toArray();
    for (const col of collections) {
      const docs = await dbConn.db.collection(col.name).find({
        $or: [{ name: /Vishakh/i }, { phone: '8883998540' }]
      }).toArray();
      if (docs.length > 0) {
        console.log('Found Vishakh in DB:', name, 'Collection:', col.name, docs);
      }
    }
    await dbConn.close();
  }
  await conn.close();

  const syncPaths = [
    'D:/New folder (2)/namba_shared_db.json',
    'C:/Users/Admin/AppData/Local/Temp/namba_shared_db.json'
  ];
  for (const p of syncPaths) {
    if (fs.existsSync(p)) {
      const file = fs.readFileSync(p, 'utf8');
      if (file.includes('Vishakh') || file.includes('8883998540')) {
        console.log('Found in shared file:', p);
      }
    }
  }
}

search();
