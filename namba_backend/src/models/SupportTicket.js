const mongoose = require('mongoose');

const supportTicketSchema = new mongoose.Schema(
  {
    ticketId: {
      type: String,
      required: true,
      unique: true,
    },
    userType: {
      type: String,
      enum: ['Customer', 'Vendor', 'DeliveryPartner'],
      required: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      refPath: 'userModel', // Dynamic ref
    },
    userModel: {
      type: String,
      required: true,
      enum: ['User', 'Vendor'],
    },
    userName: {
      type: String,
      required: true,
    },
    userPhone: {
      type: String,
      required: true,
    },
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
    },
    issueType: {
      type: String,
      required: true,
    },
    message: {
      type: String,
    },
    status: {
      type: String,
      enum: ['Open', 'In Progress', 'Resolved', 'Closed'],
      default: 'Open',
    },
    resolvedAt: {
      type: Date,
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin', // If admin model exists
    },
  },
  {
    timestamps: true,
  }
);

// Pre-save to auto-generate ticketId if not exists
supportTicketSchema.pre('validate', function(next) {
  if (!this.ticketId) {
    const timestamp = Date.now().toString();
    this.ticketId = `TK-${timestamp.substring(timestamp.length - 6)}`;
  }
  next();
});

module.exports = mongoose.model('SupportTicket', supportTicketSchema);
