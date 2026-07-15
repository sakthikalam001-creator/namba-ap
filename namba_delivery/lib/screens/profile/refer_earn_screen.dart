import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReferEarnScreen extends StatelessWidget {
  const ReferEarnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('INVITE PARTNERS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeroSection(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REFERRAL PROGRAM', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.lightText, letterSpacing: 1.5)),
                  const SizedBox(height: 24),
                  _buildReferralSteps(),
                  const SizedBox(height: 48),
                  _buildReferralCard(context),
                  const SizedBox(height: 40),
                  _buildShareButton(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 40, offset: Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(icons.Iconsax.gift_copy, color: AppTheme.primaryOrange, size: 56),
          ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          Text(
            'EARN ₹500 CREDITS',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.darkText, letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          Text(
            'Bring your friends to the Namba fleet. Get rewarded for every successful partner onboarding.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.lightText, fontWeight: FontWeight.w600, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralSteps() {
    return Column(
      children: [
        _stepItem('01', 'Share your Code', 'Send your unique referral ID to prospective partners.'),
        _stepItem('02', 'Profile Setup', 'Your friend completes registration and document verification.'),
        _stepItem('03', 'Complete Orders', 'The new partner completes 10 successful deliveries.'),
        _stepItem('04', 'Dual Rewards', 'Credits are credited to both your wallets instantly.'),
      ],
    );
  }

  Widget _stepItem(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(num, style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _buildReferralCard(BuildContext context) {
    String code = 'PRIME-NAMBA-B24';
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Text('YOUR REFERRAL CODE', style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.lightText, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.lightBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  code,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryOrange, letterSpacing: 1),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('CODE COPIED TO CLIPBOARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                        backgroundColor: AppTheme.accentGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: const Icon(icons.Iconsax.copy_copy, color: AppTheme.primaryOrange, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).scale();
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 60, width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(icons.Iconsax.share_copy, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('SHARE WITH FRIENDS', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }
}
