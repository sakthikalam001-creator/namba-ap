const mongoose = require('./namba_backend/node_modules/mongoose');
const DriverDutySession = require('./namba_backend/src/models/DriverDutySession');

async function clean() {
  await mongoose.connect('mongodb://localhost:27017/namba');
  const sessions = await DriverDutySession.find({ offlineTime: null }).sort({ onlineTime: -1 });
  if (sessions.length > 1) {
    const extraIds = sessions.slice(1).map(s => s._id);
    await DriverDutySession.deleteMany({ _id: { $in: extraIds } });
    console.log('Cleaned', extraIds.length, 'duplicate open sessions from MongoDB');
  } else {
    console.log('No duplicates found.');
  }
  mongoose.disconnect();
}

clean();
