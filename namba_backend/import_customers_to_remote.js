const mongoose = require('mongoose');
const User = require('./src/models/User');

const localCustomers = [
  {
    "_id": "69ef0171bfff658dbc539f64",
    "name": "Guest Customer",
    "phone": "0000000000",
    "role": "customer",
    "driverApprovalStatus": "pending",
    "isActive": true,
    "isOnline": false,
    "createdAt": "2026-04-27T06:25:53.531Z",
    "updatedAt": "2026-04-27T06:25:53.531Z",
    "__v": 0
  },
  {
    "_id": "69f1b58419faea0a29523815",
    "name": "samuvel",
    "phone": "9750432981",
    "role": "customer",
    "driverApprovalStatus": "pending",
    "isActive": true,
    "isOnline": false,
    "createdAt": "2026-04-29T07:38:44.073Z",
    "updatedAt": "2026-04-29T07:38:44.073Z",
    "__v": 0
  },
  {
    "_id": "6a2290c1c15bd703f8101c2a",
    "name": "shanmugam",
    "phone": "9442733603",
    "role": "customer",
    "driverApprovalStatus": "pending",
    "isActive": true,
    "isOnline": false,
    "createdAt": "2026-06-05T09:02:57.921Z",
    "updatedAt": "2026-06-05T09:02:57.921Z",
    "__v": 0
  },
  {
    "_id": "6a4f2200e7c556756cfe710d",
    "name": "Guest Customer",
    "phone": "9123456789",
    "role": "customer",
    "driverApprovalStatus": "pending",
    "isActive": true,
    "isOnline": false,
    "createdAt": "2026-07-09T04:22:24.881Z",
    "updatedAt": "2026-07-09T04:22:24.881Z",
    "__v": 0
  },
  {
    "_id": "6a578063ec17fcac2e26ce99",
    "name": "Kalam",
    "phone": "9750432982",
    "role": "customer",
    "driverApprovalStatus": "pending",
    "isActive": true,
    "isOnline": false,
    "createdAt": "2026-07-15T12:43:15.497Z",
    "updatedAt": "2026-07-15T12:43:15.497Z",
    "__v": 0
  }
];

async function run() {
  try {
    await mongoose.connect('mongodb://localhost:27017/namba');
    console.log('Connected to remote MongoDB database "namba"');

    for (const customer of localCustomers) {
      // Check if user already exists on AWS by ID or Phone
      const existing = await User.findOne({ 
        $or: [
          { _id: customer._id },
          { phone: customer.phone }
        ]
      });

      if (existing) {
        console.log(`Customer ${customer.name} (${customer.phone}) already exists on AWS. Updating details...`);
        existing.name = customer.name;
        existing.role = 'customer';
        existing.isActive = customer.isActive;
        await existing.save();
      } else {
        console.log(`Creating customer ${customer.name} (${customer.phone}) on AWS...`);
        await User.create(customer);
      }
    }

    console.log('Database migration completed successfully!');
    process.exit(0);
  } catch (e) {
    console.error('Migration failed:', e.message);
    process.exit(1);
  }
}

run();
