const express = require('express');
const router = express.Router();
const ticketController = require('../controllers/ticketController');
// const { protect, authorize } = require('../middlewares/auth'); 
// Assuming auth middleware is available, otherwise skip for simplicity in MVP

// User apps (Customer, Vendor, Delivery Partner) can create tickets
router.post('/', ticketController.createTicket);

// Admin routes for managing tickets
// Assuming route might be protected by admin auth middleware in reality
router.get('/admin', ticketController.getAllTickets);
router.get('/admin/:id', ticketController.getTicket);
router.put('/admin/:id', ticketController.updateTicketStatus);

module.exports = router;
