import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';
import '../../services/delivery_language_provider.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  String _selectedTab = 'ALL'; // 'ALL', 'PENDING', 'SETTLED'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          context.tr('earnings_payouts'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.2,
            color: const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Refresh',
            onPressed: () => context.read<DeliveryProvider>().fetchHistory(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final allDelivered = provider.deliveredOrders;
          final pendingOrders = provider.pendingSettlementOrders;
          final settledOrders = provider.settledOrders;

          final pendingPayout = provider.pendingPayoutEarnings;
          final settledPayout = provider.settledPayoutEarnings;
          final totalLifetime = provider.totalDeliveredEarnings;

          List<DeliveryOrder> displayedOrders;
          if (_selectedTab == 'PENDING') {
            displayedOrders = pendingOrders;
          } else if (_selectedTab == 'SETTLED') {
            displayedOrders = settledOrders;
          } else {
            displayedOrders = allDelivered;
          }

          return RefreshIndicator(
            color: AppTheme.primaryOrange,
            backgroundColor: Colors.white,
            onRefresh: () => provider.fetchHistory(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dual KPI Hero Cards (Pending vs Settled)
                  _buildDualKpiCards(
                    pendingPayout: pendingPayout,
                    pendingCount: pendingOrders.length,
                    settledPayout: settledPayout,
                    settledCount: settledOrders.length,
                  ),

                  const SizedBox(height: 14),

                  // 2. Cumulative Lifetime Stats Strip
                  _buildLifetimeSummaryStrip(
                    totalEarnings: totalLifetime,
                    totalCount: allDelivered.length,
                  ),

                  const SizedBox(height: 18),

                  // 3. Direct Admin Settlement Policy Banner
                  _buildAdminSettlementNotice(),

                  const SizedBox(height: 22),

                  // 4. Filter Tabs Header (ALL, PENDING, SETTLED)
                  _buildFilterTabs(
                    allCount: allDelivered.length,
                    pendingCount: pendingOrders.length,
                    settledCount: settledOrders.length,
                  ),

                  const SizedBox(height: 14),

                  // 5. Itemized Order Settlement Transactions
                  if (displayedOrders.isEmpty)
                    _buildEmptyStateForTab(_selectedTab)
                  else
                    Column(
                      children: displayedOrders.map((order) {
                        return _buildSettlementOrderCard(order);
                      }).toList(),
                    ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. DUAL KPI HERO CARDS
  // ---------------------------------------------------------------------------
  Widget _buildDualKpiCards({
    required double pendingPayout,
    required int pendingCount,
    required double settledPayout,
    required int settledCount,
  }) {
    final hasPending = pendingPayout > 0;

    return Column(
      children: [
        // Top Card: PENDING PAYOUT (Primary Attention)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasPending
                  ? [const Color(0xFF1E1B18), const Color(0xFF2C1C0D)]
                  : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasPending
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (hasPending ? const Color(0xFFD97706) : const Color(0xFF0F172A))
                    .withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasPending
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasPending
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                            : const Color(0xFF10B981).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPending ? icons.Iconsax.clock_copy : icons.Iconsax.tick_circle_copy,
                          color: hasPending ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('pending_payout'),
                          style: GoogleFonts.outfit(
                            color: hasPending ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPending
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                          : const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasPending
                          ? '⏳ $pendingCount ${context.tr('pending_tab')}'
                          : '✓ ${context.tr('all_settled')}',
                      style: GoogleFonts.outfit(
                        color: hasPending ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹',
                    style: GoogleFonts.outfit(
                      color: hasPending ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    pendingPayout.toStringAsFixed(2).split('.')[0],
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '.${pendingPayout.toStringAsFixed(2).split('.')[1]}',
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                hasPending
                    ? context.tr('awaiting_admin')
                    : '🎉 All delivered trips are settled by Super Admin!',
                style: GoogleFonts.outfit(
                  color: hasPending ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Bottom Card: SETTLED PAYOUT (Direct Bank/UPI Transferred)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(icons.Iconsax.bank_copy, color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.tr('settled_payout'),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF065F46),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$settledCount PAID',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF047857),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${settledPayout.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF047857),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('transferred_upi'),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF059669),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(icons.Iconsax.verify_copy, color: Color(0xFF10B981), size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. CUMULATIVE LIFETIME STATS STRIP
  // ---------------------------------------------------------------------------
  Widget _buildLifetimeSummaryStrip({
    required double totalEarnings,
    required int totalCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(icons.Iconsax.box_tick_copy, color: Color(0xFF4F46E5), size: 14),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('lifetime_delivered'),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '$totalCount Orders Delivered',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'LIFETIME REVENUE',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '₹ ${totalEarnings.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ADMIN SETTLEMENT POLICY NOTICE
  // ---------------------------------------------------------------------------
  Widget _buildAdminSettlementNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(icons.Iconsax.shield_tick_copy, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('direct_admin_settlement'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('settlement_desc'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. FILTER TABS (ALL, PENDING, SETTLED)
  // ---------------------------------------------------------------------------
  Widget _buildFilterTabs({
    required int allCount,
    required int pendingCount,
    required int settledCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              keyName: 'ALL',
              label: '${context.tr('all_orders_tab')} ($allCount)',
              isActive: _selectedTab == 'ALL',
            ),
          ),
          Expanded(
            child: _tabButton(
              keyName: 'PENDING',
              label: '${context.tr('pending_tab')} ($pendingCount)',
              isActive: _selectedTab == 'PENDING',
              highlightAmber: pendingCount > 0,
            ),
          ),
          Expanded(
            child: _tabButton(
              keyName: 'SETTLED',
              label: '${context.tr('settled_tab')} ($settledCount)',
              isActive: _selectedTab == 'SETTLED',
              highlightGreen: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String keyName,
    required String label,
    required bool isActive,
    bool highlightAmber = false,
    bool highlightGreen = false,
  }) {
    Color activeColor = const Color(0xFF0F172A);
    if (isActive && highlightAmber) activeColor = const Color(0xFFD97706);
    if (isActive && highlightGreen && keyName == 'SETTLED') activeColor = const Color(0xFF059669);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = keyName;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isActive ? activeColor : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. ITEMIZED SETTLEMENT ORDER CARD
  // ---------------------------------------------------------------------------
  Widget _buildSettlementOrderCard(DeliveryOrder order) {
    final isSettled = order.isDriverSettled;
    final earn = order.computedDriverEarnings > 0
        ? order.computedDriverEarnings
        : (order.driverEarningsBackend ?? 10.0);
    final earnStr = '₹ ${earn.toStringAsFixed(2)}';

    final displayId = order.displayId.isNotEmpty
        ? order.displayId
        : order.id.substring(order.id.length > 5 ? order.id.length - 5 : 0);

    final deliveryTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(order.timestamp);

    // Settlement metadata
    final paymentMethod = order.driverPaymentMethod?.trim().isNotEmpty == true
        ? order.driverPaymentMethod!
        : 'UPI / Bank Transfer';

    final paidAtStr = order.driverPaidAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(order.driverPaidAt!)
        : 'Direct Payout';

    final paymentRef = order.driverPaymentRef?.trim().isNotEmpty == true
        ? order.driverPaymentRef!
        : 'ADMIN-DIRECT-PAYOUT';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSettled ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Circle Icon
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isSettled ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSettled ? icons.Iconsax.tick_circle_copy : icons.Iconsax.clock_copy,
                    color: isSettled ? const Color(0xFF10B981) : const Color(0xFFD97706),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // Store and Order ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.storeName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0F172A),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#$displayId • $deliveryTimeStr',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      earnStr,
                      style: GoogleFonts.outfit(
                        color: isSettled ? const Color(0xFF059669) : const Color(0xFFD97706),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      isSettled ? 'Credited' : 'Pending',
                      style: GoogleFonts.outfit(
                        color: isSettled ? const Color(0xFF059669) : const Color(0xFFD97706),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Settlement Details Drawer / Status Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSettled ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(19),
                bottomRight: Radius.circular(19),
              ),
              border: Border(
                top: BorderSide(
                  color: isSettled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                ),
              ),
            ),
            child: isSettled
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(icons.Iconsax.verify_copy, color: Color(0xFF059669), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('settled').toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF065F46),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            paidAtStr,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF047857),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${context.tr('payout_method')}: $paymentMethod',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF065F46),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ref: $paymentRef',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF059669),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(icons.Iconsax.info_circle_copy, color: Color(0xFFD97706), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('awaiting_payout_notice'),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF92400E),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. EMPTY STATES
  // ---------------------------------------------------------------------------
  Widget _buildEmptyStateForTab(String tab) {
    IconData iconData = icons.Iconsax.receipt_item_copy;
    Color iconColor = const Color(0xFF94A3B8);
    Color bgColor = const Color(0xFFF1F5F9);
    String title = context.tr('no_earnings_yet');
    String desc = context.tr('no_earnings_sub');

    if (tab == 'PENDING') {
      iconData = icons.Iconsax.tick_circle_copy;
      iconColor = const Color(0xFF10B981);
      bgColor = const Color(0xFFECFDF5);
      title = context.tr('no_pending_payouts');
      desc = context.tr('no_pending_payouts_sub');
    } else if (tab == 'SETTLED') {
      iconData = icons.Iconsax.bank_copy;
      iconColor = const Color(0xFF64748B);
      bgColor = const Color(0xFFF1F5F9);
      title = context.tr('no_settled_payouts');
      desc = context.tr('no_settled_payouts_sub');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
