import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';

class RiderTiersScreen extends StatelessWidget {
  const RiderTiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('PARTNER TIERS & PROGRESS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final int completedJobs = provider.orderHistory
              .where((o) => o.status == DeliveryStatus.delivered)
              .length;

          String currentTier = 'SILVER';
          Color tierColor = const Color(0xFF64748B);
          int nextTierTarget = 10;
          double progressRatio = 0.0;
          int remainingToNext = 10;

          if (completedJobs >= 30) {
            currentTier = 'PLATINUM';
            tierColor = const Color(0xFF10B981);
            nextTierTarget = 30;
            progressRatio = 1.0;
            remainingToNext = 0;
          } else if (completedJobs >= 10) {
            currentTier = 'GOLD';
            tierColor = const Color(0xFFF59E0B);
            nextTierTarget = 30;
            progressRatio = ((completedJobs - 10) / 20).clamp(0.0, 1.0);
            remainingToNext = 30 - completedJobs;
          } else {
            currentTier = 'SILVER';
            tierColor = const Color(0xFF64748B);
            nextTierTarget = 10;
            progressRatio = (completedJobs / 10).clamp(0.0, 1.0);
            remainingToNext = 10 - completedJobs;
          }

          final int progressPercent = (progressRatio * 100).toInt();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPrimeRankCard(currentTier, tierColor, completedJobs),
                const SizedBox(height: 24),
                _buildPrimeProgressMetric(progressPercent, progressRatio, remainingToNext, currentTier),
                const SizedBox(height: 36),
                Text('TIER PRIVILEGES', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.darkText.withValues(alpha: 0.4), letterSpacing: 1)),
                const SizedBox(height: 14),
                _buildPrimeTierList(completedJobs),
                const SizedBox(height: 36),
                _buildPrimeBadgeGallery(completedJobs),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrimeRankCard(String tierName, Color color, int jobs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icons.Iconsax.medal_star_copy, color: color, size: 34),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: const Offset(1,1), end: const Offset(1.08, 1.08)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT PARTNER LEVEL', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('$tierName PARTNER', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icons.Iconsax.tick_circle_copy, color: color, size: 13),
                    const SizedBox(width: 5),
                    Text('$jobs Completed Deliveries', style: GoogleFonts.outfit(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildPrimeProgressMetric(int percent, double ratio, int remaining, String currentTier) {
    final nextTargetName = currentTier == 'SILVER' ? 'GOLD' : (currentTier == 'GOLD' ? 'PLATINUM' : 'MAX LEVEL');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PROGRESS TO $nextTargetName', style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              Text('$percent%', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.25), blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            remaining > 0
                ? 'Complete $remaining more deliveries to unlock $nextTargetName status'
                : 'Maximum Tier Unlocked • Top Partner Priority',
            style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildPrimeTierList(int jobs) {
    return Column(
      children: [
        _buildTierItem('SILVER', 'Base Rate • Fast UPI Settlement', const Color(0xFF64748B), jobs < 10, true),
        _buildTierItem('GOLD', '10+ Deliveries • High Order Priority', const Color(0xFFF59E0B), jobs >= 10 && jobs < 30, jobs >= 10),
        _buildTierItem('PLATINUM', '30+ Deliveries • Maximum Mission Priority & Rewards', const Color(0xFF10B981), jobs >= 30, jobs >= 30),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildTierItem(String title, String desc, Color accent, bool isCurrent, bool isUnlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCurrent ? accent.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isCurrent ? accent.withValues(alpha: 0.3) : AppTheme.borderLight, width: isCurrent ? 1.8 : 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icons.Iconsax.award_copy, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                        child: Text('ACTIVE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUnlocked)
            const Icon(icons.Iconsax.tick_circle_copy, color: Color(0xFF10B981), size: 20)
          else
            const Icon(icons.Iconsax.lock_copy, color: Color(0xFFCBD5E1), size: 18),
        ],
      ),
    );
  }

  Widget _buildPrimeBadgeGallery(int jobs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACHIEVEMENT BADGES', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.darkText.withValues(alpha: 0.4), letterSpacing: 1)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
          children: [
            _buildBadgeItem(icons.Iconsax.flash_1_copy, '1st Order', jobs >= 1, const Color(0xFF10B981)),
            _buildBadgeItem(icons.Iconsax.box_copy, '10 Orders', jobs >= 10, const Color(0xFFF59E0B)),
            _buildBadgeItem(icons.Iconsax.star_copy, 'Pro Rider', jobs >= 25, const Color(0xFF6366F1)),
            _buildBadgeItem(icons.Iconsax.shield_tick_copy, 'Verified KYC', true, const Color(0xFF06B6D4)),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildBadgeItem(IconData icon, String label, bool isUnlocked, Color color) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isUnlocked ? color.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isUnlocked ? color.withValues(alpha: 0.25) : const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, color: isUnlocked ? color : const Color(0xFF94A3B8), size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: isUnlocked ? AppTheme.darkText : const Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

