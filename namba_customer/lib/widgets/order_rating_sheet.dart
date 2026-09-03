import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';

class OrderRatingSheet extends StatefulWidget {
  final DeliveryOrder order;
  final VoidCallback? onSubmitted;

  const OrderRatingSheet({
    super.key,
    required this.order,
    this.onSubmitted,
  });

  static Future<void> show(BuildContext context, DeliveryOrder order, {VoidCallback? onSubmitted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderRatingSheet(order: order, onSubmitted: onSubmitted),
    );
  }

  @override
  State<OrderRatingSheet> createState() => _OrderRatingSheetState();
}

class _OrderRatingSheetState extends State<OrderRatingSheet> {
  // Store / Food Rating
  double _vendorRating = 5.0;
  final TextEditingController _vendorCommentCtrl = TextEditingController();
  final Set<String> _selectedVendorTags = {};

  // Driver / Rider Rating
  double _driverRating = 5.0;
  final TextEditingController _driverCommentCtrl = TextEditingController();
  final Set<String> _selectedDriverTags = {};
  double _selectedTip = 0.0;

  bool _isSubmitting = false;

  final List<String> _vendorTagsList = [
    'Delicious & Fresh 🍲',
    'Spill-Proof Packing 📦',
    'Generous Portion 🍱',
    'Served Hot & Crispy 🔥',
    'Value for Money 💰',
    'Fast Preparation ⚡',
  ];

  final List<String> _driverTagsList = [
    'Lightning Fast ⚡',
    'Polite & Courteous 😊',
    'Handled with Care 🛵',
    'Followed Route 📍',
    'Safe Delivery 🛡️',
  ];

  final List<double> _tipOptions = [0.0, 10.0, 20.0, 30.0, 50.0];

  String _getRatingFeedbackText(double rating) {
    if (rating >= 5.0) return 'Outstanding! Loved It! 🔥';
    if (rating >= 4.0) return 'Very Tasty & Good! 😋';
    if (rating >= 3.0) return 'Good / Satisfactory 😊';
    if (rating >= 2.0) return 'Below Expectations 😐';
    return 'Needs Improvement 😞';
  }

  String _getDriverFeedbackText(double rating) {
    if (rating >= 5.0) return 'Hero Rider / 5-Star Champion 🌟';
    if (rating >= 4.0) return 'Super Fast & Polite ⚡';
    if (rating >= 3.0) return 'Good Delivery 👍';
    if (rating >= 2.0) return 'Could Be Better 😐';
    return 'Unsatisfactory 👎';
  }

  @override
  void dispose() {
    _vendorCommentCtrl.dispose();
    _driverCommentCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final customerName = authProvider.name.isNotEmpty ? authProvider.name : 'Customer';

    try {
      await orderProvider.submitRating(
        orderId: widget.order.id,
        vendorRating: _vendorRating,
        vendorReview: _vendorCommentCtrl.text.trim(),
        vendorTags: _selectedVendorTags.toList(),
        driverRating: widget.order.deliveryPartner != null ? _driverRating : null,
        driverReview: _driverCommentCtrl.text.trim(),
        driverTags: _selectedDriverTags.toList(),
        driverTip: _selectedTip,
        customerName: customerName,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSubmitted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Thank you! Your real rating & feedback has been recorded.',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: ', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDriver = widget.order.deliveryPartner != null;
    final storeName = widget.order.storeName;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ── Header Drag Handle ──
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Top Title & Order ID ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Delivered Successfully! 🎉',
                        style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                      ),
                      Text(
                        'Order # • ',
                        style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1),

          // ── Scrollable Body ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                // ════════ 1. VENDOR / FOOD RATING SECTION ════════
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Iconsax.shop_copy, color: Color(0xFF6366F1), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rate ',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                                ),
                                Text(
                                  'How was the food quality & packaging?',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 5 Stars
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            final starVal = index + 1.0;
                            final isFilled = starVal <= _vendorRating;
                            return GestureDetector(
                              onTap: () => setState(() => _vendorRating = starVal),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: Icon(
                                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: isFilled ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                                  size: 42,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          _getRatingFeedbackText(_vendorRating),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Vendor Compliment Tags
                      Text(
                        'WHAT WENT WELL?',
                        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _vendorTagsList.map((tag) {
                          final isSelected = _selectedVendorTags.contains(tag);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedVendorTags.remove(tag);
                                } else {
                                  _selectedVendorTags.add(tag);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Text(
                                tag,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Vendor Comments Box
                      TextField(
                        controller: _vendorCommentCtrl,
                        maxLines: 2,
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Write a compliment or suggestion for the store...',
                          hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ════════ 2. RIDER / DELIVERY PARTNER RATING SECTION ════════
                if (hasDriver) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF10B981), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.order.deliveryPartner?.name ?? 'Delivery Partner',
                                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 15),
                                    ],
                                  ),
                                  Text(
                                    'How was your delivery experience?',
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // 5 Stars for Rider
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              final starVal = index + 1.0;
                              final isFilled = starVal <= _driverRating;
                              return GestureDetector(
                                onTap: () => setState(() => _driverRating = starVal),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: Icon(
                                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isFilled ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                                    size: 42,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            _getDriverFeedbackText(_driverRating),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Rider Badges & Compliments
                        Text(
                          'COMPLIMENT YOUR RIDER',
                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _driverTagsList.map((tag) {
                            final isSelected = _selectedDriverTags.contains(tag);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedDriverTags.remove(tag);
                                  } else {
                                    _selectedDriverTags.add(tag);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF10B981) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text(
                                  tag,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Tip to Rider
                        Row(
                          children: [
                            const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFEC4899), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'TIP YOUR DELIVERY PARTNER (OPTIONAL)',
                              style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: _tipOptions.map((tip) {
                            final isSelected = _selectedTip == tip;
                            final label = tip == 0.0 ? 'None' : '₹';
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () => setState(() => _selectedTip = tip),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFEC4899) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFEC4899) : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Rider Comments Box
                        TextField(
                          controller: _driverCommentCtrl,
                          maxLines: 2,
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Say something nice to ...',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF10B981)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom Fixed Submit Button ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 10),
                          Text(
                            'SUBMIT REAL RATING & FEEDBACK',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
