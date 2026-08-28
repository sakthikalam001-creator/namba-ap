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
    return log;
  } catch (error) {
    console.error('[AuditLogger Error]', error.message);
    return null;
  }
};
