const http = require('http');

const data = JSON.stringify({
  customer: '69c5c72e2938491001f3e0f2', // Dummy valid looking objectId
  vendor: '69d0c1e6783ca49b0ee68469',
  items: [],
  totalAmount: 58,
  deliveryCharge: 30,
  paymentMethod: 'COD',
  orderType: 'Cart'
});

const options = {
  hostname: 'localhost',
  port: 5000,
  path: '/api/v1/orders',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data)
  }
};

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
