const { execSync } = require('child_process');
try {
  const result = execSync('ssh -i namba-key.pem -o StrictHostKeyChecking=no ubuntu@100.50.39.221 "mongosh namba_db --eval \\"db.vendors.findOne({_id: ObjectId(\'6a57aefb16962c32adc0341c\')})\\""');
  console.log(result.toString());
} catch(e) {
  console.error(e.message);
}
