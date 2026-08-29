import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
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

  String _selectedCategory = 'Payout & Weekly Settlement';
  String _selectedPriority = 'Medium';
  final _orderCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _myTickets = [];
  bool _isLoadingTickets = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'Payout & Weekly Settlement',
      'icon': Icons.account_balance_wallet_rounded,
      'desc': 'Earnings, fuel allowance, or bank credit status',
      'color': const Color(0xFF2563EB),
    },
    {
      'title': 'Accident / SOS Emergency',
      'icon': Icons.emergency_rounded,
      'desc': 'On-duty accident or medical roadside assist',
      'color': const Color(0xFFDC2626),
    },
    {
      'title': 'Customer Not Reachable',
      'icon': Icons.phone_disabled_rounded,
      'desc': 'Customer unavailable or wrong delivery address',
      'color': const Color(0xFFD97706),
    },
    {
      'title': 'Store Closed / Wrong Location',
      'icon': Icons.wrong_location_rounded,
      'desc': 'Shop shut, location mismatch, or long wait',
      'color': const Color(0xFF7C3AED),
    },
    {
      'title': 'Vehicle Breakdown & Duty',
      'icon': Icons.two_wheeler_rounded,
      'desc': 'Puncture, engine breakdown, or shift duty pause',
      'color': const Color(0xFF059669),
    },
    {
      'title': 'App Bug / GPS Tracking Issue',
      'icon': Icons.bug_report_rounded,
      'desc': 'Order swipe glitch or location navigation fault',
      'color': const Color(0xFF0284C7),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.initialOrderId != null && widget.initialOrderId!.isNotEmpty) {
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

    if (mounted) setState(() => _isLoadingTickets = true);
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
        : '$_selectedCategory - ${name.isNotEmpty ? name : 'Partner'}';

    if (message.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please describe your incident notes before submitting.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'userType': 'DeliveryPartner',
      'userId': driverId.isNotEmpty ? driverId : null,
      'userName': name.isNotEmpty ? name : (phone.isNotEmpty ? 'Partner $phone' : 'Delivery Partner'),
      'userPhone': phone.isNotEmpty ? phone : '9876543210',
      'subject': subject,
      'category': _selectedCategory,
      'issueType': _selectedCategory,
      'priority': _selectedPriority,
      'orderDisplayId': _orderCtrl.text.trim(),
      'message': message,
    };

    final result = await DeliveryAuthService.createSupportTicket(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null && (result['ticketId'] != null || result['_id'] != null)) {
      final ticketNum = result['ticketId'] ?? 'TK-SUBMITTED';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Incident Ticket #$ticketNum dispatched to Super Admin!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _messageCtrl.clear();
      _subjectCtrl.clear();
      _orderCtrl.clear();
      _loadTickets();
      _tabController.animateTo(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit ticket. Please verify connection & try again.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FLEET PARTNER SUPPORT',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Live Incident Dispatch & Payout Help Desk',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCustomTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRaiseTicketTab(),
                _buildMyTicketsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppTheme.primaryOrange,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(text: 'RAISE TICKET'),
            Tab(text: 'MY TICKETS (${_myTickets.length})'),
          ],
        ),
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
          // Quick Hotline Contact Row
          Row(
            children: [
              Expanded(
                child: _contactBanner(
                  icon: Icons.headset_mic_rounded,
                  title: 'DISPATCH HOTLINE',
                  subtitle: 'Super Admin Desk',
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _contactBanner(
                  icon: Icons.emergency_rounded,
                  title: 'SOS EMERGENCY',
                  subtitle: 'Roadside Assist',
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'SELECT INCIDENT CATEGORY',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF475569),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Categories Grid with ample card height
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.08,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              final bool isSelected = _selectedCategory == cat['title'];
              final Color catColor = cat['color'] as Color;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat['title'] as String;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryOrange : const Color(0xFFE2E8F0),
                      width: isSelected ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryOrange.withValues(alpha: 0.12) : catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              cat['icon'] as IconData,
                              color: isSelected ? AppTheme.primaryOrange : catColor,
                              size: 20,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange, size: 18),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: isSelected ? AppTheme.primaryOrange : const Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat['desc'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF94A3B8),
                              height: 1.2,
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

          const SizedBox(height: 24),

          // Order ID (Optional)
          Text(
            'ORDER ID (OPTIONAL)',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF475569),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: TextField(
              controller: _orderCtrl,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. ORD-9821 (Leave empty if general issue)',
                hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.tag_rounded, color: AppTheme.primaryOrange, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Incident Subject
          Text(
            'INCIDENT TITLE / SUBJECT',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF475569),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: TextField(
              controller: _subjectCtrl,
              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
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
          Text(
            'INCIDENT DETAILS & DISPATCH NOTES *',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF475569),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: TextField(
              controller: _messageCtrl,
              maxLines: 4,
              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), height: 1.4),
              decoration: InputDecoration(
                hintText: 'Describe clearly what happened, location, amount or assistance needed...',
                hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Submit Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A00), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitTicket,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              label: Text(
                _isSubmitting ? 'DISPATCHING TICKET...' : 'RAISE INCIDENT TICKET',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white, letterSpacing: 0.8),
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
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(icons.Iconsax.ticket_copy, color: AppTheme.primaryOrange, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'No Incident Tickets Raised',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'Any support issues or payout questions you raise will appear here live with Admin replies.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('RAISE A TICKET', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryOrange,
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _showRiderTicketSheet(t),
              borderRadius: BorderRadius.circular(20),
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
                            Text(
                              ticketId,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: AppTheme.primaryOrange,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (orderDisplayId.toString().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  'Order #$orderDisplayId',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subject,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0F172A)),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 5),
                            Text(
                              '${replies.length} Responses',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text('View & Chat', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange)),
                            const SizedBox(width: 4),
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
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ticketId, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange)),
                              Text(subject, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(bCtx), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: ListView(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOUR INCIDENT REPORT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                                const SizedBox(height: 6),
                                Text(message.isNotEmpty ? message : 'No description provided.', style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF334155), height: 1.35)),
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
                          }),
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
                              hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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

