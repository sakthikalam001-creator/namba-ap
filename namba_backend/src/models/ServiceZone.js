const mongoose = require('mongoose');

const ServiceZoneSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please add a zone name'],
    unique: true,
    trim: true,
  },
  lat: {
    type: Number,
    required: [true, 'Please add center latitude'],
  },
  lng: {
    type: Number,
    required: [true, 'Please add center longitude'],
  },
  radiusKm: {
    type: Number,
    required: [true, 'Please add service radius in KM'],
    default: 10,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  isDefault: {
    type: Boolean,
    default: false,
  }
}, {
  timestamps: true,
});

module.exports = mongoose.model('ServiceZone', ServiceZoneSchema);
