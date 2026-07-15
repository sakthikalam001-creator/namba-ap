const mongoose = require('mongoose');

const OfferSchema = new mongoose.Schema({
  vendor: {
    type: mongoose.Schema.ObjectId,
    ref: 'Vendor',
    required: true,
  },
  title: {
    type: String,
    required: [true, 'Please add a title'],
    trim: true,
  },
  description: {
    type: String,
    required: [true, 'Please add a description'],
  },
  imageUrl: {
    type: String,
    default: '',
  },
  discountType: {
    type: String,
    enum: ['Percentage', 'Flat'],
    default: 'Percentage',
  },
  discountValue: {
    type: Number,
    required: true,
  },
  code: {
    type: String,
    uppercase: true,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  expiresAt: {
    type: Date,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Offer', OfferSchema);
