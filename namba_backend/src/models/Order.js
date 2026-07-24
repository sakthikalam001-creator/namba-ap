const mongoose = require('mongoose');

const OrderItemSchema = new mongoose.Schema({
  productName: { type: String, required: true },
  quantity: { type: Number, required: true, min: 1 },
  price: { type: Number, required: true },
  specialInstructions: String,
});

const OrderSchema = new mongoose.Schema({
  customer: {
    type: mongoose.Schema.ObjectId,
    ref: 'User',
    required: true,
  },
  vendor: {
    type: mongoose.Schema.ObjectId,
    ref: 'Vendor',
    required: false, // Optional for Any Store Delivery (Personal Assistant Mode)
  },
  isCustomStore: {
    type: Boolean,
    default: false,
  },
  customStoreName: String,
  customStoreAddress: String,
  driver: {
    type: mongoose.Schema.ObjectId,
    ref: 'User',
  },
  orderType: {
    type: String,
    enum: ['Cart', 'Text', 'Photo'],
    default: 'Cart',
  },
  textContent: String,
  photoUrl: String,
  items: {
    type: [OrderItemSchema],
    default: [],
  },
  subTotal: {
    type: Number,
  },
  discount: {
    type: Number,
    default: 0,
  },
  totalAmount: {
    type: Number,
    required: true,
  },
  deliveryCharge: {
    type: Number,
    required: true,
  },
  platformFee: {
    type: Number,
    required: true,
  },
  vendorEarnings: {
    type: Number,
    required: true, // totalAmount - vendorFee
  },
  vendorFee: {
    type: Number,
    default: 0,
  },
  customerPlatformFee: {
    type: Number,
    default: 0,
  },
  status: {
    type: String,
    enum: [
      'PaymentPending', // Awaiting online payment completion
      'Pending',        // Initial state
      'Accepted',       // Vendor accepted the order
      'Confirmed',      // Vendor confirmed order receipt
      'Assigned',       // Driver accepted the order — awaiting pickup
      'Preparing',      // Food is being cooked / Items being packed
      'Ready',          // Waiting for driver pickup
      'HandedOver',     // Transition state: vendor handed to driver
      'PickedUp',       // Driver has the package
      'OutForDelivery', // Driver on the way
      'On The Way',     // Alternative name for OutForDelivery
      'Delivered',      // Complete
      'Cancelled',      // Failure
    ],
    default: 'Pending',
  },
  deliveryCoordinates: {
    type: {
      type: String,
      default: 'Point',
    },
    coordinates: [Number],
  },
  deliveryAddress: String,
  deliveryAddressFormatted: String,
  displayId: {
    type: String,
    unique: true,
  },
  paymentStatus: {
    type: String,
    enum: ['Pending', 'Completed', 'Failed', 'Refunded'],
    default: 'Pending',
  },
  customerPaid: {
    type: Boolean,
    default: false,
  },
  paymentMethod: {
    type: String,
    enum: ['COD', 'UPI', 'CARD', 'ONLINE'],
    required: true,
  },
  billPhotoPath: {
    type: String,
    required: false, // Uploaded by driver before delivery
  },
  billUploadedAt: {
    type: Date,
    required: false,
  },
  vendorPaymentDetailsUploadedByDriver: {
    type: Boolean,
    default: false,
  },
  vendorUpiNumber: String,
  vendorUpiQrPath: String,
  vendorPaymentStatus: {
    type: String,
    enum: ['Pending', 'Completed', 'Failed'],
    default: 'Pending',
  },
  vendorPaidAt: Date,
  driverPaymentStatus: {
    type: String,
    enum: ['Pending', 'Paid'],
    default: 'Pending',
  },
}, {
  timestamps: true,
});

// Pre-save hook to generate a unique professional displayId
OrderSchema.pre('save', async function() {
  if (this.isNew || !this.displayId) {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No 0, 1, I, O to avoid confusion
    let result = '';
    for (let i = 0; i < 5; i++) {
      result += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    this.displayId = `NM-${result}`;
  }
});

module.exports = mongoose.model('Order', OrderSchema);
