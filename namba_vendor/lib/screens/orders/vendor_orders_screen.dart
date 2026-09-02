import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/vendor_order_provider.dart';
import '../../models/vendor_order_model.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../widgets/shimmer_loading.dart';
import 'vendor_order_detail_screen.dart';
import '../../widgets/cancel_order_dialog.dart';
import 'live_tracking_screen.dart';
import 'dart:async';
import '../../services/vendor_notification_service.dart';
import '../../services/language_provider.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  Timer? _countdownTimer;
  final Set<String> _playedUrgentSoundOrders = {};

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
      bool needSound = false;

      for (var order in orderProvider.orders) {
        if (order.status == VendorOrderStatus.accepted || order.status == VendorOrderStatus.preparing) {
          if (order.isPrepUrgent && !_playedUrgentSoundOrders.contains(order.id)) {
            _playedUrgentSoundOrders.add(order.id);
            needSound = true;
          }
        }
      }

      if (needSound) {
        try {
          VendorNotificationService().playAlarmSound();
        } catch (e) {
          debugPrint('Error playing urgent prep timer sound: $e');
        }
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
          elevation: 0,
          toolbarHeight: 80,
          title: Text(
            lang.translate('orders'),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
            ),
          ),
          actions: const [
            SizedBox(width: 16),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                splashBorderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(4),
                tabs: [
                  Tab(text: lang.isTamil ? 'புதிய ஆர்டர்கள்' : 'New Orders'),
                  Tab(text: lang.isTamil ? 'செயலில் உள்ளவை' : 'Active'),
                  Tab(text: lang.isTamil ? 'வரலாறு' : 'History'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList('Incoming', lang),
            _buildOrderList('Active', lang),
            _buildOrderList('History', lang),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(String type, LanguageProvider lang) {
    return Consumer<VendorOrderProvider>(
      builder: (context, orderProvider, child) {
        List<VendorOrderModel> ordersToShow = [];
        if (type == 'Incoming') {
          ordersToShow = orderProvider.newOrders;
        } else if (type == 'Active') {
          ordersToShow = orderProvider.preparingOrders;
          ordersToShow.addAll(orderProvider.readyOrders);
        } else if (type == 'History') {
          ordersToShow = orderProvider.pastOrders;
        }

        if (orderProvider.isLoading) {
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 5,
            itemBuilder: (context, index) => const OrderCardShimmer(),
          );
        }

        Widget content;
        if (ordersToShow.isEmpty) {
          content = SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppTheme.lightSurface, shape: BoxShape.circle),
                    child: Icon(Iconsax.document_copy, size: 48, color: AppTheme.lightText),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "No $type orders found",
                    style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.mediumText, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Pull down to refresh...",
                    style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.lightText),
                  ),
                ],
              ),
            ),
          );
        } else {
          content = ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: ordersToShow.length,
            itemBuilder: (context, index) {
              return _buildOrderCard(context, ordersToShow[index], type, index, lang);
            },
          );
        }

        return RefreshIndicator(
          color: AppTheme.primaryOrange,
          onRefresh: () async {
            await orderProvider.refreshOrders();
          },
          child: content,
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, VendorOrderModel order, String type, int index, LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    String statusText;

    switch (order.status) {
      case VendorOrderStatus.pending:
        statusColor = AppTheme.primaryRed;
        statusText = lang.isTamil ? 'புதிய ஆர்டர்' : 'NEW ORDER';
        break;
      case VendorOrderStatus.accepted:
        statusColor = AppTheme.primaryOrange;
        statusText = lang.isTamil ? 'ஏற்கப்பட்டது' : 'CONFIRMED';
        break;
      case VendorOrderStatus.preparing:
        statusColor = AppTheme.accentBlue;
        statusText = lang.isTamil ? 'சமையலில் உள்ளது' : 'PREPARING';
        break;
      case VendorOrderStatus.ready:
        statusColor = AppTheme.accentGreen;
        statusText = lang.isTamil ? 'டெலிவரிக்கு தயார்' : 'READY FOR HANDOVER';
        break;
      case VendorOrderStatus.handedOver:
        statusColor = AppTheme.lightText;
        statusText = lang.isTamil ? 'வழங்கப்பட்டது' : 'HANDED OVER';
        break;
      case VendorOrderStatus.rejected:
        statusColor = AppTheme.primaryRed;
        statusText = lang.isTamil ? 'ரத்து செய்யப்பட்டது' : 'CANCELLED';
        break;
    }

    final itemsText = lang.isTamil ? '${order.items.length} பொருட்கள்' : '${order.items.length} Items';

    return GestureDetector(
      key: ValueKey('card_${order.id}'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => VendorOrderDetailScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isDark ? const Color(0xFF273552) : const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: isDark ? [] : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    statusText,
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 1),
                  ),
                ),
                Text(
                  _formatDateTime(order.timestamp),
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.displayId.startsWith('NM-') ? order.displayId : 'NM-${order.displayId.replaceAll('#', '')}',
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText, height: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.orderType == VendorOrderType.standard 
                          ? '${order.customerName} • $itemsText' 
                          : '${order.customerName} • ${order.orderType.name.toUpperCase()}',
                        style: GoogleFonts.outfit(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getAmountDisplay(order, type),
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText),
                    ),
                    if (order.customerPaid)
                      Text(
                        lang.isTamil ? 'பணம் செலுத்தப்பட்டது' : 'PAID',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accentGreen, letterSpacing: 0.5),
                      ),
                  ],
                ),
              ],
            ),
            _buildPrepTimerBadge(order),
            if (order.status == VendorOrderStatus.pending) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildOrderAction(
                      label: lang.isTamil ? 'ஆர்டரை ஏற்றுக்கொள்' : 'ACCEPT ORDER', 
                      color: AppTheme.accentGreen, 
                      onTap: () => context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.accepted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOrderAction(
                      label: lang.isTamil ? 'நிராகரி' : 'Decline', 
                      color: AppTheme.primaryRed, 
                      isOutlined: true,
                      onTap: () => _showDeclineConfirmation(context, order),
                    ),
                  ),
                ],
              ),
            ],
            if (order.status == VendorOrderStatus.accepted) ...[
              const SizedBox(height: 24),
              _buildOrderAction(
                label: lang.isTamil ? 'சமைக்கத் தொடங்கு' : 'START PREPARING', 
                color: AppTheme.accentBlue, 
                onTap: () => context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.preparing),
              ),
            ],
            if (order.status == VendorOrderStatus.preparing) ...[
              const SizedBox(height: 24),
              _buildOrderAction(
                label: lang.isTamil ? 'தயாராகிவிட்டது' : 'MAKE AS READY', 
                color: AppTheme.primaryOrange, 
                onTap: () => context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.ready),
              ),
            ],
            if (order.status == VendorOrderStatus.ready) ...[
              const SizedBox(height: 24),
              _buildOrderAction(
                label: 'HAND OVER', 
                color: AppTheme.accentGreen, 
                onTap: () => context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.handedOver),
              ),
            ],
            if (order.status == VendorOrderStatus.rejected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cancelled by ${order.cancelledBy ?? "Vendor / Customer"}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.red.shade900, fontSize: 13),
                          ),
                          if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty)
                            Text(
                              'Reason: ${order.cancellationReason}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.red.shade700, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate(key: ValueKey('anim_${order.id}')).fadeIn(delay: (index * 100).ms < 500.ms ? (index * 100).ms : 0.ms).slideX(begin: 0.1, end: 0);
  }

  void _showDeclineConfirmation(BuildContext context, VendorOrderModel order) {
    CancelOrderDialog.show(
      context: context,
      role: 'Vendor',
      onConfirm: (reason) {
        context.read<VendorOrderProvider>().updateOrderStatus(
          order.id, 
          VendorOrderStatus.rejected,
          cancelledBy: 'Vendor',
          cancellationReason: reason,
        );
      },
    );
  }

  Widget _buildOrderAction({required String label, required Color color, required VoidCallback onTap, bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(16),
          border: isOutlined ? Border.all(color: color.withValues(alpha: 0.3), width: 2) : null,
          boxShadow: isOutlined ? [] : [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: isOutlined ? color : Colors.white),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[local.month - 1];
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month ${local.year}, ${hour.toString().padLeft(2, '0')}:$min $period';
  }

  String _getAmountDisplay(VendorOrderModel order, String tabType) {
    // Show only item price (vendor's price) — NOT including delivery charge or platform fee
    // Calculate from items: Σ(price × quantity)
    final double itemsTotal = order.items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
    if (itemsTotal > 0) {
      return '₹${itemsTotal.toStringAsFixed(0)}';
    }
    // Fallback to subTotal if items don't have prices (text/photo orders)
    if (order.subTotal > 0) {
      return '₹${(order.subTotal - order.discount).toStringAsFixed(0)}';
    }
    if (order.totalAmount > 0 && tabType == 'History') {
      return 'COMPLETED';
    }
    if (order.orderType != VendorOrderType.standard) {
      return 'Pending Quote';
    }
    return 'Pending';
  }

  Widget _buildPrepTimerBadge(VendorOrderModel order) {
    if (order.status == VendorOrderStatus.ready || order.status == VendorOrderStatus.handedOver) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.teal.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: Colors.teal.shade800),
            const SizedBox(width: 8),
            Text(
              '✓ PACKED IN ${order.packedTimeFormatted.toUpperCase()}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.teal.shade900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (order.status != VendorOrderStatus.accepted && order.status != VendorOrderStatus.preparing) {
      return const SizedBox.shrink();
    }

    final isUrgent = order.isPrepUrgent;
    final isOverdue = order.isPrepOverdue;
    final remainingStr = order.remainingPrepFormatted;

    Color badgeBg;
    Color textColor;
    IconData icon;
    String label;

    if (isOverdue) {
      badgeBg = Colors.red.shade100;
      textColor = Colors.red.shade900;
      icon = Icons.warning_amber_rounded;
      label = 'PACKING OVERDUE (00:00)';
    } else if (isUrgent) {
      badgeBg = Colors.red.shade600;
      textColor = Colors.white;
      icon = Icons.timer_outlined;
      label = '🚨 PACK NOW: $remainingStr';
    } else {
      badgeBg = Colors.orange.shade50;
      textColor = Colors.orange.shade900;
      icon = Icons.timer_rounded;
      label = '⏱️ Pack Time: $remainingStr';
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUrgent ? Colors.red.shade800 : textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

