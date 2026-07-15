import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/vendor_order_model.dart';

/// Full-featured screen combining:
/// - WhatsApp/Call Contact
/// - Quick Reply Templates
/// - Delivery Partner Assignment
/// - Bulk Order Actions helpers

// ── WhatsApp / Call launcher ──────────────────────────────────────────────
class ContactCustomerSheet extends StatelessWidget {
  final String phone;
  final String customerName;
  final String orderId;
  const ContactCustomerSheet({super.key, required this.phone, required this.customerName, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
          child: Text(customerName[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
        ),
        const SizedBox(height: 12),
        Text(customerName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(phone, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500)),
        Text('Order #$orderId', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _contactBtn(
            icon: Icons.phone_rounded,
            label: 'Call',
            color: const Color(0xFF059669),
            onTap: () {
              _copyOrLaunchPhone(context, phone);
              Navigator.pop(context);
            },
          )),
          const SizedBox(width: 12),
          Expanded(child: _contactBtn(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () {
              _copyOrLaunchWhatsApp(context, phone, orderId);
              Navigator.pop(context);
            },
          )),
          const SizedBox(width: 12),
          Expanded(child: _contactBtn(
            icon: Icons.sms_rounded,
            label: 'SMS',
            color: const Color(0xFF4F46E5),
            onTap: () {
              _copyOrLaunchSMS(context, phone);
              Navigator.pop(context);
            },
          )),
        ]),
        const SizedBox(height: 16),
        _quickRepliesSection(context),
      ]),
    );
  }

  Widget _contactBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _quickRepliesSection(BuildContext context) {
    final replies = [
      '✅ ஆர்டர் confirm! 15 min-ல் ready ஆகும்.',
      '⏳ சற்று நேரம் ஆகும், wait பண்ணுங்கள்.',
      '🚴 Delivery partner கிளம்பிட்டார்!',
      '❌ Sorry, இன்று stock இல்லை.',
      '📦 Order packed and ready for pickup!',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Replies', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
      const SizedBox(height: 10),
      ...replies.map((r) => GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: r));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Copied! Now paste in WhatsApp'),
              backgroundColor: const Color(0xFF25D366),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(children: [
            Expanded(child: Text(r, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600))),
            Icon(Icons.copy_rounded, size: 16, color: Colors.grey.shade400),
          ]),
        ),
      )),
    ]);
  }

  void _copyOrLaunchPhone(BuildContext ctx, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('Phone number copied: $phone'), behavior: SnackBarBehavior.floating),
    );
  }

  void _copyOrLaunchWhatsApp(BuildContext ctx, String phone, String orderId) {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    final msg = 'Hi! Regarding your Namba order #$orderId - ';
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('WhatsApp message copied! Phone: $phone'), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF25D366)),
    );
  }

  void _copyOrLaunchSMS(BuildContext ctx, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text('Phone copied: $phone'), behavior: SnackBarBehavior.floating),
    );
  }
}

// ── Delivery Partner Assignment Sheet ────────────────────────────────────
class AssignDeliveryPartnerSheet extends StatefulWidget {
  final String orderId;
  final String? currentPartner;
  final Function(String name, String phone) onAssign;
  const AssignDeliveryPartnerSheet({super.key, required this.orderId, this.currentPartner, required this.onAssign});

  @override
  State<AssignDeliveryPartnerSheet> createState() => _AssignDeliveryPartnerSheetState();
}

class _AssignDeliveryPartnerSheetState extends State<AssignDeliveryPartnerSheet> {
  int _selectedIdx = -1;
  
  final List<Map<String, dynamic>> _partners = [
    {'name': 'Rajan Kumar', 'phone': '+91 98765 43210', 'rating': 4.8, 'orders': 234, 'status': 'Available'},
    {'name': 'Karthik S', 'phone': '+91 87654 32109', 'rating': 4.6, 'orders': 189, 'status': 'Available'},
    {'name': 'Murugan T', 'phone': '+91 76543 21098', 'rating': 4.9, 'orders': 312, 'status': 'Busy'},
    {'name': 'Selvam R', 'phone': '+91 65432 10987', 'rating': 4.5, 'orders': 156, 'status': 'Available'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Assign Delivery Partner', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        ..._partners.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final isSelected = _selectedIdx == i;
          final isBusy = p['status'] == 'Busy';
          return GestureDetector(
            onTap: isBusy ? null : () => setState(() => _selectedIdx = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade200, width: isSelected ? 2 : 1),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isBusy ? Colors.grey.shade200 : const Color(0xFF4F46E5).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(p['name'][0], style: TextStyle(fontWeight: FontWeight.w900, color: isBusy ? Colors.grey : const Color(0xFF4F46E5), fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBusy ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(p['status'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isBusy ? Colors.orange.shade700 : Colors.green.shade700)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                    Text(' ${p['rating']}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(' • ${p['orders']} orders', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ])),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5)),
              ]),
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _selectedIdx < 0 ? null : () {
              final p = _partners[_selectedIdx];
              widget.onAssign(p['name'], p['phone']);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
              disabledBackgroundColor: Colors.grey.shade200,
            ),
            child: Text('Assign Partner', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

