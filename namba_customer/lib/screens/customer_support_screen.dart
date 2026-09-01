import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';

class CustomerSupportScreen extends StatefulWidget {
  final String? initialOrderId;
  final String? initialOrderDisplayId;

  const CustomerSupportScreen({
    super.key,
    this.initialOrderId,
    this.initialOrderDisplayId,
  });

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerApiService _apiService = CustomerApiService();

  // Form State
  String _selectedCategory = 'Order Delay / Food Issue';
  String _selectedPriority = 'Medium';
  String? _selectedOrderId;
  String? _selectedOrderDisplayId;
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  bool _isSubmitting = false;

  // Tickets List State
  List<Map<String, dynamic>> _myTickets = [];
  bool _isLoadingTickets = false;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Order Delay / Food Issue', 'icon': Icons.fastfood_rounded, 'desc': 'Delivery taking longer or item delayed'},
    {'title': 'Refund / Payment Deducted', 'icon': Icons.account_balance_wallet_rounded, 'desc': 'Money debited or refund inquiry'},
    {'title': 'Missing / Wrong Items', 'icon': Icons.remove_shopping_cart_rounded, 'desc': 'Items delivered incorrectly or missing'},
    {'title': 'Address & GPS Pin Issue', 'icon': Icons.location_on_rounded, 'desc': 'Need driver to navigate to alternate location'},
    {'title': 'App / Technical Bug', 'icon': Icons.bug_report_rounded, 'desc': 'App freezing, checkout error, or crash'},
    {'title': 'General Support', 'icon': Icons.help_outline_rounded, 'desc': 'Any other platform question or feedback'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedOrderId = widget.initialOrderId;
    _selectedOrderDisplayId = widget.initialOrderDisplayId;

    if (_selectedOrderDisplayId != null) {
      _subjectCtrl.text = 'Issue with Order #$_selectedOrderDisplayId';
    }

    _loadMyTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyTickets() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final phone = auth.phone;
    if (phone.isEmpty) return;

    setState(() => _isLoadingTickets = true);
    final tickets = await _apiService.fetchMyTickets(phone, userType: 'Customer');
    if (mounted) {
      setState(() {
        _myTickets = tickets;
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _submitTicket() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userName = auth.name.isNotEmpty ? auth.name : 'Customer';
    final userPhone = auth.phone;
    final message = _messageCtrl.text.trim();
    final subject = _subjectCtrl.text.trim().isNotEmpty
        ? _subjectCtrl.text.trim()
        : '$_selectedCategory - $userName';

    if (userPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please login to submit a support ticket')),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please describe your issue')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'userType': 'Customer',
      'userId': auth.uid,
      'userName': userName,
      'userPhone': userPhone,
      'subject': subject,
      'category': _selectedCategory,
      'issueType': _selectedCategory,
      'priority': _selectedPriority,
      'orderId': _selectedOrderId,
      'orderDisplayId': _selectedOrderDisplayId ?? '',
      'message': message,
    };

    final result = await _apiService.createSupportTicket(payload);
    setState(() => _isSubmitting = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Ticket #${result['ticketId'] ?? ''} created! Our resolution team is on it.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _messageCtrl.clear();
      _subjectCtrl.clear();
      _selectedOrderId = null;
      _selectedOrderDisplayId = null;
      _loadMyTickets();
      _tabController.animateTo(1); // Switch to My Tickets
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit ticket. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support & Help Desk', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
            Text('Fast resolution for orders & payments', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            const Tab(text: 'RAISE NEW ISSUE'),
            Tab(text: 'MY TICKETS (${_myTickets.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRaiseTicketTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Raise Ticket ──
  Widget _buildRaiseTicketTab() {
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select Issue Category Grid
          Text('SELECT ISSUE CATEGORY', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.5)),
          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              final bool isSelected = _selectedCategory == cat['title'];

              return InkWell(
                onTap: () => setState(() => _selectedCategory = cat['title']),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat['icon'] as IconData, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B), size: 22),
                      const SizedBox(height: 6),
                      Text(
                        cat['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat['desc'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Link Order (Optional)
          if (orders.isNotEmpty) ...[
            Text('LINK TO RECENT ORDER (OPTIONAL)', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.5)),
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      _selectedOrderId = null;
                      _selectedOrderDisplayId = null;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedOrderId == null ? const Color(0xFF4F46E5) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'None',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: _selectedOrderId == null ? Colors.white : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...orders.take(6).map((ord) {
                    final isSelected = _selectedOrderId == ord.id || _selectedOrderDisplayId == ord.displayId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedOrderId = ord.id;
                          _selectedOrderDisplayId = ord.displayId ?? ord.id;
                          _subjectCtrl.text = 'Issue with Order #${ord.displayId ?? ord.id}';
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 6),
                              Text(
                                '#${ord.displayId.isNotEmpty ? ord.displayId : ord.id.substring(0, 6)} (₹${ord.totalAmount.toInt()})',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Subject Input
          Text('TICKET TITLE / SUBJECT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: _subjectCtrl,
            style: GoogleFonts.outfit(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Brief summary of the issue...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),

          const SizedBox(height: 18),

          // Message Input
          Text('DESCRIBE YOUR ISSUE *', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            style: GoogleFonts.outfit(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Provide details like what happened, payment reference, or item names...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitTicket,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting ? 'SUBMITTING TICKET...' : 'SUBMIT SUPPORT TICKET',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Tab 2: My Tickets ──
  Widget _buildMyTicketsTab() {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    if (_myTickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                child: const Icon(Icons.confirmation_num_outlined, color: Color(0xFF4F46E5), size: 40),
              ),
              const SizedBox(height: 16),
              Text('No Support Tickets Raised', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text('Your past issue reports and live resolutions will appear here.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('RAISE A TICKET', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, idx) {
          final t = _myTickets[idx];
          final ticketId = t['ticketId'] ?? 'TK-UNKNOWN';
          final subject = t['subject'] ?? t['issueType'] ?? 'Support Inquiry';
          final status = (t['status'] ?? 'Open').toString();
          final message = t['message'] ?? '';
          final replies = (t['replies'] as List?) ?? [];
          final orderDisplayId = t['orderDisplayId'] ?? '';

          Color statusColor = const Color(0xFFD97706);
          Color statusBg = const Color(0xFFFFFBEB);
          if (status.toLowerCase() == 'resolved') {
            statusColor = const Color(0xFF16A34A);
            statusBg = const Color(0xFFF0FDF4);
          } else if (status.toLowerCase() == 'in progress') {
            statusColor = const Color(0xFF2563EB);
            statusBg = const Color(0xFFEFF6FF);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: InkWell(
              onTap: () => _showTicketChatSheet(t),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF4F46E5))),
                            if (orderDisplayId.toString().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: Text('Order #$orderDisplayId', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(subject, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0F172A))),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${replies.length} Messages', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                          ],
                        ),
                        Row(
                          children: [
                            Text('View & Reply', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Ticket Chat & Responses BottomSheet ──
  void _showTicketChatSheet(Map<String, dynamic> ticket) {
    final replyCtrl = TextEditingController();
    Map<String, dynamic> localTicket = Map<String, dynamic>.from(ticket);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final ticketId = localTicket['ticketId'] ?? 'TK-UNKNOWN';
            final subject = localTicket['subject'] ?? localTicket['issueType'] ?? 'Support Inquiry';
            final status = (localTicket['status'] ?? 'Open').toString();
            final replies = (localTicket['replies'] as List?) ?? [];
            final message = localTicket['message'] ?? '';

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ticketId, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                            Text(subject, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w800)),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(bCtx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(height: 20),

                    // Message Timeline
                    Expanded(
                      child: ListView(
                        children: [
                          // Initial issue box
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOUR INITIAL ISSUE REPORT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(message.isNotEmpty ? message : 'No description', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF334155))),
                              ],
                            ),
                          ),

                          ...replies.map((r) {
                            final sender = r['sender'] ?? 'Support';
                            final isUser = r['senderRole'] == 'Customer' || sender.toString().toLowerCase().contains('customer');
                            final repMsg = r['message'] ?? '';

                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isUser ? 'You' : 'Namba Support Executive',
                                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: isUser ? Colors.white70 : const Color(0xFF4338CA)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(repMsg, style: GoogleFonts.outfit(fontSize: 13, color: isUser ? Colors.white : const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Reply Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: replyCtrl,
                            style: GoogleFonts.outfit(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Type your reply to support...',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5)),
                          onPressed: () async {
                            final msg = replyCtrl.text.trim();
                            if (msg.isEmpty) return;

                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final userName = auth.name.isNotEmpty ? auth.name : 'Customer';

                            final ok = await _apiService.replyToTicket(localTicket['_id'], userName, msg);
                            if (ok) {
                              setSheetState(() {
                                final list = (localTicket['replies'] as List?) ?? [];
                                list.add({
                                  'sender': userName,
                                  'senderRole': 'Customer',
                                  'message': msg,
                                  'createdAt': DateTime.now().toIso8601String(),
                                });
                                localTicket['replies'] = list;
                                replyCtrl.clear();
                              });
                              _loadMyTickets();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
