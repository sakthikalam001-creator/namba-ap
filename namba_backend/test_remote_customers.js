const axios = require('axios');

async function test() {
  try {
    console.log('Logging in to remote admin...');
    const loginRes = await axios.post('http://100.53.131.76:5000/api/v1/auth/admin-login', {
      email: 'sakthikalam001@gmail.com',
      password: 'Admin@123'
    });
    
    const token = loginRes.data.token;
    console.log('Login successful! Token:', token.substring(0, 15) + '...');
    
    console.log('Fetching customers from remote...');
    const custRes = await axios.get('http://100.53.131.76:5000/api/v1/admin/customers', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    
    console.log('RESPONSE SUCCESS:', custRes.data.success);
    console.log('CUSTOMERS COUNT:', custRes.data.count);
    console.log('CUSTOMERS DATA:', JSON.stringify(custRes.data.data, null, 2));
  } catch (err) {
    console.error('Error occurred:', err.response ? err.response.data : err.message);
  }
}

test();
