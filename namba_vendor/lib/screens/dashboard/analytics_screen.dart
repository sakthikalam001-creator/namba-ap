import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'Weekly';

  final Map<String, List<FlSpot>> _revenueData = {
    'Weekly': const [
      FlSpot(0, 3.5),
      FlSpot(1, 2.8),
      FlSpot(2, 4.2),
      FlSpot(3, 3.1),
      FlSpot(4, 5.5),
      FlSpot(5, 4.8),
      FlSpot(6, 6.2),
    ],
    'Monthly': const [
      FlSpot(0, 2.1),
      FlSpot(1, 3.5),
      FlSpot(2, 2.8),
      FlSpot(3, 4.9),
      FlSpot(4, 3.2),
      FlSpot(5, 5.1),
      FlSpot(6, 4.3),
      FlSpot(7, 6.0),
      FlSpot(8, 5.2),
      FlSpot(9, 7.1),
      FlSpot(10, 6.5),
      FlSpot(11, 8.2),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.lightSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('analytics'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodToggle(),
            const SizedBox(height: 24),
            _buildRevenueChart(lang),
            const SizedBox(height: 32),
            _buildTopProductsChart(lang),
            const SizedBox(height: 32),
            _buildStatCards(lang),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          _buildToggleItem('Weekly'),
          _buildToggleItem('Monthly'),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label) {
    final isSelected = _selectedPeriod == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = label),
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
              color: isSelected ? Colors.white : AppTheme.mediumText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(LanguageProvider lang) {
    final currentSpots = _revenueData[_selectedPeriod]!;
    final maxY = currentSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
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
                  color: AppTheme.darkText,
                ),
              ),
              Text(
                _selectedPeriod == 'Weekly' ? 'Last 7 Days' : 'Last 12 Months',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.mediumText,
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
                        if (_selectedPeriod == 'Weekly') {
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Text(days[value.toInt()], style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.lightText));
                          }
                        } else {
                          const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                          if (value.toInt() >= 0 && value.toInt() < months.length) {
                            return Text(months[value.toInt()], style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.lightText));
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _selectedPeriod == 'Weekly' ? 6 : 11,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: currentSpots,
                    isCurved: true,
                    color: AppTheme.primaryOrange,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryOrange.withValues(alpha: 0.2),
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

  Widget _buildTopProductsChart(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.translate('top_products'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 24),
          _buildProductBar('Fresh Milk', 0.9, Colors.blue),
          const SizedBox(height: 12),
          _buildProductBar('Brown Bread', 0.7, Colors.orange),
          const SizedBox(height: 12),
          _buildProductBar('Butter', 0.5, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildProductBar(String name, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.darkText)),
            Text('${(percent * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.lightSurface,
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

  Widget _buildStatCards(LanguageProvider lang) {
    return Row(
      children: [
        _buildMiniStat('Orders', '124', Iconsax.bag_2, Colors.green),
        const SizedBox(width: 16),
        _buildMiniStat('Growth', '+12%', Iconsax.trend_up, Colors.purple),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mediumText)),
          ],
        ),
      ),
    );
  }
}

