const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '.env') });

const Vendor = require('./src/models/Vendor');

const testUpdate = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db');
    console.log('[Test] Connected to MongoDB');
    
    const id = '69d0c21b783ca49b0ee6846e';
    const isOpen = false;
    
    console.log(`[Test] Attempting to update status to ${isOpen} for ID ${id}...`);
    
    const vendor = await Vendor.findByIdAndUpdate(
      id,
      { isOpen },
      { new: true, runValidators: true }
    );
    
    if (!vendor) {
      console.log('[Test] FAILED: Vendor not found');
    } else {
      console.log(`[Test] SUCCESS: ${vendor.storeName} is now ${vendor.isOpen ? 'ONLINE' : 'OFFLINE'}`);
    }
    
    process.exit(0);
  } catch (err) {
    console.error('[Test Error] Mongoose Error Details:', err.message);
    if (err.errors) {
       Object.keys(err.errors).forEach(key => {
         console.error(`- Field: ${key} | Message: ${err.errors[key].message}`);
       });
    }
    process.exit(1);
  }
};

testUpdate();
