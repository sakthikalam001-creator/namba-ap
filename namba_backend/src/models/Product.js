const mongoose = require('mongoose');

const ProductSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please add a product name'],
    trim: true,
  },
  price: {
    type: Number,
    required: [true, 'Please add a price'],
  },
  stock: {
    type: Number,
    required: [true, 'Please add stock quantity'],
    default: 0,
  },
  category: {
    type: String,
    required: [true, 'Please add a category'],
  },
  isAvailable: {
    type: Boolean,
    default: true,
  },
  description: {
    type: String,
    default: '',
  },
  image: {
    type: String,
    default: '',
  },
  mrp: {
    type: Number,
    default: 0,
  },
  discount: {
    type: Number,
    default: 0,
  },
  offerBadge: {
    type: String,
    default: '',
  },
  unit: {
    type: String,
    default: '1 pc',
  },
  isVeg: {
    type: Boolean,
    default: true,
  },
  foodType: {
    type: String,
    default: 'veg',
  },
  prepTime: {
    type: String,
    default: '15 mins',
  },
  vendor: {
    type: mongoose.Schema.ObjectId,
    ref: 'Vendor',
    required: true,
  }
}, {
  timestamps: true,
});

module.exports = mongoose.model('Product', ProductSchema);
