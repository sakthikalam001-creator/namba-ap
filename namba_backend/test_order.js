const axios = require('axios');

async function testPlaceOrder() {
  try {
    const res = await axios.post('http://localhost:5000/api/v1/orders', {
      customer: '65bdf255d654ed001abc1111',
      vendor: '69cb51b1a8b65d2e86c60488', // Make sure this is a string
      items: [
        { productName: 'Tomato', quantity: 2, price: 30 }
      ],
      totalAmount: 60,
      deliveryCharge: 30,
      paymentMethod: 'COD'
    });
    console.log('Success:', res.data);
  } catch (e) {
    if (e.response) {
      console.error('API Error Response:', JSON.stringify(e.response.data, null, 2));
    } else {
      console.error('Error:', e.message);
    }
  }
}

testPlaceOrder();
