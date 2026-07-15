const mongoose = require('mongoose');
const Order = require('./models/Order');
require('dotenv').config({ path: './namba_backend/.env' });

async function checkOrder() {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/namba_db');
        const order = await Order.findOne({ displayId: 'NM-WYCFT' }).populate('customer');
        if (order) {
            console.log('Order Found:');
            console.log('ID:', order._id);
            console.log('Customer:', order.customer ? order.customer.name : 'None');
            console.log('Customer Phone:', order.customer ? order.customer.phone : 'None');
            console.log('Status:', order.status);
            console.log('Total Amount:', order.totalAmount);
        } else {
            console.log('Order NM-WYCFT not found');
        }
    } catch (e) {
        console.error(e);
    } finally {
        await mongoose.disconnect();
    }
}

checkOrder();
