const SupportTicket = require('../models/SupportTicket');
const Order = require('../models/Order');
const User = require('../models/User');
const Vendor = require('../models/Vendor');

// Create a new support ticket (User Apps or Admin)
exports.createTicket = async (req, res) => {
  try {
    const {
      userType,
      userId,
      userName,
      userPhone,
      subject,
      category,
      orderId,
      orderDisplayId,
      issueType,
      priority,
      message,
      imageUrl,
      imageUrls,
    } = req.body;

    if (!userType || !userName || !userPhone || !issueType) {
      return res.status(400).json({ success: false, message: 'Missing required ticket fields' });
    }

    let userModel = 'User';
    if (userType === 'Vendor') {
      userModel = 'Vendor';
    }

    let resolvedOrderId = orderId;
    let resolvedDisplayId = orderDisplayId || '';

    // If order displayId provided, look up order
    if (!resolvedOrderId && resolvedDisplayId) {
      const order = await Order.findOne({ displayId: resolvedDisplayId });
      if (order) {
        resolvedOrderId = order._id;
      }
    } else if (resolvedOrderId && !resolvedDisplayId) {
      const order = await Order.findById(resolvedOrderId);
      if (order && order.displayId) {
        resolvedDisplayId = order.displayId;
      }
    }

    const finalImg = imageUrl || (imageUrls && imageUrls[0]) || '';

    const newTicket = new SupportTicket({
      userType,
      userId: userId || null,
      userModel,
      userName,
      userPhone,
      subject: subject || `${issueType} Issue`,
      category: category || issueType || 'General Support',
      orderId: resolvedOrderId || null,
      orderDisplayId: resolvedDisplayId,
      issueType,
      priority: priority || 'Medium',
      message: message || '',
      imageUrl: finalImg,
      imageUrls: imageUrls || (finalImg ? [finalImg] : []),
      replies: (message || finalImg) ? [{
        sender: userName,
        senderRole: userType === 'DeliveryPartner' ? 'DeliveryPartner' : (userType === 'Vendor' ? 'Vendor' : 'Customer'),
        message: message || (finalImg ? '📷 Photo Proof Attached' : ''),
        imageUrl: finalImg,
        createdAt: new Date(),
      }] : [],
    });

    await newTicket.save();

    // Broadcast to Admin via Socket.io
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
    res.status(500).json({ success: false, message: error.message || 'Server error' });
  }
};

