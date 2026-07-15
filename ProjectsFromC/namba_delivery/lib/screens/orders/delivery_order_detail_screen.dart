import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/voice_dispatch_service.dart';
import '../../services/delivery_auth_service.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';
import '../map/order_tracking_map_screen.dart';

class DeliveryOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const DeliveryOrderDetailScreen({super.key, required this.orderId});

  @override
  State<DeliveryOrderDetailScreen> createState() => _DeliveryOrderDetailScreenState();
}

class _DeliveryOrderDetailScreenState extends State<DeliveryOrderDetailScreen> {
  String? _localPickedPath; // Tracks image before confirmation

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();

    // 1. Check incoming (just assigned, not yet picked up)
    final incomingIdx = provider.incomingRequests.indexWhere((o) => o.id == widget.orderId);
    if (incomingIdx != -1) {
      final coreOrder = provider.incomingRequests[incomingIdx];
      return _buildIncomingOrderUI(context, coreOrder, provider);
    }

    // 2. Check Active orders (Assigned, Preparing, PickedUp, etc.)
    final activeIdx = provider.activeOrders.indexWhere((o) => o.id == widget.orderId);
    if (activeIdx != -1) {
      final dOrder = provider.activeOrders[activeIdx];
      return _buildActiveOrderUI(context, dOrder, provider);
    }

    // 3. Check Order History (Delivered, Cancelled)
    final historyIdx = provider.orderHistory.indexWhere((o) => o.id == widget.orderId);
    if (historyIdx != -1) {
      final hOrder = provider.orderHistory[historyIdx];
      // If it's in history and delivered, show completion
      if (hOrder.status.index == 7) { // Delivered
        return _buildCompletedUI(context);
      }
      // Otherwise show some status message or history details (simplified here to history check)
    }

