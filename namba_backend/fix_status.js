const mongoose = require('mongoose');
const Order = require('./src/models/Order');

async function fixStatus() {
    try {
        await mongoose.connect('mongodb://localhost:27017/namba_db');
        console.log('Connected to DB');

        const result = await Order.updateMany(
            { status: 'HandedOver' }, 
            { $set: { status: 'Delivered' } }
        );

        console.log(`Successfully fixed ${result.modifiedCount} orders!`);
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

fixStatus();
