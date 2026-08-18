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
import '../widgets/cancel_order_dialog.dart';
import '../services/api_service.dart';

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
                if (order.status == OrderStatus.rejected) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Cancelled by ${order.cancelledBy ?? "Customer"}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.red.shade900, fontSize: 14),
                              ),
                              if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty)
                                Text(
                                  'Reason: ${order.cancellationReason}',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.red.shade700, fontSize: 12.5),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                            color: order.isPaymentDone
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: order.isPaymentDone
                                  ? const Color(0xFFBBF7D0)
                                  : const Color(0xFFFCD34D),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    order.isPaymentDone
                                        ? Icons.check_circle_rounded
                                        : Icons.hourglass_top_rounded,
                                    color: order.isPaymentDone ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    order.isPaymentDone
                                        ? 'Delivery Fee Paid: ₹${order.deliveryFee.toInt()} ✅'
                                        : 'Awaiting Quote from Rider',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: order.isPaymentDone ? const Color(0xFF166534) : const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                order.isPaymentDone
                                    ? 'Rider கடைக்குச் சென்று பில் விவரங்களை சரிபார்த்து Quote அனுப்புவார். Quote வந்தவுடன் பொருட்களுக்கான தொகையை செலுத்தவும்.'
                                    : 'Rider கடைக்குச் சென்று பொருட்களை வாங்கி பில் Quote அனுப்பியதும், டெலிவரி கட்டணம் + பொருட்கள் விலை சேர்த்து Pay செய்யவும்.',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: order.isPaymentDone ? const Color(0xFF15803D) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (order.totalAmount > 0 && !order.isPaymentDone && order.status != OrderStatus.rejected) ...[
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
                          Text(
                            (order.deliveryAddress.isEmpty || order.deliveryAddress.toLowerCase().contains('fetching address'))
                                ? 'Pinned Delivery Location'
                                : order.deliveryAddress.replaceAll(RegExp(r'\s*\(-?\d+\.\d+,\s*-?\d+\.\d+\)'), '').replaceAll(RegExp(r'^Current Location\s*'), '').trim(),
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor, height: 1.4),
                          ),
                        ),
                        const Divider(height: 24, color: Color(0xFFF3F4F6)),
                        
                        _orderDetailRow('Order placed', Text('placed on ${DateFormat("d MMM yyyy, h:mm a").format(((order.placedAt as dynamic) ?? DateTime.now()).toLocal())}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (order.statusTimestamps.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order Timeline', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1F2937))),
                          const SizedBox(height: 16),
                          ...[
                            {'title': 'Order Placed', 'status': OrderStatus.placed},
                            {'title': 'Order Confirmed', 'status': OrderStatus.accepted},
                            {'title': 'Preparing Order', 'status': OrderStatus.preparing},
                            {'title': 'Ready for Pickup', 'status': OrderStatus.ready},
                            {'title': 'Out for Delivery', 'status': OrderStatus.outForDelivery},
                            {'title': 'Delivered', 'status': OrderStatus.delivered},
                          ].map((step) {
                            final isDone = order.statusTimestamps.containsKey(step['status']);
                            if (!isDone && step['status'] != order.status) return const SizedBox.shrink();
                            final dt = (order.statusTimestamps[step['status']] ?? (order.placedAt as dynamic) ?? DateTime.now()).toLocal();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: isDone ? const Color(0xFF059669) : Colors.grey.shade300),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(step['title'] as String, style: GoogleFonts.outfit(fontSize: 14, fontWeight: isDone ? FontWeight.w800 : FontWeight.w600, color: isDone ? const Color(0xFF1F2937) : Colors.grey.shade300))),
                                  if (isDone)
                                    Text(DateFormat('h:mm a').format(dt), style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                  // 6. Need help Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Need help with your order?', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondaryColor)),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _showOrderSupportBottomSheet(context, order, provider),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
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
                      Text(DateFormat('h:mm a').format(order.statusTimestamps[step['status']] ?? (order.placedAt as dynamic) ?? DateTime.now()), style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
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

  void _showOrderSupportBottomSheet(BuildContext context, DeliveryOrder order, OrderProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Help & Support', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1F2937))),
                        Text('Order #${order.displayId} • ${order.storeName}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action 1: Cancel Order (If active)
              if (order.status != OrderStatus.delivered && order.status != OrderStatus.rejected) ...[
                _supportOptionTile(
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFEF4444),
                  title: 'Cancel Order (ஆர்டரை ரத்து செய்)',
                  subtitle: 'Select a reason to cancel this order',
                  onTap: () {
                    Navigator.pop(context);
                    CancelOrderDialog.show(
                      context: context,
                      role: 'Customer',
                      onConfirm: (reason) async {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => const Center(
                            child: CircularProgressIndicator(color: Color(0xFFEF4444)),
                          ),
                        );

                        final success = await provider.cancelOrder(order.id, reason);

                        // Dismiss loading indicator
                        if (context.mounted) {
                          Navigator.pop(context);
                        }

                        if (success) {
                          if (context.mounted) {
                            _showCancelSuccessDialog(context, reason);
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to cancel order. Please try again.', style: GoogleFonts.outfit()),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Action 2: Raise Ticket with Customer Care
              _supportOptionTile(
                icon: Icons.confirmation_number_outlined,
                color: const Color(0xFF4F46E5),
                title: 'Raise Support Ticket (புகார் பதிவு செய்ய)',
                subtitle: 'Report missing items, food quality or payment issue',
                onTap: () {
                  Navigator.pop(context);
                  _showRaiseTicketDialog(context, order);
                },
              ),
              const SizedBox(height: 10),

              // Action 3: Call Customer Care Helpline
              _supportOptionTile(
                icon: Icons.phone_in_talk_rounded,
                color: const Color(0xFF10B981),
                title: 'Call Customer Care (வாடிக்கையாளர் சேவை)',
                subtitle: 'Toll-free 1800-123-4567 (24x7 Assistance)',
                onTap: () async {
                  final uri = Uri.parse('tel:18001234567');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
              ),
              const SizedBox(height: 10),

              // Action 4: Call Delivery Partner (if available)
              if (order.deliveryPartner != null && order.deliveryPartner!.phone.isNotEmpty) ...[
                _supportOptionTile(
                  icon: Icons.two_wheeler_rounded,
                  color: const Color(0xFF8B5CF6),
                  title: 'Call Delivery Rider (${order.deliveryPartner!.name})',
                  subtitle: order.deliveryPartner!.phone,
                  onTap: () async {
                    final uri = Uri.parse('tel:${order.deliveryPartner!.phone}');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                ),
                const SizedBox(height: 10),
              ],

              // Refund & Cancellation Policy Box
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '100% Instant Refund for cancellations prior to store preparation. Tickets are resolved within 15 minutes.',
                        style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 11.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showCancelSuccessDialog(BuildContext context, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20.0,
                  offset: const Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFEE2E2), width: 4),
                  ),
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: Color(0xFFEF4444),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Order Cancelled',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'ஆர்டர் ரத்து செய்யப்பட்டது',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Your order has been successfully cancelled.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason for Cancellation:',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: Text(
                      'Done',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRaiseTicketDialog(BuildContext context, DeliveryOrder order) {
    int selectedIssue = 0;
    final issues = [
      '📦 Missing or Incorrect Items (பொருள் விடுபட்டுள்ளது / தவறானது)',
      '🍱 Food Quality / Packaging Damage (உணவுத் தரம் / சேதம்)',
      '🛵 Delivery Delay / Rider Issue (டெலிவரி தாமதம் / ரைடர் பிரச்சனை)',
      '💳 Payment / Double Deduction (கட்டணம் / பணம்திரும்பல்)',
      '✏️ Other Custom Query (மற்றக் கருத்துக்கள் / கேள்விகள்)',
    ];
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Text Customer Support', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFF1E293B))),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Topic / Issue Category:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  ...issues.asMap().entries.map((e) => RadioListTile<int>(
                    value: e.key,
                    groupValue: selectedIssue,
                    activeColor: const Color(0xFF4F46E5),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    onChanged: (val) => setState(() => selectedIssue = val ?? 0),
                  )),
                  const SizedBox(height: 12),
                  Text('Type your message to Customer Care:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12.5, color: const Color(0xFF4F46E5))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    style: GoogleFonts.outfit(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Type your message or issue description here (உங்கள் மெசேஜை டைப் செய்யவும்)...',
                      hintStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final messageText = noteController.text.trim();
                  Navigator.pop(ctx);
                  
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (c) => const Center(child: CircularProgressIndicator()),
                  );

                  final apiService = CustomerApiService();
                  final ticketData = {
                    'userType': 'Customer',
                    'userId': apiService.customerId ?? 'unknown_id',
                    'userName': apiService.customerName ?? 'Customer',
                    'userPhone': apiService.customerPhone ?? 'Unknown',
                    'orderId': order.id,
                    'issueType': issues[selectedIssue].split(' (')[0].replaceAll(RegExp(r'[^a-zA-Z\s\/]'), '').trim(),
                    'message': messageText,
                  };
                  
                  final result = await apiService.createSupportTicket(ticketData);
                  Navigator.pop(context);
                  
                  final ticketId = (result != null && result['ticketId'] != null) 
                    ? result['ticketId'] 
                    : 'TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                  
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                      title: Text('Ticket Registered!', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ticket #$ticketId has been created successfully.', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)), textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          if (messageText.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                              child: Text('"$messageText"', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text('Our Customer Care executive will review your text message and respond within 15 minutes.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
                        ],
                      ),
                      actions: [
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(c),
                            child: Text('Done', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Text('Send Message', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }
}
