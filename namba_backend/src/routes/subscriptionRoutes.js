const express = require('express');
const {
  getSubscriptions,
  getAdminSubscriptions,
  createSubscriptionPlan,
  updateSubscriptionPlan,
  deleteSubscriptionPlan
} = require('../controllers/subscriptionController');

const router = express.Router();

// Public routes (for Vendor App)
router.get('/', getSubscriptions);

// Admin routes (for Admin Dashboard)
router.get('/admin', getAdminSubscriptions);
router.post('/admin', createSubscriptionPlan);
router.put('/admin/:id', updateSubscriptionPlan);
router.delete('/admin/:id', deleteSubscriptionPlan);

module.exports = router;
