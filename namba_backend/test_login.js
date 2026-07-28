const http = require('http');
const data = JSON.stringify({ phone: '9876543212', password: 'vendor123' });
const req = http.request({
  hostname: '100.50.39.221',
  port: 5000,
  path: '/api/v1/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
}, res => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => console.log(body));
});
req.on('error', e => console.error(e));
req.write(data);
req.end();
