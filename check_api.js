const axios = require('axios');

const check = async () => {
  try {
    const res = await axios.get('http://100.53.131.76:5000/api/v1/admin/drivers');
    const drivers = res.data.data;
    const arun = drivers.find(d => d.name && d.name.toLowerCase().includes('arun'));
    console.log('Arun from getAllDrivers:', JSON.stringify(arun, null, 2));
    
    const perfRes = await axios.get('http://100.53.131.76:5000/api/v1/admin/performance-analytics');
    const arunPerf = perfRes.data.data.driverPerformance.find(d => d.name && d.name.toLowerCase().includes('arun'));
    console.log('Arun from Performance Analytics:', JSON.stringify(arunPerf, null, 2));
  } catch (err) {
    console.error('Error:', err.message);
  }
};

check();
