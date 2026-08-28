import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/delivery_auth_service.dart';
import '../../theme/app_theme.dart';

class HelpCenterScreen extends StatefulWidget {
  final String? initialOrderId;

  const HelpCenterScreen({super.key, this.initialOrderId});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _selectedCategory = 'Payout & Weekly Bank Settlement';
  String _selectedPriority = 'Medium';
  final _orderCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _myTickets = [];
  bool _isLoadingTickets = false;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Payout & Weekly Settlement', 'icon': Icons.account_balance_rounded, 'desc': 'Earnings, fuel pay, or bank credit issue'},
    {'title': 'Accident / SOS Emergency', 'icon': Icons.emergency_rounded, 'desc': 'On-duty accident or medical roadside help'},
    {'title': 'Customer Not Reachable', 'icon': Icons.phone_missed_rounded, 'desc': 'Customer unavailable at delivery pin'},
    {'title': 'Wrong GPS Pin / Store Closed', 'icon': Icons.wrong_location_rounded, 'desc': 'Map navigation mismatch or shop shut'},
    {'title': 'Vehicle Breakdown & Duty', 'icon': Icons.two_wheeler_rounded, 'desc': 'Puncture, engine fault or duty pause'},
    {'title': 'App Bug / Location Issue', 'icon': Icons.bug_report_rounded, 'desc': 'Order swipe glitch or GPS tracking fault'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialOrderId != null) {
      _orderCtrl.text = widget.initialOrderId!;
      _subjectCtrl.text = 'Incident on Order #${widget.initialOrderId}';
    }
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orderCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final phone = await DeliveryAuthService.getDriverPhone();
    if (phone.isEmpty) return;

