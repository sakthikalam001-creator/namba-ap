const express = require('express');
const router = express.Router();
const ticketController = require('../controllers/ticketController');

// User Apps (Customer, Rider, Vendor)
router.post('/', ticketController.createTicket);
router.get('/my-tickets', ticketController.getMyTickets);
router.get('/user/:id', ticketController.getTicket);
router.post('/:id/reply', ticketController.addUserReply);

// Admin ticket management
router.get('/admin', ticketController.getAllTickets);
router.get('/admin/stats', ticketController.getTicketStats);
router.post('/admin/create', ticketController.createAdminTicket);
router.get('/admin/:id', ticketController.getTicket);
router.put('/admin/:id', ticketController.updateTicketStatus);
router.post('/admin/:id/reply', ticketController.addTicketReply);
router.delete('/admin/:id', ticketController.deleteTicket);

module.exports = router;
