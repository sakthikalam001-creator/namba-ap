const mongoose = require('mongoose');

const DriverDutySessionSchema = new mongoose.Schema({
  driver: {
    type: mongoose.Schema.ObjectId,
    ref: 'User',
    required: true,
  },
  date: {
    type: String, // YYYY-MM-DD for fast aggregation
    required: true,
  },
  onlineTime: {
    type: Date,
    required: true,
  },
  offlineTime: {
    type: Date,
    default: null,
  },
  durationSeconds: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('DriverDutySession', DriverDutySessionSchema);
