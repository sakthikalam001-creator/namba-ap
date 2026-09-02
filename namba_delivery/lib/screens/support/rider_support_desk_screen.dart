import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/delivery_auth_service.dart';
import '../../theme/app_theme.dart';
import 'rider_ticket_chat_screen.dart';

class RiderSupportDeskScreen extends StatefulWidget {
  final String? initialPhone;
  final int initialTabIndex;

  const RiderSupportDeskScreen({
    super.key,
    this.initialPhone,
    this.initialTabIndex = 0,
  });

  @override
  State<RiderSupportDeskScreen> createState() => _RiderSupportDeskScreenState();
}

class _RiderSupportDeskScreenState extends State<RiderSupportDeskScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _messageCtrl;

  late int _activeTab;
  String _selectedCategory = 'Device Locked / Login Issue';
  bool _isSubmitting = false;
  bool _isLoadingTickets = false;
  List<Map<String, dynamic>> _existingTickets = [];

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'Device Locked / Login Issue',
      'title': 'Device Locked',
      'tamil': 'சாதனம் பூட்டப்பட்டது',
      'icon': Icons.phonelink_lock_rounded,
      'color': const Color(0xFFEF4444),
    },
    {
      'id': 'Reinstalled App',
      'title': 'Reinstalled App',
      'tamil': 'ரீ-இன்ஸ்டால் பிரச்சனை',
      'icon': Icons.install_mobile_rounded,
      'color': const Color(0xFF4F46E5),
    },
    {
      'id': 'Changed / Replaced Phone',
      'title': 'Changed Phone',
      'tamil': 'புதிய மொபைல் மாற்றம்',
      'icon': Icons.phone_android_rounded,
      'color': const Color(0xFF0EA5E9),
    },
    {
      'id': 'Account Verification Issue',
      'title': 'Verification Issue',
      'tamil': 'சரிபார்ப்பு உதவி',
      'icon': Icons.verified_user_rounded,
      'color': const Color(0xFF10B981),
    },
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
    _messageCtrl = TextEditingController(
      text: 'My device is locked or I reinstalled the app. Please unlock my driver account on this mobile phone.',
    );

    if (_activeTab == 1 || (_phoneCtrl.text.trim().length >= 10)) {
      _loadTickets();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) return;
    setState(() => _isLoadingTickets = true);
    final tickets = await DeliveryAuthService.fetchMyTickets(phone);
    if (mounted) {
      setState(() {
        _existingTickets = tickets;
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _submitTicket() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await DeliveryAuthService.createSupportTicket({
      'userType': 'DeliveryPartner',
      'userName': name.isNotEmpty ? name : 'Rider Partner',
      'userPhone': phone,
      'issueType': _selectedCategory,
      'category': 'Device Lock Support',
      'priority': 'Urgent',
      'subject': 'Device Lock / Session Support Request',
      'message': message,
    });

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RiderTicketChatScreen(initialTicket: res),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send ticket. Please retry.'), backgroundColor: Colors.red),
        );
      }
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin Support',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -0.3),
                  ),
                  Text(
                    'அட்மின் நேரலை உதவி & சாட் டெஸ்க்',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Top Tab Switcher
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _activeTab == 0
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note_rounded, size: 18, color: _activeTab == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                'RAISE TICKET',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _activeTab == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _activeTab = 1);
                          _loadTickets();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _activeTab == 1
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 18, color: _activeTab == 1 ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text(
                                'MY CHATS & STATUS',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: _activeTab == 1 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: _activeTab == 0 ? _buildRaiseTicketForm() : _buildMyTicketsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaiseTicketForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT ISSUE CATEGORY / பிரச்சனை வகை',
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // 2x2 Responsive Category Tiles Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, idx) {
              final cat = _categories[idx];
              final bool isSelected = _selectedCategory == cat['id'];
              return InkWell(
                onTap: () => setState(() => _selectedCategory = cat['id']),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4F46E5) : (cat['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.white : (cat['color'] as Color),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              cat['title'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cat['tamil'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          Text('RIDER NAME / உங்கள் பெயர்', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          Text('REGISTERED PHONE NUMBER / தொலைபேசி எண்', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '10-digit mobile number',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20, color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          Text('PROBLEM DESCRIPTION / என்ன பிரச்சனை?', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _messageCtrl,
            maxLines: 3,
            style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Describe your issue in detail for Admin to resolve',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
            ),
          ),
          const SizedBox(height: 24),

          // Primary Gradient Button
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSubmitting ? null : _submitTicket,
                borderRadius: BorderRadius.circular(18),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              'SEND TICKET & START LIVE CHAT 💬',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTicketsView() {
    if (_isLoadingTickets) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2.5),
      );
    }

    if (_existingTickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                child: const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 16),
              Text('No Active Tickets Found', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B))),
              const SizedBox(height: 6),
              Text(
                'Raise a new ticket to chat live with Super Admin and resolve device lock issues.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => setState(() => _activeTab = 0),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('RAISE NEW TICKET'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _existingTickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final t = _existingTickets[idx];
        final ticketId = t['ticketId'] ?? ('#TK-${(t['_id'] ?? '').toString().substring(0, 6).toUpperCase()}');
        final status = (t['status'] ?? 'Open').toString();
        final issue = t['issueType'] ?? t['category'] ?? 'Support';
        final replies = (t['replies'] as List?) ?? [];
        final lastMsg = replies.isNotEmpty ? (replies.last['message'] ?? '') : (t['message'] ?? '');

        Color statusColor = const Color(0xFFF59E0B);
        if (status.toLowerCase() == 'in progress') statusColor = const Color(0xFF3B82F6);
        if (status.toLowerCase() == 'resolved' || status.toLowerCase() == 'closed') statusColor = const Color(0xFF10B981);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RiderTicketChatScreen(initialTicket: t)),
              );
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF0F172A))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(issue, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF4F46E5))),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('OPEN LIVE CHAT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFF4F46E5), letterSpacing: 0.6)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
