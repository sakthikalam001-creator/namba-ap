import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String? _lastFetchedId;

  @override
  void initState() {
    super.initState();
    // Attempt fetch immediately in case customerId is already available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptFetch();
    });
  }

  void _attemptFetch() {
    final orderProvider = context.read<OrderProvider>();
    final cid = orderProvider.customerId;
    if (cid != null && cid != _lastFetchedId) {
      _lastFetchedId = cid;
      orderProvider.fetchOrderHistory();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attemptFetch();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color secondary = Theme.of(context).colorScheme.secondary;

    final orderProvider = context.watch<OrderProvider>();
    final cart = context.read<CartProvider>();
    final isLoading = orderProvider.isLoadingHistory;
    final orders = orderProvider.orders;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        leading: Navigator.canPop(context) ? IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: secondary),
          onPressed: () => Navigator.pop(context),
        ) : null,
        title: Text('ORDER HISTORY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: secondary)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<OrderProvider>().fetchOrderHistory(),
        color: primary,
        child: isLoading && orders.isEmpty
            ? Center(child: CircularProgressIndicator(color: primary))
            : (orders.isEmpty 
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      _buildEmptyOrders(),
                    ],
                  )
                : _buildOrdersList(context, orders, cart, primary, secondary)),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)]), child: const Icon(Iconsax.receipt_2_copy, size: 80, color: Color(0xFFE5E7EB))),
        const SizedBox(height: 24),
        Text('No orders yet', style: GoogleFonts.outfit(color: const Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Your culinary journey starts here!', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        Consumer<OrderProvider>(
          builder: (context, provider, _) => Column(children: [
            Text(
              'Debug ID: ${provider.customerId ?? "NULL"}',
              style: GoogleFonts.outfit(color: Colors.grey.withOpacity(0.3), fontSize: 10),
            ),
            if (provider.lastError != null)
              Text(
                'Status: ${provider.lastError}',
                style: GoogleFonts.outfit(color: Colors.red.withOpacity(0.3), fontSize: 10),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildOrdersList(BuildContext context, List<DeliveryOrder> orders, CartProvider cart, Color primary, Color secondary) {
    final now = DateTime.now();
    bool isToday(DateTime dt) => dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final todayOrders = orders.where((o) => isToday(o.placedAt)).toList();
    final previousOrders = orders.where((o) => !isToday(o.placedAt)).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (todayOrders.isNotEmpty) ...[
          _sectionHeader('TODAY\'S ORDERS'),
          ...todayOrders.map((o) => _orderCard(context, o, cart, primary, secondary)),
          const SizedBox(height: 24),
        ],
        if (previousOrders.isNotEmpty) ...[
          _sectionHeader('PREVIOUS ORDERS'),
          ...previousOrders.map((o) => _orderCard(context, o, cart, primary, secondary)),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 16), child: Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)));
  }

  Widget _orderCard(BuildContext context, DeliveryOrder order, CartProvider cart, Color primary, Color secondary) {
    final statusColor = {
      OrderStatus.placed: const Color(0xFFF59E0B),
      OrderStatus.accepted: const Color(0xFF3B82F6),
      OrderStatus.preparing: const Color(0xFF6366F1),
      OrderStatus.assigned: const Color(0xFF8B5CF6),
      OrderStatus.ready: const Color(0xFFEC4899),
      OrderStatus.pickedUp: const Color(0xFF8B5CF6),
      OrderStatus.outForDelivery: primary,
      OrderStatus.arrived: const Color(0xFF10B981),
      OrderStatus.delivered: const Color(0xFF10B981),
      OrderStatus.rejected: const Color(0xFFEF4444),
    }[order.status] ?? Colors.grey;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(Iconsax.shop_copy, color: primary, size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.storeName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: secondary)),
              Text(DateFormat('dd MMM, hh:mm a').format(order.placedAt), style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(order.status.name.toUpperCase(), style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5))),
          ]),
          const SizedBox(height: 12),
          Text(
            order.orderType == OrderType.standard 
              ? order.items.map((i) => i.product.name).join(', ')
              : (order.textContent ?? (order.orderType == OrderType.photo ? 'Photo Order' : 'Custom Order')),
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 32, color: Color(0xFFF3F4F6)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('₹${order.totalAmount.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: secondary)),
            TextButton.icon(onPressed: () { context.read<OrderProvider>().reorder(order.id, cart); }, icon: const Icon(Iconsax.repeat_copy, size: 14), label: Text('REORDER', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900)), style: TextButton.styleFrom(foregroundColor: primary, padding: EdgeInsets.zero, minimumSize: Size.zero)),
          ]),
        ]),
      ),
    );
  }
}
