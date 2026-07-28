const http = require('http');
http.get('http://100.50.39.221:5000/api/v1/orders/vendor/6a57aefb16962c32adc0341c', res => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => {
    const data = JSON.parse(body).data;
    const pending = data.find(o => o.status === 'Pending');
    console.log(JSON.stringify(pending, null, 2));
  });
});
