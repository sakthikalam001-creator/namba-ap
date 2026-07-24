import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/order_provider.dart';
import 'payment_screen.dart';
import 'order_tracking_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final fmt = (double v) => '₹${v.toStringAsFixed(0)}';
    const Color primaryColor = Color(0xFF4F46E5); 
    const Color secondaryColor = Color(0xFF1F2937);

    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final order = provider.orders.firstWhere((o) => o.id == orderId);

        // Ensure we are in the socket room for this order for live updates
        if (order.status != OrderStatus.delivered && order.status != OrderStatus.rejected) {
          Future.microtask(() => provider.joinOrderRoom(orderId));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: secondaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('ORDER DETAILS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            centerTitle: true,
            actions: [
              if (order.status != OrderStatus.delivered && order.status != OrderStatus.rejected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order))),
                    child: Text('TRACK LIVE', style: GoogleFonts.outfit(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Order ID & Status Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.storeName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: secondaryColor)),
                              const SizedBox(height: 4),
                              Text('ID: ${order.displayId}', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          _statusBadge(order.status),
                        ],
                      ),
                      const Divider(height: 48, color: Color(0xFFF3F4F6)),
                      _statusTimeline(order),
                    ],
                  ),
                ),
                const SizedBox(height: 24),



                // 3. Order Items Section (Premium Invoice Style)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORDER SUMMARY', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                      const SizedBox(height: 20),
                      if (order.orderType == OrderType.standard) ...[
                        ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Iconsax.box_copy, color: primaryColor, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: secondaryColor)),
                                    Text('Quantity: ${item.quantity}', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Text(fmt(item.total), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: secondaryColor)),
                            ],
                          ),
                        )),
                      ] else ...[
                         // Professional display for Custom/Text/Photo items
                         if (order.textContent != null && order.textContent!.isNotEmpty) ...[
                           Container(
                             padding: const EdgeInsets.all(20),
                             decoration: BoxDecoration(
                               color: const Color(0xFFF9FAFB),
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(color: const Color(0xFFE5E7EB)),
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   children: [
                                     const Icon(Iconsax.receipt_text_copy, color: primaryColor, size: 18),
                                     const SizedBox(width: 10),
                                     Text('ITEMS REQUESTED', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 1)),
                                   ],
                                 ),
                                 const SizedBox(height: 16),
                                 Text(
                                   order.textContent!, 
                                   style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor, height: 1.6),
                                 ),
                               ],
                             ),
                           ),
                           const SizedBox(height: 20),
                         ],
                         
                         if (order.orderType == OrderType.photo && order.photoPath != null) ...[
                           Text('PHOTO REQUEST', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1)),
                           const SizedBox(height: 12),
                           ClipRRect(
                             borderRadius: BorderRadius.circular(20),
                             child: Image.file(
                               File(order.photoPath!),
                               width: double.infinity,
                               height: 200,
                               fit: BoxFit.cover,
                               errorBuilder: (_, __, ___) => Container(
                                 height: 100, 
                                 width: double.infinity, 
                                 decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                                 child: const Center(child: Icon(Iconsax.image_copy, color: Colors.grey)),
                               ),
                             ),
                           ),
                         ],
                        ],
                      if (order.totalAmount > 0) ...[
                        const Divider(height: 32, color: Color(0xFFF3F4F6)),
                        Text('Bill details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: secondaryColor)),
                        const SizedBox(height: 16),
                        Builder(builder: (context) {
                          double itemsSum = order.items.fold(0.0, (sum, i) => sum + i.total);
                          double mrp = itemsSum > 0
                              ? itemsSum
                              : (order.subTotal > 0
                                  ? order.subTotal
                                  : (order.totalAmount - order.platformFee - order.deliveryFee).clamp(0.0, double.infinity));
                          double itemTotal = mrp - order.discount;

                          return Column(
                            children: [
                              _priceRow('MRP', mrp, secondaryColor),
                              if (order.discount > 0) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Product discount', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6))),
                                    Text('-₹${order.discount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF3B82F6))),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              _priceRow('Item total', itemTotal, secondaryColor),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Handling charge', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor.withOpacity(0.8))),
                                  Text('+₹${order.platformFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: secondaryColor)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Delivery charges', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor.withOpacity(0.8))),
                                  Text(order.deliveryFee == 0 ? 'FREE' : '₹${order.deliveryFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: order.deliveryFee == 0 ? const Color(0xFF10B981) : secondaryColor)),
                                ],
                              ),
                            ],
                          );
                        }),
                        const Divider(height: 24, color: Color(0xFFF3F4F6)),
                        Builder(builder: (context) {
                          double itemsSumFinal = order.items.fold(0.0, (sum, i) => sum + i.total);
                          double mrpFinal = itemsSumFinal > 0
                              ? itemsSumFinal
                              : (order.subTotal > 0
                                  ? order.subTotal
                                  : (order.totalAmount - order.platformFee - order.deliveryFee).clamp(0.0, double.infinity));
                          double itemTotalFinal = mrpFinal - order.discount;
                          double billTotal = itemTotalFinal + order.platformFee + order.deliveryFee;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Bill total', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondaryColor)),
                              Text(fmt(billTotal), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: secondaryColor)),
                            ],
                          );
                        }),
                      ] else ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Awaiting Quote from Shop', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFFB45309))),
                                    const SizedBox(height: 2),
                                    Text('The shop will send the bill total shortly.', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFFD97706))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (order.orderType != OrderType.standard && order.totalAmount > 0 && !order.isPaymentDone && order.status != OrderStatus.rejected) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(order: order))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor, 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text('PAY NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                          ),
                        ),
                      ] else if (order.status == OrderStatus.rejected) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 8),
                              Text('ORDER CANCELLED', style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Bill Photo Section (If uploaded by driver)
                if (order.billPhotoPath != null && order.billPhotoPath!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Iconsax.receipt_2_copy, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 12),
                            Text('VERIFIED BILL', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF10B981), letterSpacing: 1.5)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            order.billPhotoPath!.startsWith('http') 
                                ? order.billPhotoPath! 
                                : 'http://100.53.131.76:5000${order.billPhotoPath}', // Fallback to backend URL
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100, 
                              width: double.infinity, 
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                              child: const Center(child: Icon(Iconsax.image_copy, color: Colors.grey)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('This bill was uploaded by the rider at pickup.', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Rider Section (If Assigned)
                if (order.deliveryPartner != null) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DELIVERY PARTNER', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                              child: const Icon(Iconsax.user_copy, color: primaryColor, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order.deliveryPartner!.name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: secondaryColor)),
                                  Text('Delivery Partner', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => launchUrl(Uri.parse('tel:${order.deliveryPartner!.phone}')),
                              icon: const Icon(Iconsax.call_copy, color: primaryColor, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                  // 5. Order Details Section (Replacing Delivery Details)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondaryColor)),
                        const SizedBox(height: 20),
                        
                        _orderDetailRow('Order id', Row(
                          children: [
                            Text(order.displayId, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor)),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                          ],
                        )),
                        const Divider(height: 24, color: Color(0xFFF3F4F6)),
                        
                        _orderDetailRow('Payment', Text(order.isPaymentDone ? 'Paid online' : 'Pay on Delivery', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor))),
                        const Divider(height: 24, color: Color(0xFFF3F4F6)),
                        
                        _orderDetailRow(
                          'Deliver to',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (order.deliveryAddress.isEmpty || order.deliveryAddress.toLowerCase().contains('fetching address'))
                                    ? 'Location Pinned (Erode)'
                                    : order.deliveryAddress,
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor, height: 1.4),
                              ),
                              if (order.customerLat != null && order.customerLng != null && order.customerLat != 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'GPS Pinned (${order.customerLat!.toStringAsFixed(4)}, ${order.customerLng!.toStringAsFixed(4)})',
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 24, color: Color(0xFFF3F4F6)),
                        
                        _orderDetailRow('Order placed', Text('placed on ${DateFormat("EEE, d MMM''yy, h:mm a").format(order.placedAt)}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6. Need help Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Need help with your order?', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondaryColor)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Color(0xFFF9FAFB), shape: BoxShape.circle),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black87, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Chat with us', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: secondaryColor)),
                                  Text('About any issues related to your order', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
    );
  }



  Widget _statusBadge(OrderStatus s) {
    final color = {
      OrderStatus.placed: const Color(0xFF6366F1),
      OrderStatus.accepted: const Color(0xFF3B82F6),
      OrderStatus.preparing: const Color(0xFF6366F1),
      OrderStatus.assigned: const Color(0xFF8B5CF6),
      OrderStatus.ready: const Color(0xFFEC4899),
      OrderStatus.pickedUp: const Color(0xFF8B5CF6),
      OrderStatus.outForDelivery: const Color(0xFF8B5CF6),
      OrderStatus.arrived: const Color(0xFF10B981),
      OrderStatus.delivered: const Color(0xFF10B981),
      OrderStatus.rejected: const Color(0xFFEF4444),
    }[s] ?? const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(s.name.toUpperCase(), style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _statusTimeline(DeliveryOrder order) {
    final steps = [
      {'title': 'Order Placed', 'status': OrderStatus.placed},
      {'title': 'Order Confirmed', 'status': OrderStatus.accepted},
      {'title': 'Order Preparing', 'status': OrderStatus.preparing},
      {'title': 'Rider Assigned', 'status': OrderStatus.assigned},
      {'title': 'Order Ready', 'status': OrderStatus.ready},
      {'title': 'Picked Up', 'status': OrderStatus.pickedUp},
      {'title': 'On Way', 'status': OrderStatus.outForDelivery},
      {'title': 'Delivered', 'status': OrderStatus.delivered},
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

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final bool isDone = index <= currentIdx;
        final bool isLast = index == steps.length - 1;
        const Color accentColor = Color(0xFF6366F1);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: isDone ? accentColor : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDone ? accentColor : Colors.grey.shade200, width: 2),
                    ),
                    child: isDone ? const Icon(Icons.check, color: Colors.white, size: 10) : null,
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 2, color: isDone ? accentColor : Colors.grey.shade100)),
                ],
              ),
              const SizedBox(width: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step['title'] as String, style: GoogleFonts.outfit(fontSize: 14, fontWeight: isDone ? FontWeight.w800 : FontWeight.w600, color: isDone ? const Color(0xFF1F2937) : Colors.grey.shade300)),
                    if (isDone)
                      Text(DateFormat('h:mm a').format(order.statusTimestamps[step['status']] ?? order.placedAt), style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _priceRow(String label, double value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: color.withOpacity(0.8))),
        Text('₹${value.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _quoteRow(String label, String value, {bool strikethrough = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isGreen ? const Color(0xFF10B981) : Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              color: isGreen ? const Color(0xFF10B981) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              decoration: strikethrough ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderDetailRow(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
