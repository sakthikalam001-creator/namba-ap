require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./src/models/User');

mongoose.connect(process.env.MONGODB_URI).then(async () => {
    try {
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash('Admin@123', salt);
        await User.updateMany({ role: { $in: ['admin', 'superadmin'] } }, { $set: { password: hashedPassword } });
        console.log('Successfully reset all Admin / Super Admin passwords to: Admin@123');
    } catch (e) {
        console.error('Error:', e);
    } finally {
        process.exit(0);
    }
});
