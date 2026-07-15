const mongoose = require('mongoose');
const Order = require('./src/models/Order');

async function migrate() {
    try {
        await mongoose.connect('mongodb://localhost:27017/namba_db');
        console.log('Connected to DB');

        const omMurugaId = '69cb5a07a8b65d2e86c604a1';
        const nellaiStoreId = '69d0974335d8a9784ca0548e';

        const allOrders = await Order.find({});
        let omCount = 0;
        let nellaiCount = 0;

        for (const order of allOrders) {
            const content = (order.textContent || '').toLowerCase();
            // If the order mentions "OM Muruga", it's for them
            if (content.includes('om muruga')) {
                await Order.updateOne({ _id: order._id }, { $set: { vendor: omMurugaId } });
                omCount++;
            } 
            // If it mentions "nellai store" or "valaikpalam" which was in Dharun's screenshot
            else if (content.includes('nellai store') || content.includes('valaipalam') || content.includes('nai')) {
                await Order.updateOne({ _id: order._id }, { $set: { vendor: nellaiStoreId } });
                nellaiCount++;
            }
        }

        console.log(`Migration Complete:`);
        console.log(`- ${omCount} orders moved to OM Muruga Mess`);
        console.log(`- ${nellaiCount} orders moved to nellai store`);
        
        process.exit(0);
    } catch (err) {
        console.error('Migration Failed:', err);
        process.exit(1);
    }
}

migrate();