    // 4. Default / Transition state - Show Loading while syncing
    // This prevents "Order Completed" from flashing during sync transitions
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryOrange),
            const SizedBox(height: 24),
            Text('Syncing order details...', 
              style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedUI(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 80),
          const SizedBox(height: 16),
          Text('Order Completed!', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
        ]),
      ),
    );
  }

  // ── INCOMING ORDER — Accept/Decline View ──────────────────────────────────
  Widget _buildIncomingOrderUI(BuildContext context, dynamic order, DeliveryProvider provider) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: Image.network(
                'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?q=80&w=2000&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppTheme.softShadow),
                        child: const Icon(Icons.close_rounded, color: AppTheme.darkText, size: 20)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        const Icon(icons.Iconsax.clock_copy, color: AppTheme.primaryOrange, size: 14),
                        const SizedBox(width: 8),
                        Text('RESPOND QUICKLY', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ]),
                ),
                const Spacer(),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 40, offset: Offset(0, -10))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 32),

                      // Earning + Distance
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('POTENTIAL EARNING', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                            Text('₹', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text(order.total.toStringAsFixed(0), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1)),
                          ]),
                        ]),
                        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(20)),
                          child: Column(children: [
                            const Icon(icons.Iconsax.routing_copy, color: AppTheme.accentGreen, size: 24),
                            const SizedBox(height: 4),
                            Text('${order.items.length} ITEMS', style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w900, fontSize: 12)),
                          ])),
                      ]),
                      const SizedBox(height: 28),

                      // Item List
                      if (order.items.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: order.items.map<Widget>((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(
                                  '${item.product.name} × ${item.quantity}',
                                  style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w700),
                                )),
                              ]),
                            )).toList(),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Payment Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: (order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              order.paymentMethod == 'COD' ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                              color: order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              order.paymentMethod == 'COD' ? 'CASH ON DELIVERY' : 'ONLINE PAYMENT RECEIVED',
                              style: GoogleFonts.outfit(
                                color: order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      _buildRouteStop(icons.Iconsax.shop_copy, 'STORE', order.store.name.toUpperCase(), AppTheme.primaryOrange),
                      const SizedBox(height: 12),
                      _buildRouteStop(icons.Iconsax.user_copy, 'DROP-OFF', 'CUSTOMER', AppTheme.accentGreen),
                      const SizedBox(height: 32),

                      // DECLINE | ACCEPT
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              await provider.declineAssignment(order.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Center(child: Text('DECLINE', style: GoogleFonts.outfit(color: Colors.red.shade500, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () async {
                              VoiceDispatchService.missionAccepted();
                              await provider.acceptAssignment(order.id);
                              // Screen transitions automatically via provider sync!
                            },
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppTheme.accentGreen, Color(0xFF00C853)]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                              ),
                              child: Center(child: Text('ACCEPT ORDER', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1))),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ).animate().slideY(begin: 1.0, end: 0, curve: Curves.easeOutBack, duration: 600.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ACTIVE ORDER — Live Status + Action Buttons ───────────────────────────
  Widget _buildActiveOrderUI(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final isPickedUp = order.status == DeliveryStatus.pickedUp ||
        order.status == DeliveryStatus.onTheWay ||
        order.status == DeliveryStatus.delivered;

    final orderLabel = order.displayId.isNotEmpty ? '#${order.displayId}' : '#${order.id.substring(order.id.length - 6).toUpperCase()}';

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('ORDER $orderLabel', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Special Notification for Any Shop Orders
            if (order.isCustomStore)
              _buildCustomOrderBanner(order),

            // Notification for Specific Vendor Text/Photo Orders
            if (!order.isCustomStore && order.orderType != 'Cart')
               Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.1)),
                ),
                child: Row(children: [
                  const Icon(icons.Iconsax.info_circle_copy, color: AppTheme.primaryOrange, size: 18),
                  const SizedBox(width: 12),
                  Text('CUSTOM ORDER (TEXT/PHOTO)', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                ]),
              ),

            // Live Status Tracker
            _buildLiveStatusTracker(order),
            const SizedBox(height: 32),

            // Text/Photo Content (if any)
            if (order.orderType != 'Cart' && order.textContent != null)
              _buildOrderContentCard(order),
            
            const SizedBox(height: 24),

            // Pickup location
            _buildRouteStop(
              icons.Iconsax.shop_copy, 
              'PICKUP FROM', 
              order.storeName, 
              AppTheme.primaryOrange, 
              subtext: order.storeAddress.isNotEmpty ? order.storeAddress : null, 
              hasActions: true,
              onNavigate: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => OrderTrackingMapScreen(orderId: widget.orderId, focusOnCustomer: false)),
              ),
            ),
            const SizedBox(height: 12),

            // Deliver to (locked until picked up)
            if (isPickedUp)
              _buildRouteStop(
                icons.Iconsax.user_copy, 
                'DELIVER TO', 
                order.customerName, 
                AppTheme.accentGreen, 
                subtext: order.customerAddress, 
                hasActions: true,
                onNavigate: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => OrderTrackingMapScreen(orderId: widget.orderId, focusOnCustomer: true)),
                ),
              )
            else
              _buildRouteStop(icons.Iconsax.lock_circle_copy, 'DELIVER TO', 'LOCKED UNTIL PICKUP', Colors.grey.shade400, isLocked: true),

            const SizedBox(height: 32),

            // Order items & total
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppTheme.softShadow),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('ORDER DETAILS', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text(DateFormat('hh:mm a').format(DateTime.now()), style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 8),
                Text(DateFormat('EEEE, dd MMMM').format(DateTime.now()), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Text(item.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                )),
                const Divider(height: 40, color: AppTheme.lightBg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PAYMENT METHOD', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.paymentMethod == 'COD' ? 'CASH ON DELIVERY' : 'ONLINE PAYMENT',
                        style: GoogleFonts.outfit(
                          color: order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL EARNING', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800)),
                    Text(
                      order.totalAmount > 0 
                        ? '₹${order.totalAmount.toStringAsFixed(0)}'
                        : 'WAITING FOR QUOTE', 
                      style: GoogleFonts.outfit(
                        color: order.totalAmount > 0 ? AppTheme.primaryOrange : Colors.grey, 
                        fontSize: 20, 
                        fontWeight: FontWeight.w900
                      )
                    ),
                  ],
                ),
              ]),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),

            // Vendor Payment Request Section (Only for "Any Shop" orders that are paid online and after customer has paid admin)
            if (order.isCustomStore && order.paymentMethod != 'COD' && (order.paymentStatus == 'Completed') && (order.status == DeliveryStatus.allocated || order.status == DeliveryStatus.pickingUp || order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay))
              _buildAdminPaymentSection(context, order, provider),
            
            const SizedBox(height: 24),

            // Bill Photo Section (Only for Text/Photo/Custom orders)
            if ((order.isCustomStore || order.orderType != 'Cart') && 
                (order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay))
              _buildBillUploadSection(context, order, provider),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildActionButton(context, order, provider),
    );
  }

  Widget _buildAdminPaymentSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    if (order.vendorPaymentStatus == 'Completed') {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.2))),
        child: Row(children: [
          const Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VENDOR PAID BY ADMIN', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('You can proceed with the delivery.', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        ]),
      );
    }

    if (order.vendorPaymentDetailsUploadedByDriver) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
        child: Row(children: [
          const CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('WAITING FOR ADMIN PAYMENT', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('Admin is processing the vendor payment.', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(icons.Iconsax.bank_copy, color: const Color(0xFF6366F1), size: 20),
          const SizedBox(width: 10),
          Text('VENDOR PAYMENT', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
        const SizedBox(height: 16),
        Text('Customer paid online. Need Admin to pay the vendor directly?', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _showVendorPaymentDialog(context, order, provider),
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
          label: Text('REQUEST ADMIN PAYMENT', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ]),
    );
  }

  void _showVendorPaymentDialog(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final upiCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Request Vendor Payment', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Send the vendor\'s payment details to Admin.', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 14)),
          const SizedBox(height: 32),
          
          TextField(
            controller: upiCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Vendor UPI Mobile Number',
              hintText: 'e.g. 9876543210',
              prefixIcon: const Icon(Icons.phone_android_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              _showImageSourceDialog(ctx, (path) {
                Navigator.pop(ctx);
                _submitPaymentRequest(context, order, provider, filePath: path);
              });
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('SCAN OR UPLOAD QR CODE'),
          ),
          const SizedBox(height: 24),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              if (upiCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                _submitPaymentRequest(context, order, provider, upiNumber: upiCtrl.text);
              }
            },
            child: Text('SEND NUMBER TO ADMIN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _submitPaymentRequest(BuildContext context, DeliveryOrder order, DeliveryProvider provider, {String? filePath, String? upiNumber}) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)));
    final success = await provider.submitVendorPaymentDetails(order.id, filePath: filePath, upiNumber: upiNumber);
    if (context.mounted) {
      Navigator.pop(context); // close loading
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit request to Admin.')));
      }
    }
  }

  Widget _buildCustomOrderBanner(DeliveryOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(icons.Iconsax.magicpen_copy, color: Color(0xFF6366F1), size: 24),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PERSONAL ASSISTANT ORDER', style: GoogleFonts.outfit(color: const Color(0xFF6366F1), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
          Text('பொருட்களின் விலையை கேட்டு Quote அனுப்பவும்.', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _buildOrderContentCard(DeliveryOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(order.orderType == 'Text' ? 'SHOPPING LIST (TEXT)' : 'PHOTO ORDER DETAILS', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        Text(order.textContent ?? '', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
      ]),
    );
  }

  Widget _buildBillUploadSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SHOP BILL PHOTO', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 20),
        if (order.billPhotoPath != null)
          _buildBillPreview(order.billPhotoPath!)
        else
          _buildUploadPlaceholder(context, order, provider),
      ]),
    );
  }

  Widget _buildBillPreview(String path) {
    // Basic detection for network vs local path
    final isNetwork = path.startsWith('http') || path.startsWith('/public');
    final fullUrl = isNetwork && path.startsWith('/public') 
       ? '${DeliveryAuthService.baseUrl.split('/api').first}$path' 
       : path;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: isNetwork 
            ? Image.network(fullUrl, height: 200, width: double.infinity, fit: BoxFit.cover)
            : Image.file(File(path), height: 200, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 16),
          const SizedBox(width: 8),
          Text('BILL UPLOADED SUCCESSFULLY', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w900)),
        ]),
      ],
    );
  }

  void _showImageSourceDialog(BuildContext context, Function(String path) onImageSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SELECT IMAGE SOURCE', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerOption(icons.Iconsax.camera_copy, 'CAMERA', () async {
                  Navigator.pop(ctx);
                  final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
                                    if (photo != null) {
                    setState(() => _localPickedPath = photo.path);
                    onImageSelected(photo.path);
                  }
                }),
                _pickerOption(icons.Iconsax.image_copy, 'GALLERY', () async {
                  Navigator.pop(ctx);
                  final photo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                                    if (photo != null) {
                    setState(() => _localPickedPath = photo.path);
                    onImageSelected(photo.path);
                  }
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 32),
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: AppTheme.darkText)),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    if (_localPickedPath != null) {
      return _buildPreviewSection(context, order, provider);
    }

    return GestureDetector(
      onTap: () => _showImageSourceDialog(context, (path) {}),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: AppTheme.lightBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2), style: BorderStyle.solid),
        ),
        child: Column(children: [
          const Icon(icons.Iconsax.camera_copy, color: AppTheme.primaryOrange, size: 32),
          const SizedBox(height: 12),
          Text('TAKE PHOTO OF ORIGINAL BILL', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.w900)),
          Text('டெலிவரி செய்வதற்கு முன் பில்லை போட்டோ எடுக்கவும்', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('CONFIRM BILL PHOTO', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(_localPickedPath!),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showImageSourceDialog(context, (path) {}),
                  icon: const Icon(icons.Iconsax.camera_copy, size: 18),
                  label: Text('RE-TAKE', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                    side: const BorderSide(color: AppTheme.primaryOrange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                    );
                    
                    final success = await provider.uploadBillPhoto(order.id, _localPickedPath!);
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      if (success) {
                        setState(() => _localPickedPath = null);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload bill photo.')));
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text('CONFIRM', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── LIVE STATUS TRACKER ──────────────────────────────────────────────────
  Widget _buildLiveStatusTracker(DeliveryOrder order) {
    // Map rawStatus to step index: 0=Assigned, 1=PickedUp, 2=OutForDelivery, 3=Delivered
    final rawStatus = order.rawStatus;

    final List<_StatusStep> steps;
    final int activeIdx;

    bool isAnyShop = order.isCustomStore;
    bool isTextOrPhoto = order.orderType == 'Text' || order.orderType == 'Photo';
    bool isBillUploaded = order.billPhotoPath != null && order.billPhotoPath!.isNotEmpty;

    if (isAnyShop) {
      final isQuoteSent = order.totalAmount > 0;
      final isCustomerPaid = order.paymentStatus == 'Completed';
      final isAdminPaid = order.vendorPaymentStatus == 'Completed';

      // Flow A: Any Shop (Elite Flow)
      steps = [
        _StatusStep('CONFIRMED', Icons.assignment_rounded, true),
        _StatusStep('QUOTE SENT', icons.Iconsax.magicpen_copy, isQuoteSent),
        _StatusStep('CUSTOMER PAID', icons.Iconsax.wallet_3_copy, isCustomerPaid),
        _StatusStep('ADMIN PAID', icons.Iconsax.bank_copy, isAdminPaid),
        _StatusStep('ON THE WAY', icons.Iconsax.routing_copy, rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('DELIVERED', Icons.check_circle_rounded, rawStatus == 'Delivered'),
      ];

      activeIdx = rawStatus == 'Delivered' ? 5 
          : (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') ? 4
          : isAdminPaid ? 3
          : isCustomerPaid ? 3 
          : isQuoteSent ? 2
          : 1; 
    } else if (isTextOrPhoto) {
      // Flow B: Text/Photo for Specific Vendor (Includes Preparing & Bill Upload)
      final isPreparing = rawStatus == 'Preparing' || rawStatus == 'Ready' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered';
      final isReady = rawStatus == 'Ready' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered';

      steps = [
        _StatusStep('CONFIRMED', Icons.assignment_rounded, true),
        _StatusStep('PREPARING', icons.Iconsax.box_copy, isPreparing),
        _StatusStep('READY', icons.Iconsax.box_tick_copy, isReady),
        _StatusStep('BILL UPLOAD', icons.Iconsax.receipt_2_copy, isBillUploaded),
        _StatusStep('ON THE WAY', icons.Iconsax.routing_copy, rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('DELIVERED', Icons.check_circle_rounded, rawStatus == 'Delivered'),
      ];

      activeIdx = rawStatus == 'Delivered' ? 5
          : (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') ? 4
          : isBillUploaded ? 4
          : isReady ? 2
          : isPreparing ? 1
          : 0;
    } else {
      // Flow C: Standard Menu Order
      steps = [
        _StatusStep('CONFIRMED', Icons.assignment_rounded, true),
        _StatusStep('PREPARING', icons.Iconsax.box_copy, rawStatus == 'Preparing' || rawStatus == 'Ready' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('READY', icons.Iconsax.box_tick_copy, rawStatus == 'Ready' || rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('ON THE WAY', icons.Iconsax.routing_copy, rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery' || rawStatus == 'Delivered'),
        _StatusStep('DELIVERED', Icons.check_circle_rounded, rawStatus == 'Delivered'),
      ];

      activeIdx = rawStatus == 'Delivered' ? 4
          : (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') ? 3
          : rawStatus == 'Ready' ? 2
          : rawStatus == 'Preparing' ? 1
          : 0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('LIVE STATUS', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                const SizedBox(width: 6),
                Text('LIVE', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // connector line
                final lineIdx = i ~/ 2;
                final filled = steps[lineIdx + 1].isDone;
                return Expanded(child: Container(height: 2, color: filled ? AppTheme.accentGreen.withValues(alpha: 0.4) : AppTheme.lightBg));
              }
              final stepIdx = i ~/ 2;
              final step = steps[stepIdx];
              final isActive = stepIdx == activeIdx;
              return _buildStatusNode(step.label, step.isDone, step.icon, isActive: isActive);
            }),
          ),
          const SizedBox(height: 12),
          // Current status text
          Center(
            child: Text(
              _getStatusDescription(order, rawStatus),
              style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDescription(DeliveryOrder order, String rawStatus) {
    if (order.isCustomStore) {
      if (rawStatus == 'Delivered') return '🏁 Successfully delivered!';
      if (rawStatus == 'PickedUp' || rawStatus == 'OutForDelivery') return '🚀 Heading to customer';
      if (order.vendorPaymentStatus == 'Completed') return '✅ Vendor paid! You can PICK UP now.';
      if (order.paymentStatus == 'Completed') return '⏳ Waiting for Admin to pay the vendor';
      if (order.totalAmount > 0) return '📱 Quote sent! Waiting for customer confirmation/payment';
      return '📝 Please send a price quote to the customer';
    }

    switch (rawStatus.toLowerCase()) {
      case 'accepted':
      case 'assigned': return '✅ Order confirmed by vendor';
      case 'preparing': return '👨‍🍳 Vendor started preparing your order';
      case 'ready':
      case 'ready for handover': return '📦 Order is ready for handover!';
      case 'pickedup':
      case 'picked up': return '🚀 Order picked up — heading to customer';
      case 'outfordelivery': return '📍 Almost there! Out for delivery';
      case 'delivered': return '🏁 Successfully delivered!';
      default: return rawStatus;
    }
  }

  Widget _buildStatusNode(String label, bool isDone, IconData icon, {bool isActive = false}) {
    Color color = isDone ? AppTheme.accentGreen : (isActive ? AppTheme.primaryOrange : AppTheme.lightBg);

    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isDone ? AppTheme.accentGreen : (isActive ? AppTheme.primaryOrange : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.25), blurRadius: 10)] : null,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : icon,
            color: isDone || isActive ? Colors.white : AppTheme.lightText,
            size: 16,
          ),
        ).animate(target: isActive ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.outfit(
          color: isActive ? AppTheme.primaryOrange : (isDone ? AppTheme.accentGreen : AppTheme.lightText),
          fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildRouteStop(IconData icon, String label, String value, Color color,
      {bool hasActions = false, String? subtext, bool isLocked = false, VoidCallback? onNavigate, VoidCallback? onCall}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLocked ? AppTheme.lightBg : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isLocked ? [] : AppTheme.softShadow,
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey.shade200 : color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isLocked ? Colors.white : color, size: 22)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(color: isLocked ? AppTheme.lightText : AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w900)),
          if (subtext != null && subtext.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtext, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ])),
        if (hasActions)
          Row(children: [
            _buildCircularAction(Icons.call_rounded, AppTheme.lightBg, AppTheme.darkText, onTap: onCall),
            const SizedBox(width: 8),
            _buildCircularAction(Icons.near_me_rounded, color.withValues(alpha: 0.08), color, onTap: onNavigate),
          ]),
      ]),
    );
  }

  Widget _buildCircularAction(IconData icon, Color bg, Color iconColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  // ── BOTTOM ACTION BUTTON ─────────────────────────────────────────────────
  Widget _buildActionButton(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    String label = '';
    DeliveryStatus? next;
    Color color = AppTheme.primaryOrange;
    bool isBlocked = false;

    if (order.status == DeliveryStatus.allocated || order.status == DeliveryStatus.pickingUp) {
      final needsQuote = order.isCustomStore && order.totalAmount == 0;
      
      if (needsQuote) {
        label = 'SEND PRICE QUOTE';
        color = const Color(0xFF6366F1);
        next = null; // Special action
      } else {
        final isReady = order.rawStatus == 'Ready' || order.rawStatus == 'PickedUp' || order.rawStatus == 'Picked Up' || (order.isCustomStore && order.vendorPaymentStatus == 'Completed');
        
        if (order.isCustomStore && !isReady) {
          if (order.totalAmount == 0) {
             label = 'SEND PRICE QUOTE';
             color = const Color(0xFF6366F1);
          } else if (order.paymentStatus == 'Pending' && order.paymentMethod != 'COD') {
             label = 'WAITING FOR CUSTOMER PAYMENT';
             color = Colors.grey.shade400;
          } else {
             label = 'WAITING FOR ADMIN PAYMENT';
             color = Colors.grey.shade400;
          }
          next = null;
        } else {
          label = isReady ? 'PICK UP' : 'WAITING FOR VENDOR';
          next = isReady ? DeliveryStatus.pickedUp : null;
          color = isReady ? AppTheme.primaryOrange : Colors.grey.shade400;
        }
      }
    } else if (order.status == DeliveryStatus.pickedUp || order.status == DeliveryStatus.onTheWay) {
      label = 'DELIVERED';
      next = DeliveryStatus.delivered;
      color = AppTheme.accentGreen;
      
      // BLOCK DELIVERY IF BILL IS NOT UPLOADED for Custom/Text orders
      if ((order.isCustomStore || order.orderType != 'Cart') && order.billPhotoPath == null) {
        isBlocked = true;
      }
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: GestureDetector(
        onTap: isBlocked ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please upload the bill photo before delivering!'))
          );
        } : (label == 'SEND PRICE QUOTE' ? () => _showQuoteDialog(context, order, provider) : (next == null ? null : () async {
          if (next == DeliveryStatus.delivered) {
            // Show simple confirmation dialog (no QR scan)
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text('Confirm Order Delivery?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                content: Text('Confirm that you have successfully delivered this package to the customer.', style: GoogleFonts.outfit()),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('DELIVERED ✓', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              VoiceDispatchService.missionCompleted();
              await provider.updateOrderStatus(order.id, next!);
              if (context.mounted) Navigator.pop(context);
            }
          } else {
            await provider.updateOrderStatus(order.id, next!);
            // If it's a custom store, we skip the intermediate steps usually
            if (context.mounted) Navigator.pop(context);
          }
        })),
        child: Container(
          height: 64,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isBlocked ? Colors.grey.shade300 : color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isBlocked ? [] : [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
            border: isBlocked ? Border.all(color: Colors.grey.shade400, width: 1) : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label, 
                  style: GoogleFonts.outfit(
                    color: isBlocked ? Colors.grey.shade600 : Colors.white, 
                    fontSize: 14, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 1.5
                  )
                ),
                if (isBlocked)
                  Text(
                    'UPLOAD BILL TO PROCEED', 
                    style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 400.ms);
  }

  void _showQuoteDialog(BuildContext context, DeliveryOrder order, DeliveryProvider provider) {
    final TextEditingController amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Enter Total Amount', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min, children: [
          Text('பொருட்களின் மொத்த விலையை (Original Bill Amount) இங்கே பதிவிடவும்.', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.lightText)),
          const SizedBox(height: 20),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange),
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: '0.00',
              filled: true,
              fillColor: AppTheme.lightBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount != null && amount > 0) {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (c) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                );
                final success = await provider.sendQuote(order.id, amount);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send quote.')));
                  }
                }
              }
            },
            child: Text('SEND QUOTE', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _StatusStep {
  final String label;
  final IconData icon;
  final bool isDone;
  _StatusStep(this.label, this.icon, this.isDone);
}
