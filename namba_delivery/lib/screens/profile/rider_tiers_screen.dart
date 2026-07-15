import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RiderTiersScreen extends StatelessWidget {
  const RiderTiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('PARTNER PROGRESS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPrimeRankCard(),
            const SizedBox(height: 32),
            _buildPrimeProgressMetric(),
            const SizedBox(height: 48),
            Text('LEVEL PRIVILEGES', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.darkText, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildPrimeTierList(),
            const SizedBox(height: 48),
            _buildPrimeBadgeGallery(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimeRankCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.accentGreen.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(icons.Iconsax.medal_star_copy, color: AppTheme.accentGreen, size: 36),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2.seconds, begin: const Offset(1,1), end: const Offset(1.1, 1.1)),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT STATUS', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('GOLD PARTNER', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(icons.Iconsax.ranking_copy, color: AppTheme.accentGreen, size: 12),
                    const SizedBox(width: 6),
                    Text('Global Rank: #424', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPrimeProgressMetric() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NEXT LEVEL PROGRESS', style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              Text('85%', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(10)),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.85,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accentGreen, Color(0xFF6EE7B7)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.2), blurRadius: 10)],
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(delay: 3.seconds, duration: 2.seconds),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Complete 15 more jobs to reach Diamond status', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildPrimeTierList() {
    return Column(
      children: [
        _buildTierItem('BRONZE', 'Basic Access • 1.0x Multiplier', Colors.brown, false, false),
        _buildTierItem('SILVER', 'Extended Buffer • 1.1x Multiplier', Colors.blueGrey, false, false),
        _buildTierItem('GOLD', 'Priority Support • 1.3x Multiplier', Colors.amber.shade700, true, true),
        _buildTierItem('DIAMOND', 'Max Priority • 1.5x Multiplier • Insurance', AppTheme.accentGreen, false, false),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildTierItem(String title, String desc, Color accent, bool isCurrent, bool isUnlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent ? accent.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isCurrent ? accent.withValues(alpha: 0.2) : Colors.transparent),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icons.Iconsax.award_copy, color: accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text(desc, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (isUnlocked)
            const Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 20)
          else
            const Icon(icons.Iconsax.lock_copy, color: AppTheme.lightBg, size: 18),
        ],
      ),
    );
  }

  Widget _buildPrimeBadgeGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ACHIEVEMENT BADGES', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.darkText, letterSpacing: 1)),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
          children: [
            _buildBadgeItem(icons.Iconsax.moon_copy, 'Night Owl', true, Colors.indigo),
            _buildBadgeItem(icons.Iconsax.flash_1_copy, 'Speedster', true, Colors.amber),
            _buildBadgeItem(icons.Iconsax.shield_tick_copy, 'Guardian', false, Colors.teal),
            _buildBadgeItem(icons.Iconsax.status_up_copy, 'Top Partner', true, AppTheme.accentGreen),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildBadgeItem(IconData icon, String label, bool isUnlocked, Color color) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isUnlocked ? color.withValues(alpha: 0.05) : AppTheme.lightBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isUnlocked ? color.withValues(alpha: 0.1) : Colors.transparent),
            ),
            child: Icon(icon, color: isUnlocked ? color : AppTheme.lightText.withValues(alpha: 0.5), size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.outfit(color: isUnlocked ? AppTheme.darkText : AppTheme.lightText, fontSize: 9, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      ],
    );
  }
}
