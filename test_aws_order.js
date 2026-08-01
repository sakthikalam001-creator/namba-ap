const http = require('http');

const data = JSON.stringify({
  customer: '69c5c72e2938491001f3e0f2', // Dummy valid customer ID
  vendor: '6a57aefb16962c32adc0341c',   // OM Muruga Mess Vendor ID (active push token registered)
  items: [
    {
      productName: 'Fresh Tomato',
      price: 40,
      quantity: 2
    }
  ],
  totalAmount: 110,
  deliveryCharge: 30,
  paymentMethod: 'COD',
  orderType: 'Cart',
  deliveryAddress: 'Erode Bus Stand, Erode',
  deliveryCoordinates: { lat: 11.3410, lng: 77.7172 } // Default Erode center (geofence pass)
});

const options = {
  hostname: '54.204.9.126',
  port: 5000,
  path: '/api/v1/orders',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data)
  }
};

console.log('Sending test order to AWS server (54.204.9.126) for OM Muruga Mess...');
const req = http.request(options, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    console.log(`STATUS: ${res.statusCode}`);
    console.log(`BODY: ${body}`);
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

req.write(data);
req.end();
