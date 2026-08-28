const mongoose = require('mongoose');

const AuditLogSchema = new mongoose.Schema(
  {
    action: {
      type: String,
      required: true,
      index: true,
    },
    category: {
      type: String,
      enum: ['AUTH', 'VENDOR', 'FLEET', 'SETTINGS', 'BROADCAST', 'SUPPORT', 'PAYMENTS', 'SECURITY', 'SYSTEM'],
      default: 'SYSTEM',
      index: true,
    },
    severity: {
      type: String,
      enum: ['INFO', 'WARNING', 'CRITICAL', 'AUDIT'],
      default: 'INFO',
      index: true,
    },
    actor: {
      id: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      name: { type: String, default: 'System Core' },
      email: { type: String, default: 'admin@namba.com' },
      role: { type: String, default: 'SUPER_ADMIN' },
    },
    targetEntity: {
      entityType: { type: String }, // 'Vendor', 'User', 'Order', 'Settings', 'SupportTicket', 'Broadcast'
      entityId: { type: String },
      name: { type: String },
    },
    detail: {
      type: String,
      required: true,
    },
    changes: {
      before: { type: mongoose.Schema.Types.Mixed },
      after: { type: mongoose.Schema.Types.Mixed },
    },
    ipAddress: {
      type: String,
      default: '127.0.0.1',
    },
    userAgent: {
      type: String,
      default: 'Namba Dashboard Admin Portal / Chrome v126 (Windows)',
    },
    status: {
      type: String,
      enum: ['SUCCESS', 'FAILURE', 'BLOCKED', 'WARNING'],
      default: 'SUCCESS',
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for fast search & filtering
AuditLogSchema.index({ createdAt: -1 });
AuditLogSchema.index({ action: 'text', detail: 'text', 'actor.name': 'text', 'actor.email': 'text', 'targetEntity.name': 'text' });

module.exports = mongoose.model('AuditLog', AuditLogSchema);
