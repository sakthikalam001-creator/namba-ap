const mongoose = require('mongoose');

const ReviewSchema = new mongoose.Schema({
  order: {
    type: mongoose.Schema.ObjectId,
    ref: 'Order',
    required: false,
  },
  vendor: {
    type: mongoose.Schema.ObjectId,
    ref: 'Vendor',
    required: false,
  },
  driver: {
    type: mongoose.Schema.ObjectId,
    ref: 'User',
    required: false,
  },
  customer: {
    type: mongoose.Schema.ObjectId,
    ref: 'User',
  },
  customerName: {
    type: String,
    default: 'Customer',
  },
  rating: {
    type: Number,
    required: [true, 'Please add a rating between 1 and 5'],
    min: 1,
    max: 5,
  },
  comment: {
    type: String,
    default: '',
  },
  orderType: {
    type: String,
    default: 'Order',
  },
}, {
  timestamps: true,
});

ReviewSchema.index({ vendor: 1, createdAt: -1 });

module.exports = mongoose.model('Review', ReviewSchema);
