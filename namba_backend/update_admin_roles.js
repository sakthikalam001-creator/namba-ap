const mongoose = require('mongoose');
const User = require('./src/models/User');
require('dotenv').config();

mongoose.connect('mongodb://localhost:27017/namba_db').then(async () => {
  console.log('Updating Admin Roles...');
  
  const kayal = await User.findOneAndUpdate(
    { email: 'kayalbsc2000@gmail.com' },
    { $set: { role: 'admin', name: 'Kayal' } },
    { new: true }
  );
  if (kayal) console.log(`Updated Kayal: ${kayal.email} -> ${kayal.role}, ${kayal.name}`);
  
  const sakthi = await User.findOneAndUpdate(
    { email: 'sakthikalam001@gmail.com' },
    { $set: { role: 'superadmin', name: 'Sakthi' } },
    { new: true }
  );
  if (sakthi) console.log(`Updated Sakthi: ${sakthi.email} -> ${sakthi.role}, ${sakthi.name}`);

  const adminUser = await User.findOneAndUpdate(
    { email: 'admin@namba.in' },
    { $set: { name: 'Admin Karthi' } }, // giving the placeholder a better name
    { new: true }
  );
  if (adminUser) console.log(`Updated Admin User: ${adminUser.email} -> ${adminUser.role}, ${adminUser.name}`);
  
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
