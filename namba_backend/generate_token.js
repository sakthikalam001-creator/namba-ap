const jwt = require('jsonwebtoken');
const token = jwt.sign({ id: '69d7a23d1cf00e7245ef6748' }, 'supersecret_namba_key_12345', {
  expiresIn: '30d',
});
console.log('JWT_TOKEN:', token);