// Admin Raise Ticket Directly
exports.createAdminTicket = async (req, res) => {
  try {
    const {
      userType,
      userId,
      userName,
      userPhone,
      subject,
      category,
      orderId,
      orderDisplayId,
      issueType,
      priority,
      message,
    } = req.body;

    if (!userType || !userName || !userPhone || !issueType) {
      return res.status(400).json({ success: false, message: 'Please fill user type, name, phone, and issue category' });
    }

    const newTicket = new SupportTicket({
      userType,
      userId: userId || null,
      userModel: userType === 'Vendor' ? 'Vendor' : 'User',
      userName,
      userPhone,
      subject: subject || `[ADMIN] ${issueType} - ${userName}`,
      category: category || issueType || 'General Support',
      orderId: orderId || null,
      orderDisplayId: orderDisplayId || '',
      issueType,
      priority: priority || 'High',
      message: message || '',
      replies: message ? [{
        sender: 'Super Admin Desk',
        senderRole: 'Admin',
        message: message,
        createdAt: new Date(),
      }] : [],
    });

    await newTicket.save();

    res.status(201).json({
      success: true,
      data: newTicket,
    });
  } catch (error) {
    console.error('[createAdminTicket Error]', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get all tickets with filtering & search (for admin)
exports.getAllTickets = async (req, res) => {
  try {
    const { status, userType, priority, q } = req.query;
    
    let filter = {};
    if (status && status !== 'ALL') filter.status = status;
    if (userType && userType !== 'ALL') filter.userType = userType;
    if (priority && priority !== 'ALL') filter.priority = priority;

    if (q && q.trim()) {
      const regex = new RegExp(q.trim(), 'i');
      filter.$or = [
        { ticketId: regex },
        { userName: regex },
        { userPhone: regex },
        { subject: regex },
        { issueType: regex },
        { orderDisplayId: regex },
      ];
    }

    const tickets = await SupportTicket.find(filter)
      .populate('userId', 'name phone email')
      .populate('orderId', 'displayId status totalAmount createdAt')
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

// Get high-level support desk statistics
exports.getTicketStats = async (req, res) => {
  try {
    const total = await SupportTicket.countDocuments();
    const open = await SupportTicket.countDocuments({ status: 'Open' });
    const inProgress = await SupportTicket.countDocuments({ status: 'In Progress' });
    const resolved = await SupportTicket.countDocuments({ status: 'Resolved' });
    const closed = await SupportTicket.countDocuments({ status: 'Closed' });

    const customerCount = await SupportTicket.countDocuments({ userType: 'Customer' });
    const riderCount = await SupportTicket.countDocuments({ userType: 'DeliveryPartner' });
    const vendorCount = await SupportTicket.countDocuments({ userType: 'Vendor' });
    const urgentCount = await SupportTicket.countDocuments({ priority: { $in: ['High', 'Urgent'] }, status: { $in: ['Open', 'In Progress'] } });

    res.status(200).json({
      success: true,
      data: {
        total,
        open,
        inProgress,
        resolved,
        closed,
        customerCount,
        riderCount,
        vendorCount,
        urgentCount,
      },
    });
  } catch (error) {
    console.error('[getTicketStats Error]', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Get a single ticket
exports.getTicket = async (req, res) => {
  try {
    const ticket = await SupportTicket.findById(req.params.id)
      .populate('userId', 'name phone email')
      .populate('orderId', 'displayId status totalAmount createdAt');

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

// Add reply to ticket
exports.addTicketReply = async (req, res) => {
  try {
    const { sender, senderRole, message, imageUrl } = req.body;
    if ((!message || !message.trim()) && !imageUrl) {
      return res.status(400).json({ success: false, message: 'Reply message or image cannot be empty' });
    }

    const ticket = await SupportTicket.findById(req.params.id);
    if (!ticket) {
      return res.status(404).json({ success: false, message: 'Ticket not found' });
    }

    ticket.replies.push({
      sender: sender || 'Support Executive',
      senderRole: senderRole || 'Admin',
      message: (message || '').trim() || (imageUrl ? '📷 Photo Attached' : ''),
      imageUrl: imageUrl || '',
      createdAt: new Date(),
    });

    if (ticket.status === 'Open') {
      ticket.status = 'In Progress';
    }

    await ticket.save();

    // Broadcast to Admin & User sockets for live chat
    const io = req.app.get('socketio');
    if (io) {
      io.to('admin').emit('ticket_admin_reply', { ticketId: ticket._id, ticket });
      io.emit(`ticket_reply_${ticket._id}`, { ticketId: ticket._id, ticket });
      if (ticket.userPhone) {
        io.emit(`ticket_reply_phone_${ticket.userPhone}`, { ticketId: ticket._id, ticket });
      }
    }

    res.status(200).json({
      success: true,
      data: ticket,
    });
  } catch (error) {
    console.error('[addTicketReply Error]', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Update ticket status
exports.updateTicketStatus = async (req, res) => {
  try {
    const { status, resolutionNotes, priority } = req.body;
    if (status && !['Open', 'In Progress', 'Resolved', 'Closed'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    const ticket = await SupportTicket.findById(req.params.id);
    if (!ticket) {
      return res.status(404).json({ success: false, message: 'Ticket not found' });
    }

    if (status) {
      ticket.status = status;
      if (status === 'Resolved' || status === 'Closed') {
        ticket.resolvedAt = Date.now();
      }
    }

    if (priority) {
      ticket.priority = priority;
    }

    if (resolutionNotes !== undefined) {
      ticket.resolutionNotes = resolutionNotes;
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

// Get User's own tickets (For Customer / Rider / Vendor apps)
exports.getMyTickets = async (req, res) => {
  try {
    const { phone, userId, userType } = req.query;

    let filter = {};
    if (phone) {
      // match exact phone or regex
      filter.userPhone = phone.trim();
    } else if (userId) {
      filter.userId = userId;
    }

    if (userType) {
      filter.userType = userType;
    }

    const tickets = await SupportTicket.find(filter)
      .populate('orderId', 'displayId status totalAmount createdAt')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: tickets.length,
      data: tickets,
    });
  } catch (error) {
    console.error('[getMyTickets Error]', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// User / Rider / Vendor reply to ticket
exports.addUserReply = async (req, res) => {
  try {
    const { sender, senderRole, message, imageUrl } = req.body;
    if ((!message || !message.trim()) && !imageUrl) {
      return res.status(400).json({ success: false, message: 'Message or image cannot be empty' });
    }

    const ticket = await SupportTicket.findById(req.params.id);
    if (!ticket) {
      return res.status(404).json({ success: false, message: 'Ticket not found' });
    }

    ticket.replies.push({
      sender: sender || ticket.userName || 'User',
      senderRole: senderRole || ticket.userType || 'Customer',
      message: (message || '').trim() || (imageUrl ? '📷 Photo Proof Attached' : ''),
      imageUrl: imageUrl || '',
      createdAt: new Date(),
    });

    if (ticket.status === 'Resolved' || ticket.status === 'Closed') {
      ticket.status = 'In Progress'; // Re-open on user reply
    }

    await ticket.save();

    // Notify Admin via Socket.io
    const io = req.app.get('socketio');
    if (io) {
      io.to('admin').emit('ticket_user_reply', { ticketId: ticket._id, ticket });
    }

    res.status(200).json({
      success: true,
      data: ticket,
    });
  } catch (error) {
    console.error('[addUserReply Error]', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Delete ticket
exports.deleteTicket = async (req, res) => {
  try {
    await SupportTicket.findByIdAndDelete(req.params.id);
    res.status(200).json({ success: true, message: 'Ticket deleted successfully' });
  } catch (error) {
    console.error('[deleteTicket Error]', error);
    res.status(500).json({ success: false, message: error.message });
  }
};
