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
      required: false,
      refPath: 'userModel', // Dynamic ref
    },
    userModel: {
      type: String,
      required: false,
      enum: ['User', 'Vendor', 'Admin'],
      default: 'User',
    },
    userName: {
      type: String,
      required: true,
    },
    userPhone: {
      type: String,
      required: true,
    },
    subject: {
      type: String,
      default: '',
    },
    category: {
      type: String,
      default: 'General Support',
    },
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
    },
    orderDisplayId: {
      type: String,
      default: '',
    },
    issueType: {
      type: String,
      required: true,
    },
    priority: {
      type: String,
      enum: ['Low', 'Medium', 'High', 'Urgent'],
      default: 'Medium',
    },
    message: {
      type: String,
      default: '',
    },
    replies: [
      {
        sender: String,
        senderRole: {
          type: String,
          enum: ['Admin', 'Customer', 'DeliveryPartner', 'Vendor', 'System'],
          default: 'Admin',
        },
        message: String,
        createdAt: {
          type: Date,
          default: Date.now,
        },
      }
    ],
    status: {
      type: String,
      enum: ['Open', 'In Progress', 'Resolved', 'Closed'],
      default: 'Open',
    },
    resolutionNotes: {
      type: String,
      default: '',
    },
    resolvedAt: {
      type: Date,
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
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
