const express = require('express');
const router = express.Router();
const auditController = require('../controllers/auditController');

router.get('/logs', auditController.getAuditLogs);
router.get('/stats', auditController.getAuditStats);
router.post('/log', auditController.createAuditLog);
router.delete('/purge', auditController.purgeAuditLogs);

module.exports = router;
