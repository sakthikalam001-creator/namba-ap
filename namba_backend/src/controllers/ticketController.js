const SupportTicket = require('../models/SupportTicket');

// Create a new support ticket
exports.createTicket = async (req, res) => {
  try {
    const { userType, userId, userName, userPhone, orderId, issueType, message } = req.body;

    if (!userType || !userId || !userName || !userPhone || !issueType) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    let userModel;
    if (userType === 'Customer' || userType === 'DeliveryPartner') {
      userModel = 'User';
    } else if (userType === 'Vendor') {
      userModel = 'Vendor';
    } else {
      return res.status(400).json({ success: false, message: 'Invalid userType' });
    }

    const newTicket = new SupportTicket({
      userType,
      userId,
      userModel,
      userName,
      userPhone,
      orderId,
      issueType,
      message,
    });

    await newTicket.save();

    // Optionally emit a socket event to admin here
    const io = req.app.get('socketio');
    if (io) {
      io.to('admin').emit('new_support_ticket', newTicket);
    }

    res.status(201).json({
      success: true,
      data: newTicket,
    });
  } catch (error) {
    console.error('[createTicket Error]', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Get all tickets (for admin)
exports.getAllTickets = async (req, res) => {
  try {
    const { status, userType } = req.query;
    
    let filter = {};
    if (status) filter.status = status;
    if (userType) filter.userType = userType;

    const tickets = await SupportTicket.find(filter)
      .populate('userId', 'name phone email')
      .populate('orderId', 'orderId status totalAmount')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: tickets.length,
      data: tickets,
    });
  } catch (error) {
    console.error('[getAllTickets Error]', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Get a single ticket
exports.getTicket = async (req, res) => {
  try {
    const ticket = await SupportTicket.findById(req.params.id)
      .populate('userId', 'name phone email')
      .populate('orderId', 'orderId status totalAmount');

    if (!ticket) {
      return res.status(404).json({ success: false, message: 'Ticket not found' });
    }

    res.status(200).json({
      success: true,
      data: ticket,
    });
  } catch (error) {
    console.error('[getTicket Error]', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Update ticket status
exports.updateTicketStatus = async (req, res) => {
  try {
    const { status } = req.body;
    if (!['Open', 'In Progress', 'Resolved', 'Closed'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    const ticket = await SupportTicket.findById(req.params.id);
    if (!ticket) {
      return res.status(404).json({ success: false, message: 'Ticket not found' });
    }

    ticket.status = status;
    if (status === 'Resolved' || status === 'Closed') {
      ticket.resolvedAt = Date.now();
    }
    
    await ticket.save();

    res.status(200).json({
      success: true,
      data: ticket,
    });
  } catch (error) {
    console.error('[updateTicketStatus Error]', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
