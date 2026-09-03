import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/vendor_order_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'Weekly';
  bool _isLoading = true;

  Map<String, dynamic> _summary = {};
  List<dynamic> _dailyRevenue = [];
  List<dynamic> _fastMoving = [];
  List<dynamic> _slowMoving = [];
  List<dynamic> _peakHours = [];

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadVendorAnalytics();
  }

  Future<void> _loadVendorAnalytics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
      String vendorId = orderProvider.vendorId;

      if (vendorId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        vendorId = prefs.getString('bg_vendor_id') ?? prefs.getString('vendor_id') ?? '';
      }

      if (vendorId.isNotEmpty) {
        final analyticsData = await _apiService.getVendorAnalytics(vendorId, period: _selectedPeriod);
        if (analyticsData != null && mounted) {
          setState(() {
            _summary = analyticsData['summary'] ?? {};
            _dailyRevenue = analyticsData['dailyRevenue'] ?? [];
            _fastMoving = analyticsData['fastMoving'] ?? [];
            _slowMoving = analyticsData['slowMoving'] ?? [];
            _peakHours = analyticsData['peakHours'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: isDark ? Colors.white : AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('analytics'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.darkText,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryOrange),
            onPressed: _loadVendorAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodToggle(isDark),
                  const SizedBox(height: 24),
                  _buildRevenueChart(lang, isDark),
                  const SizedBox(height: 24),
                  _buildStatCards(lang, isDark),
                  const SizedBox(height: 32),
                  _buildFastMovingProductsCard(lang, isDark),
                  if (_slowMoving.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSlowMovingProductsCard(lang, isDark),
                  ],
                  if (_peakHours.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildPeakHoursCard(lang, isDark),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodToggle(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          _buildToggleItem('Weekly', isDark),
          _buildToggleItem('Monthly', isDark),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isDark) {
    final isSelected = _selectedPeriod == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedPeriod != label) {
            setState(() => _selectedPeriod = label);
            _loadVendorAnalytics();
          }
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(LanguageProvider lang, bool isDark) {
    List<FlSpot> spots = [];
    if (_dailyRevenue.isEmpty) {
      spots = const [FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0)];
    } else {
      for (int i = 0; i < _dailyRevenue.length; i++) {
        final rev = (_dailyRevenue[i]['revenue'] as num?)?.toDouble() ?? 0.0;
        spots.add(FlSpot(i.toDouble(), rev));
      }
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxY > 0 ? maxY * 1.2 : 100.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.translate('revenue'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.darkText,
                ),
              ),
              Text(
                _selectedPeriod == 'Weekly' ? 'Last 7 Days' : 'Last 30 Days',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _dailyRevenue.length) {
                          final dateStr = _dailyRevenue[idx]['_id']?.toString() ?? '';
                          if (dateStr.length >= 5) {
                            return Text(dateStr.substring(dateStr.length - 5), style: GoogleFonts.outfit(fontSize: 10, color: isDark ? const Color(0xFF64748B) : AppTheme.lightText));
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble() > 0 ? (spots.length - 1).toDouble() : 1.0,
                minY: 0,
                maxY: chartMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primaryOrange,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange.withValues(alpha: 0.25),
                          AppTheme.primaryOrange.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastMovingProductsCard(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.flash_1, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                lang.translate('fast_moving'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_fastMoving.isEmpty)
            Text('No product sales data yet', style: GoogleFonts.outfit(color: isDark ? const Color(0xFF64748B) : AppTheme.lightText, fontSize: 13))
          else
            ..._fastMoving.map((item) {
              final name = item['name']?.toString() ?? 'Item';
              final qty = item['qty'] ?? 0;
              final sales = item['sales'] ?? 0;
              final pct = ((item['percentage'] as num?)?.toDouble() ?? 0.0) / 100.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildProductBar(name, '$qty sold • ₹$sales', pct > 1.0 ? 1.0 : (pct < 0.1 ? 0.1 : pct), Colors.green, isDark),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSlowMovingProductsCard(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.trend_down, color: Colors.redAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                lang.translate('slow_moving'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._slowMoving.map((item) {
            final name = item['name']?.toString() ?? 'Item';
            final qty = item['qty'] ?? 0;
            final sales = item['sales'] ?? 0;
            final pct = ((item['percentage'] as num?)?.toDouble() ?? 0.0) / 100.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildProductBar(name, '$qty sold • ₹$sales', pct > 1.0 ? 1.0 : (pct < 0.05 ? 0.05 : pct), Colors.orangeAccent, isDark),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPeakHoursCard(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.clock, color: Colors.purple, size: 22),
              const SizedBox(width: 8),
              Text(
                lang.translate('peak_hours'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._peakHours.map((h) {
            final slot = h['timeSlot']?.toString() ?? '';
            final count = h['orderCount'] ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.timer_start, color: Colors.purple, size: 18),
                  const SizedBox(width: 12),
                  Text(slot, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : AppTheme.darkText)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(20)),
                    child: Text('$count orders', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductBar(String name, String subLabel, double percent, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : AppTheme.darkText), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(subLabel, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(LanguageProvider lang, bool isDark) {
    final totalRevenue = _summary['totalRevenue'] ?? 0;
    final totalOrders = _summary['orderCount'] ?? 0;
    final avgOrderValue = _summary['avgOrderValue'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            _buildMiniStat('Total Revenue', '₹$totalRevenue', Iconsax.wallet_2, Colors.green, isDark),
            const SizedBox(width: 16),
            _buildMiniStat('Orders', '$totalOrders', Iconsax.bag_2, Colors.blue, isDark),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildMiniStat(lang.translate('avg_order_value'), '₹$avgOrderValue', Iconsax.chart_21, Colors.orange, isDark),
            const SizedBox(width: 16),
            _buildMiniStat('Growth', '+15.4%', Iconsax.trend_up, Colors.purple, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
          boxShadow: isDark ? null : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.darkText)),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText)),
          ],
        ),
      ),
    );
  }
}

