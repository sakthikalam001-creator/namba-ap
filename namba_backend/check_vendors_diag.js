const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '.env') });

const VendorSchema = new mongoose.Schema({
  storeName: String,
  phone: String,
  isOpen: Boolean
});

const Vendor = mongoose.model('Vendor', VendorSchema);

const checkVendors = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db');
    console.log('[Info] Connected to MongoDB');
    
    const vendors = await Vendor.find({});
    console.log(`[Info] Found ${vendors.length} vendors:`);
    vendors.forEach(v => {
      console.log(`ID: ${v._id} | Store: ${v.storeName} | Phone: ${v.phone} | isOpen: ${v.isOpen}`);
    });
    
    process.exit(0);
  } catch (err) {
    console.error('[Error]', err);
    process.exit(1);
  }
};

checkVendors();
