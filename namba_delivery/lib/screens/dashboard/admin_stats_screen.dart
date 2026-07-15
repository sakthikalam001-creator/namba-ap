import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_theme.dart';

class AdminStatsScreen extends StatelessWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeliveryProvider>(context);
    final acceptedCount = provider.orderHistory.length;
    final declinedCount = provider.declinedOrderIds.length;
    final totalAttempts = acceptedCount + declinedCount;
    final acceptanceRate = totalAttempts > 0 ? (acceptedCount / totalAttempts * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('ADMIN CENTER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── OVERALL PERFORMANCE ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2E2E3E), Color(0xFF1A1A2E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: const Color(0xFF1A1A2E).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ACCEPTANCE RATE', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$acceptanceRate', style: GoogleFonts.outfit(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1)),
                              const SizedBox(width: 4),
                              Text('%', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 24, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Iconsax.status_up_copy, color: AppTheme.accentGreen, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _miniStat('TOTAL ORDERS', '$totalAttempts', Colors.white38),
                      const SizedBox(width: 20),
                      _miniStat('AVG. RATING', '4.9', Colors.white38),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ── HISTORY SECTION ──────────────────────────────────────────────
            Text('ASSIGNMENT HISTORY', style: GoogleFonts.outfit(color: AppTheme.darkText.withValues(alpha: 0.3), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 24),

            // Accepted List
            if (provider.orderHistory.isNotEmpty) ...[
              _buildHeader('ACCEPTED MISSIONS', AppTheme.accentGreen),
              const SizedBox(height: 12),
              ...provider.orderHistory.take(5).map((order) => _historyTile(
                'Order #${order.displayId}',
                order.storeName,
                'Accepted',
                AppTheme.accentGreen,
                Iconsax.tick_circle_copy,
              )),
              const SizedBox(height: 24),
            ],

            // Declined List
            if (provider.declinedOrderIds.isNotEmpty) ...[
              _buildHeader('DECLINED MISSIONS', Colors.red),
              const SizedBox(height: 12),
              ...provider.declinedOrderIds.take(5).map((id) => _historyTile(
                'Order #${id.length > 6 ? id.substring(id.length - 6) : id}',
                'Manually Declined',
                'Declined',
                Colors.red,
                Iconsax.close_circle_copy,
              )),
            ],

            if (provider.orderHistory.isEmpty && provider.declinedOrderIds.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    children: [
                      Icon(Iconsax.archive_1_copy, color: Colors.grey.shade300, size: 60),
                      const SizedBox(height: 16),
                      Text('NO HISTORY YET', style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(title, style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }

  Widget _historyTile(String title, String subtitle, String status, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(subtitle, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(status.toUpperCase(), style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
