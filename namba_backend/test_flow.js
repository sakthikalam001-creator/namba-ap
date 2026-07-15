const io = require('socket.io-client');
const axios = require('axios');

const BACKEND_URL = 'http://localhost:5000';
const CUSTOMER_ID = '65bdf255d654ed001abc1111';
const VENDOR_ID = '69cb51b1a8b65d2e86c60488';

async function runDemo() {
  console.log('🔄 Connecting Sockets...');
  
  // 1. Connect Vendor & Customer Sockets
  const vendorSocket = io(BACKEND_URL);
  const customerSocket = io(BACKEND_URL);

  vendorSocket.on('connect', () => {
    vendorSocket.emit('join_room', `vendor_${VENDOR_ID}`);
    console.log('✅ Vendor Socket Connected & Listening to vendor_' + VENDOR_ID);
  });

  customerSocket.on('connect', () => {
    customerSocket.emit('join_room', `customer_${CUSTOMER_ID}`);
    console.log('✅ Customer Socket Connected & Listening to customer_' + CUSTOMER_ID);
  });

  // 2. Listeners
  vendorSocket.on('new_order_alert', (orderData) => {
    console.log('\n📱 VENDOR APP: 🔔 New Order Incoming! \n', JSON.stringify(orderData, null, 2));
  });

  customerSocket.on('order_status_update', (statusData) => {
    console.log('\n📱 CUSTOMER APP: 🔔 Order Status Updated! \n', JSON.stringify(statusData, null, 2));
  });

  // Wait 2s for connections
  await new Promise(r => setTimeout(r, 2000));

  console.log('\n--- 🛒 1. CUSTOMER PLACES ORDER ---');
  let placedOrder;
  try {
    const res = await axios.post(`${BACKEND_URL}/api/v1/orders`, {
      customer: CUSTOMER_ID,
      vendor: VENDOR_ID,
      items: [{ productName: 'Fresh Milk', quantity: 2, price: 30 }],
      totalAmount: 60,
      deliveryCharge: 30,
      paymentMethod: 'COD'
    });
    placedOrder = res.data.data;
    console.log('API Response (Success): Order ID =', placedOrder._id);
  } catch(e) { console.error('Error placing order:', e.message); }

  await new Promise(r => setTimeout(r, 2000));

  console.log('\n--- 🏪 2. VENDOR ACCEPTS ORDER ---');
  try {
    await axios.put(`${BACKEND_URL}/api/v1/orders/${placedOrder._id}/status`, {
      status: 'Preparing'
    });
    console.log(`API Response (Success): Updated Order to 'Preparing'`);
  } catch(e) { console.error(e.message); }

  await new Promise(r => setTimeout(r, 2000));
  
  console.log('\n--- 🏍 3. VENDOR HANDS OVER TO DRIVER ---');
  try {
    await axios.put(`${BACKEND_URL}/api/v1/orders/${placedOrder._id}/status`, {
      status: 'OutForDelivery'
    });
    console.log(`API Response (Success): Updated Order to 'OutForDelivery'`);
  } catch(e) { console.error(e.message); }

  await new Promise(r => setTimeout(r, 2000));
  console.log('\n🎉 DEMO FINISHED 🎉');
  process.exit(0);
}

runDemo();
