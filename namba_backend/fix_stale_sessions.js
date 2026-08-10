const mongoose = require('mongoose');
const User = require('./src/models/User');
const DriverDutySession = require('./src/models/DriverDutySession');
require('dotenv').config();

async function fixStaleSessions() {
  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/namba';
    console.log(`[Fix] Connecting to MongoDB (${mongoUri})...`);
    await mongoose.connect(mongoUri);

    const now = new Date();

    // 1. Close all unclosed duty sessions
    const unclosedSessions = await DriverDutySession.find({ offlineTime: null });
    console.log(`[Fix] Found ${unclosedSessions.length} unclosed duty sessions.`);
    
    for (const session of unclosedSessions) {
      const sessionSeconds = Math.max(0, Math.floor((now.getTime() - new Date(session.onlineTime).getTime()) / 1000));
      session.offlineTime = now;
      session.durationSeconds = sessionSeconds;
      await session.save();
      console.log(`[Fix] Closed duty session ${session._id} for driver ${session.driver}`);
    }

    // 2. Reset all drivers to isOnline: false and onlineSessionStart: null
    const result = await User.updateMany(
      { role: 'driver' },
      { 
        $set: { 
          isOnline: false, 
          onlineSessionStart: null 
        } 
      }
    );
    console.log(`[Fix] Reset ${result.modifiedCount} driver(s) to isOnline: false.`);

    console.log('[Fix] ✅ Stale sessions cleanup complete.');
    process.exit(0);
  } catch (err) {
    console.error('[Fix] ❌ Error fixing stale sessions:', err);
    process.exit(1);
  }
}

fixStaleSessions();
