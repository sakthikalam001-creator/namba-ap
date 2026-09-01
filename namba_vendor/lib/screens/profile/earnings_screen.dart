import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../models/vendor_order_model.dart';
import '../../services/vendor_order_provider.dart';
import '../../services/language_provider.dart';
import '../../services/api_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingPayouts = false;
  Map<String, dynamic>? _payoutData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPayoutData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayoutData() async {
    final provider = context.read<VendorOrderProvider>();
    final vendorId = provider.vendorId;
    if (vendorId.isEmpty) return;

    setState(() => _isLoadingPayouts = true);
    try {
      final data = await VendorApiService().fetchVendorPayouts(vendorId);
      if (mounted) {
        setState(() {
          _payoutData = data;
          _isLoadingPayouts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPayouts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final orderProvider = Provider.of<VendorOrderProvider>(context);

    // Prefer backend calculated payout data if available, else fall back to local provider calculations
    final double pendingPayout = _payoutData != null
        ? (_payoutData!['availableForPayout'] as num?)?.toDouble() ?? (orderProvider.totalEarnings * 0.95)
        : (orderProvider.totalEarnings * 0.95);
    final double totalSettled = _payoutData != null
        ? (_payoutData!['totalSettled'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final double totalEarnings = _payoutData != null
        ? (_payoutData!['totalEarnings'] as num?)?.toDouble() ?? orderProvider.totalEarnings
        : orderProvider.totalEarnings;
    final double commission = _payoutData != null
        ? (_payoutData!['totalCommissionDeducted'] as num?)?.toDouble() ?? (totalEarnings * 0.05)
        : (totalEarnings * 0.05);

    final List settlements = _payoutData?['settlements'] ?? [];
    final pastOrders = orderProvider.pastOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('earnings'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.darkText,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Iconsax.refresh, size: 20, color: _isLoadingPayouts ? Colors.grey : AppTheme.primaryOrange),
            onPressed: _isLoadingPayouts ? null : () => _loadPayoutData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadPayoutData();
          await orderProvider.refreshOrders();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Clean Direct Admin Payout Summary Card
              _buildAdminPayoutSummaryCard(
                pendingPayout: pendingPayout,
                totalSettled: totalSettled,
                totalGross: totalEarnings,
                commission: commission,
              ),
              const SizedBox(height: 20),

              // 2. 7-Day Revenue Trend Chart
              _buildWeeklyChart(orderProvider),
              const SizedBox(height: 24),

              // 3. Tab Bar (Direct Admin Payouts vs Order Revenue)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryOrange,
                  indicatorWeight: 3,
                  labelColor: AppTheme.primaryOrange,
                  unselectedLabelColor: Colors.grey.shade500,
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text('Direct Admin Transfers (${settlements.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.receipt_2, size: 16),
                          const SizedBox(width: 6),
                          Text('Order Revenue (${pastOrders.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Tab Views
              SizedBox(
                height: 480,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Real Admin Direct Settlements
                    _buildSettlementList(settlements),
                    // Tab 2: Order-by-order Revenue Breakdown
                    _buildOrderRevenueList(pastOrders),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPayoutSummaryCard({
    required double pendingPayout,
    required double totalSettled,
    required double totalGross,
    required double commission,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending Admin Settlement',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Direct Bank / UPI Pay', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${pendingPayout.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Directly transferred by Admin to your registered Bank / UPI account',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Paid by Admin', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('₹${totalSettled.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: const Color(0xFF86EFAC), fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Fee (5%)', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('-₹${commission.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gross Sales', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('₹${totalGross.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(VendorOrderProvider orderProvider) {
    final weekly = orderProvider.weeklyRevenue;
    final maxVal = weekly.reduce((a, b) => a > b ? a : b);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('7-Day Revenue Trend', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.darkText)),
              Text('Past 7 Days', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: maxVal > 0 ? maxVal * 1.25 : 500,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.darkText,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '₹${rod.toY.toStringAsFixed(0)}',
                        GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(days[idx], style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w700)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final amount = (i < weekly.length) ? weekly[i] : 0.0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: amount,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementList(List settlements) {
    if (settlements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No Direct Admin Settlements yet.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text('When Super Admin transfers payouts to your Bank / UPI, transaction entries appear here automatically.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: settlements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final s = settlements[i];
        final displayId = s['displayId'] ?? 'SETTLE';
        final amount = (s['amount'] as num?)?.toDouble() ?? 0.0;
        final mode = s['paymentMethod'] ?? 'Bank Transfer';
        final refId = s['refId'] ?? 'PAY-REF';
        final settledAt = s['settledAt'] != null ? DateTime.tryParse(s['settledAt'].toString())?.toLocal() : null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Order #$displayId', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.darkText)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('PAID BY ADMIN', style: TextStyle(color: Colors.green.shade800, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Ref: $refId  •  $mode', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w500)),
                    if (settledAt != null)
                      Text(DateFormat('dd MMM yyyy, hh:mm a').format(settledAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                  ],
                ),
              ),
              Text(
                '+ ₹${amount.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF16A34A)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderRevenueList(List<VendorOrderModel> orders) {
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.receipt_2, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No completed order revenue yet.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    final sorted = List<VendorOrderModel>.from(orders)..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final order = sorted[i];
        final timeStr = DateFormat('dd-MM-yyyy • hh:mm a').format(order.timestamp);
        final netAmount = order.totalAmount * 0.95;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Iconsax.wallet_3, color: AppTheme.primaryOrange, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order: ${order.displayId}',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 2),
                    Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    Text('Gross: ₹${order.totalAmount.toStringAsFixed(0)} (5% Fee Applied)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+ ₹${netAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                  ),
                  Text(order.paymentMethod, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
