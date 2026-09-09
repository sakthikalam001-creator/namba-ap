import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
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
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);
    final isDark = theme.isDarkMode;

    final Color primary = Theme.of(context).colorScheme.primary;

    final orderProvider = context.watch<OrderProvider>();
    final cart = context.read<CartProvider>();
    final isLoading = orderProvider.isLoadingHistory;
    final orders = orderProvider.orders;

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: theme.cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          lang.translate('order_history').toUpperCase(),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
            color: theme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<OrderProvider>().fetchOrderHistory(),
        color: primary,
        child: isLoading && orders.isEmpty
            ? Center(child: CircularProgressIndicator(color: primary))
            : (orders.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                      _buildEmptyOrders(theme, lang, isDark),
                    ],
                  )
                : _buildOrdersList(context, orders, cart, primary, theme, lang, isDark)),
      ),
    );
  }

  Widget _buildEmptyOrders(ThemeProvider theme, CustomerLanguageProvider lang, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: theme.borderCol),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Iconsax.receipt_2_copy,
                size: 72,
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              lang.translate('no_orders_yet'),
              style: GoogleFonts.outfit(
                color: theme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('culinary_journey'),
              style: GoogleFonts.outfit(
                color: theme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    List<DeliveryOrder> orders,
    CartProvider cart,
    Color primary,
    ThemeProvider theme,
    CustomerLanguageProvider lang,
    bool isDark,
  ) {
    final now = DateTime.now();
    bool isToday(DateTime dt) => dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final todayOrders = orders.where((o) => isToday(o.placedAt)).toList();
    final previousOrders = orders.where((o) => !isToday(o.placedAt)).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (todayOrders.isNotEmpty) ...[
          _sectionHeader(lang.translate('todays_orders'), theme),
          ...todayOrders.map((o) => _orderCard(context, o, cart, primary, theme, isDark)),
          const SizedBox(height: 24),
        ],
        if (previousOrders.isNotEmpty) ...[
          _sectionHeader(lang.translate('previous_orders'), theme),
          ...previousOrders.map((o) => _orderCard(context, o, cart, primary, theme, isDark)),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _sectionHeader(String title, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 14),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: theme.textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _orderCard(
    BuildContext context,
    DeliveryOrder order,
    CartProvider cart,
    Color primary,
    ThemeProvider theme,
    bool isDark,
  ) {
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

    final bool isMapPin = order.orderType == OrderType.mapPin || order.isCustomStore;
    final displayStore = order.customStoreName?.isNotEmpty == true
        ? order.customStoreName!
        : (order.storeName.isNotEmpty ? order.storeName : (isMapPin ? 'Pinned Shop Location' : 'Store'));

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isMapPin
                ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                : theme.borderCol,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMapPin) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 4),
                    Text(
                      '📍 MAP PIN PICKUP',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4F46E5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (isMapPin ? const Color(0xFF4F46E5) : primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isMapPin ? Icons.storefront_rounded : Iconsax.shop_copy,
                    color: isMapPin ? const Color(0xFF4F46E5) : primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayStore,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(((order.placedAt as dynamic) ?? DateTime.now()).toLocal()),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.status.name.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.orderType == OrderType.standard
                  ? order.items.map((i) => i.product.name).join(', ')
                  : (order.textContent?.isNotEmpty == true
                      ? order.textContent!
                      : (order.orderType == OrderType.photo ? '📷 Photo Order' : '📍 Map Pin Pickup Order')),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: theme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Divider(height: 24, color: theme.borderCol),
            Builder(
              builder: (context) {
                final double itemsCost = order.items.fold(0.0, (sum, i) => sum + i.total) > 0
                    ? order.items.fold(0.0, (sum, i) => sum + i.total)
                    : order.subTotal;
                final bool isQuotePending = isMapPin && itemsCost <= 0 && (order.billPhotoPath == null || order.billPhotoPath!.isEmpty);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isQuotePending
                              ? 'Awaiting Rider Quote'
                              : (order.totalAmount > 0
                                  ? '₹${order.totalAmount.toStringAsFixed(0)}'
                                  : '₹${order.deliveryFee.toInt()} (Delivery Fee)'),
                          style: GoogleFonts.outfit(
                            fontSize: isQuotePending ? 13.5 : 16,
                            fontWeight: FontWeight.w900,
                            color: isQuotePending ? const Color(0xFFD97706) : theme.textPrimary,
                          ),
                        ),
                        if (isQuotePending)
                          Text(
                            'Bill will appear once rider quotes',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (!isMapPin && order.orderType == OrderType.standard)
                      TextButton.icon(
                        onPressed: () {
                          context.read<OrderProvider>().reorder(order.id, cart);
                        },
                        icon: const Icon(Iconsax.repeat_copy, size: 14),
                        label: Text('REORDER', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900)),
                        style: TextButton.styleFrom(
                          foregroundColor: primary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                      )
                    else
                      Text(
                        'VIEW DETAILS ➔',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
