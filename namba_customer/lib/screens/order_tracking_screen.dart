import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import '../providers/order_provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final DeliveryOrder order;
  const OrderTrackingScreen({super.key, required this.order});
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _dialogShown = false;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showRatingDialog(BuildContext context, DeliveryOrder order, OrderProvider provider) {
    double selectedRating = 5.0;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.star_1_copy, color: Color(0xFF6366F1), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Rate Your Experience',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How was the delivery for your order from ${order.storeName}?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= selectedRating;
                  return GestureDetector(
                    onTap: () {
                      setStateDialog(() {
                        selectedRating = starIndex.toDouble();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isSelected ? Colors.amber : Colors.grey.shade300,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: commentCtrl,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your comments (optional)...',
                  hintStyle: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 13),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.outfit(color: Colors.grey.shade500, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        provider.submitRating(order.id, selectedRating, commentCtrl.text);
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Thank you for your rating!',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );

                        const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.namba.customer';
                        await _launchUrl(playStoreUrl);
                      },
                      child: Text(
                        'SUBMIT & RATE',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final order = orderProvider.orders.firstWhere((o) => o.id == widget.order.id, orElse: () => widget.order);

    if (order.status == OrderStatus.delivered && (order.userRating == null || order.userRating == 0.0) && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRatingDialog(context, order, orderProvider);
      });
    }

    final steps = [
      {'title': 'Order Placed', 'subtitle': 'We have received your order.', 'status': OrderStatus.placed, 'icon': Iconsax.shopping_bag_copy},
      {'title': 'Order Confirmed', 'subtitle': 'Store has confirmed your order.', 'status': OrderStatus.accepted, 'icon': Iconsax.tick_circle_copy},
      {'title': 'Order in Preparation', 'subtitle': 'Preparing your items with care.', 'status': OrderStatus.preparing, 'icon': Iconsax.status_up_copy},
      {'title': 'Rider Assigned', 'subtitle': order.deliveryPartner?.name ?? 'Assigning best rider...', 'status': OrderStatus.assigned, 'icon': Iconsax.user_tag_copy},
      {'title': 'Rider Reached Shop', 'subtitle': 'Rider is collecting your order.', 'status': OrderStatus.ready, 'icon': Iconsax.shop_copy},
      {'title': 'Rider On the Way', 'subtitle': 'Rider is moving towards you.', 'status': OrderStatus.pickedUp, 'icon': Iconsax.routing_copy},
      {'title': 'Order Arrived', 'subtitle': 'Rider is at your location!', 'status': OrderStatus.outForDelivery, 'icon': Iconsax.location_copy},
      {'title': 'Order Delivered', 'subtitle': 'Delivered. Enjoy your meal!', 'status': OrderStatus.delivered, 'icon': Iconsax.cup_copy},
    ];

    int currentIdx = 0;
    switch (order.status) {
      case OrderStatus.placed: currentIdx = 0; break;
      case OrderStatus.accepted: currentIdx = 1; break;
      case OrderStatus.preparing: currentIdx = 2; break;
      case OrderStatus.assigned: currentIdx = 3; break;
      case OrderStatus.ready: currentIdx = 4; break;
      case OrderStatus.pickedUp: currentIdx = 5; break;
      case OrderStatus.outForDelivery: 
      case OrderStatus.arrived: currentIdx = 6; break;
      case OrderStatus.delivered: currentIdx = 7; break;
      case OrderStatus.rejected: currentIdx = -1; break;
    }

    const Color primaryColor = Color(0xFF6366F1); 
    const Color secondaryColor = Color(0xFF1F2937);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map Header Section
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                image: const DecorationImage(
                  image: AssetImage('C:/Users/Admin/.gemini/antigravity/brain/81ef3f00-66e7-4eaa-ac70-ff24dfee9862/premium_delivery_map_ui_1776931915702.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.white],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ),

          // 2. Main Content (Scrollable)
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: secondaryColor, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Iconsax.call_copy, color: primaryColor, size: 18),
                    ),
                    onPressed: () => _launchUrl('tel:${order.deliveryPartner?.phone ?? "919840212345"}'),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).size.height * 0.25)),

              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ETA & Status Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Arriving in', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('15 - 20 MINS', style: GoogleFonts.outfit(color: secondaryColor, fontSize: 28, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(order.status == OrderStatus.delivered ? 'DELIVERED' : 'ON TIME', 
                              style: GoogleFonts.outfit(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Rider Card (If Assigned)
                      if (order.deliveryPartner != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Iconsax.user_copy, color: primaryColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.deliveryPartner!.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: secondaryColor)),
                                    Text('Delivery Partner', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Iconsax.message_2_copy, color: primaryColor),
                                onPressed: () => _launchUrl('https://wa.me/${order.deliveryPartner!.phone}'),
                              ),
                              IconButton(
                                icon: const Icon(Iconsax.call_copy, color: primaryColor),
                                onPressed: () => _launchUrl('tel:${order.deliveryPartner!.phone}'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Timeline
                      Text('TRACKING DETAILS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                      const SizedBox(height: 24),
                      Column(
                        children: List.generate(steps.length, (index) {
                          final step = steps[index];
                          final bool isDone = index <= currentIdx;
                          final bool isActive = index == currentIdx;
                          final bool isLast = index == steps.length - 1;

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                        color: isDone ? primaryColor : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: isDone ? primaryColor : Colors.grey.shade200, width: isActive ? 4 : 2),
                                        boxShadow: isActive ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)] : [],
                                      ),
                                      child: isDone ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                                    ),
                                    if (!isLast)
                                      Expanded(
                                        child: Container(width: 2, color: isDone ? primaryColor : Colors.grey.shade200),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 32),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(step['title'] as String, 
                                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: isActive ? FontWeight.w900 : FontWeight.w700, color: isDone ? secondaryColor : Colors.grey.shade300)),
                                        Text(step['subtitle'] as String, 
                                          style: GoogleFonts.outfit(fontSize: 12, color: isDone ? Colors.grey.shade500 : Colors.grey.shade300, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isDone)
                                  Text(DateFormat('hh:mm a').format(order.statusTimestamps[step['status']] ?? order.placedAt),
                                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // Order Summary Section (Price Breakdown)
                      if (order.orderType != OrderType.standard && order.totalAmount > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ORDER SUMMARY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                              const SizedBox(height: 20),
                              _priceRow('Subtotal', (order.totalAmount - order.platformFee) < 0 ? 0.0 : (order.totalAmount - order.platformFee), secondaryColor),
                              const SizedBox(height: 12),
                              _priceRow('Delivery Fee', order.deliveryFee, secondaryColor),
                              const SizedBox(height: 12),
                              _priceRow('Platform Fee', order.platformFee, secondaryColor),
                              const Divider(height: 32, color: Color(0xFFE5E7EB)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Grand Total', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondaryColor)),
                                      if (order.isPaymentDone)
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                                            const SizedBox(width: 4),
                                            Text('Payment Done', style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                    ],
                                  ),
                                  Text('₹${(order.totalAmount + order.deliveryFee).toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: primaryColor)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],

                      // Rate Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: order.status == OrderStatus.delivered
                              ? () => _showRatingDialog(context, order, orderProvider)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: order.userRating != null && order.userRating! > 0
                                ? const Color(0xFF10B981)
                                : primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(
                            order.userRating != null && order.userRating! > 0
                                ? 'RATED ${order.userRating!.toStringAsFixed(0)} ★'
                                : 'RATE EXPERIENCE',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
        Text('₹${value.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
