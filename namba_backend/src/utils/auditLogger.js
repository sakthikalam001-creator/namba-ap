const AuditLog = require('../models/AuditLog');

/**
 * Log a real system or admin audit event
 */
exports.logEvent = async ({
  action,
  category = 'SYSTEM',
  severity = 'INFO',
  actor = {},
  targetEntity = {},
  detail,
  changes = null,
  ipAddress = '127.0.0.1',
  userAgent = 'Namba Admin Console / Web (Windows 11)',
  status = 'SUCCESS',
  metadata = {},
}) => {
  try {
    const log = new AuditLog({
      action: action.toUpperCase(),
      category: category.toUpperCase(),
      severity: severity.toUpperCase(),
      actor: {
        id: actor.id || null,
        name: actor.name || 'Sakthikalam Admin',
        email: actor.email || 'sakthikalam001@gmail.com',
        role: actor.role || 'SUPER_ADMIN',
      },
      targetEntity: {
        entityType: targetEntity.entityType || '',
        entityId: targetEntity.entityId ? targetEntity.entityId.toString() : '',
        name: targetEntity.name || '',
      },
      detail: detail || `${action} executed successfully`,
      changes: changes || undefined,
      ipAddress: ipAddress || '127.0.0.1',
      userAgent: userAgent || 'Namba Admin Console / Web (Windows 11)',
      status: status.toUpperCase(),
      metadata: metadata || undefined,
    });

    await log.save();

    // Broadcast to Admin socket in real time
    if (global.io) {
      try {
        global.io.emit('audit:new_log', log.toObject());
      } catch (err) {
        console.error('[Audit Socket Emit Error]', err.message);
      }
    }

    return log;
  } catch (error) {
    console.error('[AuditLogger Error]', error.message);
    return null;
  }
};

/**
 * Convenience helper to log an audit event directly from an Express request
 */
exports.logAudit = async (req, eventData) => {
  try {
    const ip = req
      ? (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '127.0.0.1').toString().split(',')[0].trim()
      : '127.0.0.1';
    const ua = req ? (req.headers['user-agent'] || 'Namba Client') : 'Namba Core';

    let actor = eventData.actor;
    if (!actor && req && req.user) {
      actor = {
        id: req.user._id,
        name: req.user.name || req.user.phone || 'Platform User',
        email: req.user.email || `${req.user.phone || 'user'}@namba.app`,
        role: (req.user.role || 'USER').toUpperCase(),
      };
    }

    return await exports.logEvent({
      ...eventData,
      actor: actor || { name: 'Sakthikalam Admin', email: 'sakthikalam001@gmail.com', role: 'SUPER_ADMIN' },
      ipAddress: eventData.ipAddress || ip,
      userAgent: eventData.userAgent || ua,
    });
  } catch (e) {
    console.error('[logAudit Error]', e.message);
    return null;
  }
};
