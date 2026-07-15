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
import 'live_tracking_screen.dart';

class VendorOrdersScreen extends StatelessWidget {
  const VendorOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.lightBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 80,
          title: Text(
            'Orders',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkText,
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
                color: AppTheme.lightSurface,
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
                unselectedLabelColor: AppTheme.lightText,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                splashBorderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(text: 'New Orders'),
                  Tab(text: 'Active'),
                  Tab(text: 'History'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList('Incoming'),
            _buildOrderList('Active'),
            _buildOrderList('History'),
          ],
        ),
      ),
    );
  }


  Widget _buildOrderList(String type) {
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

        if (ordersToShow.isEmpty) {
          return Center(
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
                Text(
                  "Waiting for new orders...",
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.lightText),
                ),
              ],
            ),
          );
        }

        return AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: ordersToShow.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 600),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildOrderCard(context, ordersToShow[index], type, index),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, VendorOrderModel order, String type, int index) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case VendorOrderStatus.pending: statusColor = AppTheme.primaryRed; statusText = 'NEW ORDER'; break;
      case VendorOrderStatus.accepted: statusColor = AppTheme.primaryOrange; statusText = 'CONFIRMED'; break;
      case VendorOrderStatus.preparing: statusColor = AppTheme.accentBlue; statusText = 'PREPARING'; break;
      case VendorOrderStatus.ready: statusColor = AppTheme.accentGreen; statusText = 'READY FOR HANDOVER'; break;
      case VendorOrderStatus.handedOver: statusColor = AppTheme.lightText; statusText = 'HANDED OVER'; break;
      case VendorOrderStatus.rejected: statusColor = AppTheme.primaryRed; statusText = 'REJECTED'; break;
    }

    return GestureDetector(
      key: ValueKey('card_${order.id}'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => VendorOrderDetailScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.cardShadow,
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
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.lightText),
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
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.darkText, height: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.orderType == VendorOrderType.standard 
                          ? '${order.customerName} • ${order.items.length} Items' 
                          : '${order.customerName} • ${order.orderType.name.toUpperCase()}',
                        style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.mediumText, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getAmountDisplay(order, type),
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.darkText),
                    ),
                    if (order.customerPaid)
                      Text(
                        'PAID',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.accentGreen, letterSpacing: 0.5),
                      ),
                  ],
                ),
              ],
            ),
            if (order.status == VendorOrderStatus.pending) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildOrderAction(
                      label: 'ACCEPT ORDER', 
                      color: AppTheme.accentGreen, 
                      onTap: () => context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.accepted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOrderAction(
                      label: 'Decline', 
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
                label: 'START PREPARING', 
                color: AppTheme.accentBlue, 
                onTap: () => context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.preparing),
              ),
            ],
            if (order.status == VendorOrderStatus.preparing) ...[
              const SizedBox(height: 24),
              _buildOrderAction(
                label: 'MAKE AS READY', 
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
          ],
        ),
      ),
    ).animate(key: ValueKey('anim_${order.id}')).fadeIn(delay: (index * 100).ms < 500.ms ? (index * 100).ms : 0.ms).slideX(begin: 0.1, end: 0);
  }

  void _showDeclineConfirmation(BuildContext context, VendorOrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Decline Order?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24, color: AppTheme.darkText),
        ),
        content: Text(
          'Are you sure you want to decline order #${order.displayId}? This action cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.lightText, fontWeight: FontWeight.w500),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.mediumText),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<VendorOrderProvider>().updateOrderStatus(order.id, VendorOrderStatus.rejected);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Yes, Decline',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, ${hour.toString().padLeft(2, '0')}:$min $period';
  }

  String _getAmountDisplay(VendorOrderModel order, String tabType) {
    if (order.totalAmount > 0) {
      return '₹${order.totalAmount.toStringAsFixed(0)}';
    }
    if (tabType == 'History') {
      return 'COMPLETED';
    }
    return 'Pending';
  }
}

