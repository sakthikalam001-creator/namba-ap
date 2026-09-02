import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../services/delivery_auth_service.dart';
import '../../theme/app_theme.dart';

class RiderTicketChatScreen extends StatefulWidget {
  final Map<String, dynamic> initialTicket;

  const RiderTicketChatScreen({super.key, required this.initialTicket});

  @override
  State<RiderTicketChatScreen> createState() => _RiderTicketChatScreenState();
}

class _RiderTicketChatScreenState extends State<RiderTicketChatScreen> {
  late Map<String, dynamic> _ticket;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSending = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _ticket = widget.initialTicket;
    _startLivePoller();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startLivePoller() {
    _poller = Timer.periodic(const Duration(seconds: 3), (_) async {
      final ticketId = _ticket['_id'] ?? _ticket['id'];
      if (ticketId != null) {
        final updated = await DeliveryAuthService.fetchTicketById(ticketId.toString());
        if (updated != null && mounted) {
          final int prevCount = (_ticket['replies'] as List?)?.length ?? 0;
          final int newCount = (updated['replies'] as List?)?.length ?? 0;
          setState(() {
            _ticket = updated;
          });
          if (newCount > prevCount) {
            _scrollToBottom();
          }
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply([String? customText]) async {
    final text = (customText ?? _msgCtrl.text).trim();
    if (text.isEmpty || _isSending) return;

    final ticketId = (_ticket['_id'] ?? _ticket['id'])?.toString();
    if (ticketId == null) return;

    setState(() => _isSending = true);
    if (customText == null) _msgCtrl.clear();

    final sender = _ticket['userName'] ?? 'Rider Partner';
    final success = await DeliveryAuthService.replyToTicket(ticketId, sender, text);

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        final updated = await DeliveryAuthService.fetchTicketById(ticketId);
        if (updated != null && mounted) {
          setState(() => _ticket = updated);
          _scrollToBottom();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Please retry.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketId = _ticket['ticketId'] ?? ('#TK-${(_ticket['_id'] ?? '').toString().substring(0, 6).toUpperCase()}');
    final status = (_ticket['status'] ?? 'Open').toString();
    final replies = List<Map<String, dynamic>>.from(_ticket['replies'] ?? []);
    final isResolved = status.toLowerCase() == 'resolved' || status.toLowerCase() == 'closed';

    Color statusColor = const Color(0xFFF59E0B);
    if (status.toLowerCase() == 'in progress') statusColor = const Color(0xFF3B82F6);
    if (isResolved) statusColor = const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
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
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ticketId,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: statusColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _ticket['issueType'] ?? _ticket['category'] ?? 'Super Admin Desk',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            // Resolved Celebration Banner
            if (isResolved)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                color: const Color(0xFFDCFCE7),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Admin resolved this ticket & unlocked your account! You can log in now.',
                        style: GoogleFonts.outfit(color: const Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

            // Live Chat Messages
            Expanded(
              child: replies.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                              child: const Icon(Icons.headset_mic_rounded, size: 36, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(height: 14),
                            Text('Connected to Super Admin Desk', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            Text(
                              'Super Admin will review your request and reply shortly in this chat.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      physics: const BouncingScrollPhysics(),
                      itemCount: replies.length,
                      itemBuilder: (context, idx) {
                        final r = replies[idx];
                        final role = (r['senderRole'] ?? '').toString().toLowerCase();
                        final bool isAdmin = role.contains('admin') || role.contains('executive');
                        final senderName = isAdmin ? 'Super Admin Desk 🛡️' : 'You (Rider)';
                        final timeStr = _formatReplyTime(r['createdAt']);

                        return Align(
                          alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                            child: Column(
                              crossAxisAlignment: isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    senderName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: isAdmin ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isAdmin ? Colors.white : const Color(0xFF4F46E5),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: Radius.circular(isAdmin ? 4 : 20),
                                      bottomRight: Radius.circular(isAdmin ? 20 : 4),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isAdmin ? 0.04 : 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                    border: isAdmin ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['message'] ?? '',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: isAdmin ? const Color(0xFF0F172A) : Colors.white,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          timeStr,
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: isAdmin ? const Color(0xFF94A3B8) : Colors.white70,
                                          ),
                                        ),
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
            ),

            // Quick Prompt Chips
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _buildQuickChip('🔓 Please unlock my account'),
                  _buildQuickChip('🔄 I reinstalled the app'),
                  _buildQuickChip('📱 Changed my mobile phone'),
                  _buildQuickChip('🙏 Thank you Admin'),
                ],
              ),
            ),

            // Message Input Bar with Bottom Safety
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -3))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _msgCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Type your message to Admin...',
                          hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendReply(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _sendReply(),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: _isSending
                          ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _sendReply(text),
      ),
    );
  }

  String _formatReplyTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }
}
