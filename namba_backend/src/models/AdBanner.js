const mongoose = require('mongoose');

const AdBannerSchema = new mongoose.Schema({
  vendor: {
    type: mongoose.Schema.ObjectId,
    ref: 'Vendor',
    required: true,
  },
  vendorName: {
    type: String,
    default: 'Featured Store',
  },
  title: {
    type: String,
    required: [true, 'Please add an ad title'],
    trim: true,
  },
  subtitle: {
    type: String,
    default: '',
  },
  imageUrl: {
    type: String,
    required: [true, 'Please add a banner image URL'],
  },
  targetCategory: {
    type: String,
    default: 'ALL',
  },
  position: {
    type: String,
    enum: ['HomeCarousel', 'TopBanner', 'SearchFeatured'],
    default: 'HomeCarousel',
  },
  status: {
    type: String,
    enum: ['Pending', 'Active', 'Paused', 'Rejected'],
    default: 'Active',
  },
  clickCount: {
    type: Number,
    default: 0,
  },
  impressionCount: {
    type: Number,
    default: 0,
  },
  startDate: {
    type: Date,
    default: Date.now,
  },
  endDate: {
    type: Date,
  },
  offerTag: {
    type: String,
    default: '',
  },
  theme: {
    type: String,
    default: '',
  },
  gradient: {
    type: [String],
    default: [],
  },
}, {
  timestamps: true,
});

AdBannerSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('AdBanner', AdBannerSchema);