    setState(() => _isLoadingTickets = true);
    final tickets = await DeliveryAuthService.fetchMyTickets(phone);
    if (mounted) {
      setState(() {
        _myTickets = tickets;
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _submitTicket() async {
    final name = await DeliveryAuthService.getDriverName();
    final phone = await DeliveryAuthService.getDriverPhone();
    final driverId = await DeliveryAuthService.getDriverId();
    final message = _messageCtrl.text.trim();
    final subject = _subjectCtrl.text.trim().isNotEmpty
        ? _subjectCtrl.text.trim()
        : '$_selectedCategory - $name';

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please describe your incident details')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'userType': 'DeliveryPartner',
      'userId': driverId.isNotEmpty ? driverId : null,
      'userName': name.isNotEmpty ? name : 'Rider',
      'userPhone': phone.isNotEmpty ? phone : '9876543210',
      'subject': subject,
      'category': _selectedCategory,
      'issueType': _selectedCategory,
      'priority': _selectedPriority,
      'orderDisplayId': _orderCtrl.text.trim(),
      'message': message,
    };

    final result = await DeliveryAuthService.createSupportTicket(payload);
    setState(() => _isSubmitting = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Incident Ticket #${result['ticketId']} raised to Dispatch Desk!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _messageCtrl.clear();
      _subjectCtrl.clear();
      _orderCtrl.clear();
      _loadTickets();
      _tabController.animateTo(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to raise ticket. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FLEET PARTNER SUPPORT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1, color: AppTheme.darkText)),
            Text('Live Incident Dispatch & Payout Help Desk', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.lightText)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryOrange,
          unselectedLabelColor: AppTheme.lightText,
          indicatorColor: AppTheme.primaryOrange,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5),
          tabs: [
            const Tab(text: 'RAISE TICKET'),
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

  // ── Tab 1: Raise Incident Ticket ──
  Widget _buildRaiseTicketTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency Call & SOS Row
          Row(
            children: [
              Expanded(
                child: _contactBanner(
                  icon: Icons.support_agent_rounded,
                  title: 'DISPATCH HOTLINE',
                  subtitle: 'Direct Admin Desk',
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _contactBanner(
                  icon: Icons.emergency_rounded,
                  title: 'SOS EMERGENCY',
                  subtitle: 'Priority Roadside',
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'SELECT INCIDENT CATEGORY',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.32,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              final bool isSelected = _selectedCategory == cat['title'];

              return InkWell(
                onTap: () => setState(() => _selectedCategory = cat['title']),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryOrange : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1.2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))
                      else
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryOrange.withOpacity(0.15) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cat['icon'] as IconData, color: isSelected ? AppTheme.primaryOrange : const Color(0xFF64748B), size: 20),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange, size: 18),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: isSelected ? AppTheme.primaryOrange : const Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            cat['desc'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 22),

          // Priority & Order ID Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('URGENCY LEVEL', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Low', child: Text('🟢 Normal')),
                          DropdownMenuItem(value: 'Medium', child: Text('🟡 Medium')),
                          DropdownMenuItem(value: 'High', child: Text('🟠 High Priority')),
                          DropdownMenuItem(value: 'Urgent', child: Text('🔴 SOS Urgent')),
                        ],
                        onChanged: (val) => setState(() => _selectedPriority = val ?? 'Medium'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORDER ID (OPTIONAL)', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: TextField(
                        controller: _orderCtrl,
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'e.g. ORD-9821',
                          hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Incident Subject
          Text('INCIDENT TITLE / SUBJECT', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.4)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _subjectCtrl,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Brief summary of what happened...',
                hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Incident Description
          Text('INCIDENT DETAILS & DISPATCH NOTES *', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.4)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _messageCtrl,
              maxLines: 4,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Describe clearly what happened, location, amount or assistance needed...',
                hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 26),

          // Submit Button
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A00), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: const Color(0xFFEA580C).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitTicket,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              label: Text(
                _isSubmitting ? 'DISPATCHING TICKET...' : 'RAISE INCIDENT TICKET',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ── Tab 2: My Tickets ──
  Widget _buildMyTicketsTab() {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
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
                decoration: BoxDecoration(color: AppTheme.primaryOrange.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(icons.Iconsax.ticket_copy, color: AppTheme.primaryOrange, size: 36),
              ),
              const SizedBox(height: 16),
              Text('No Incident Tickets Raised', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.darkText)),
              const SizedBox(height: 6),
              Text('Any support issues or payout disputes you raise will be tracked here live.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.lightText)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
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
      onRefresh: _loadTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, idx) {
          final t = _myTickets[idx];
          final ticketId = t['ticketId'] ?? 'TK-UNKNOWN';
          final subject = t['subject'] ?? t['issueType'] ?? 'Fleet Incident';
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
              boxShadow: AppTheme.softShadow,
            ),
            child: InkWell(
              onTap: () => _showRiderTicketSheet(t),
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
                            Text(ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.primaryOrange)),
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
                    Text(subject, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.darkText)),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.lightText)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${replies.length} Responses', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                          ],
                        ),
                        Row(
                          children: [
                            Text('View & Chat', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange)),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primaryOrange),
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

  Widget _contactBanner({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11.5, color: color, letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRiderTicketSheet(Map<String, dynamic> ticket) {
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
            final subject = localTicket['subject'] ?? localTicket['issueType'] ?? 'Fleet Support';
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
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ticketId, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange)),
                            Text(subject, style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.darkText, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(bCtx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOUR INCIDENT REPORT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(message.isNotEmpty ? message : 'No description', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF334155))),
                              ],
                            ),
                          ),
                          ...replies.map((r) {
                            final sender = r['sender'] ?? 'Dispatch';
                            final isRider = r['senderRole'] == 'DeliveryPartner' || sender.toString().toLowerCase().contains('rider');
                            final repMsg = r['message'] ?? '';

                            return Align(
                              alignment: isRider ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isRider ? AppTheme.primaryOrange : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isRider ? 'You' : 'Super Admin Dispatch Desk',
                                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: isRider ? Colors.white70 : const Color(0xFF4338CA)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(repMsg, style: GoogleFonts.outfit(fontSize: 13, color: isRider ? Colors.white : const Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: replyCtrl,
                            style: GoogleFonts.outfit(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Type reply to Dispatch Desk...',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppTheme.primaryOrange),
                          onPressed: () async {
                            final msg = replyCtrl.text.trim();
                            if (msg.isEmpty) return;

                            final name = await DeliveryAuthService.getDriverName();
                            final ok = await DeliveryAuthService.replyToTicket(localTicket['_id'], name, msg);
                            if (ok) {
                              setSheetState(() {
                                final list = (localTicket['replies'] as List?) ?? [];
                                list.add({
                                  'sender': name,
                                  'senderRole': 'DeliveryPartner',
                                  'message': msg,
                                  'createdAt': DateTime.now().toIso8601String(),
                                });
                                localTicket['replies'] = list;
                                replyCtrl.clear();
                              });
                              _loadTickets();
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
