const mongoose = require('mongoose');
const Vendor = require('./src/models/Vendor');
const dotenv = require('dotenv');

dotenv.config({ path: './.env' });

async function grantTrial() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to DB');
  
  const expiryDate = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000); // 14 days from now
  
  const result = await Vendor.updateMany(
    { 
      $or: [
        { trialExpiry: { $exists: false } },
        { trialExpiry: { $lt: new Date() } }
      ]
    },
    { 
      $set: { 
        trialExpiry: expiryDate,
        isSubscribed: false // Ensure they are on trial
      } 
    }
  );
  
  console.log(`Updated ${result.modifiedCount} vendors with 14-day trial.`);
  process.exit();
}

grantTrial();
