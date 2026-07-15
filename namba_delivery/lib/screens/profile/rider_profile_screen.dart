import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../services/delivery_auth_service.dart';
import '../earnings/rider_earnings_screen.dart';
import '../auth/delivery_login_screen.dart';
import 'refer_earn_screen.dart';
import 'document_status_screen.dart';
import 'rider_tiers_screen.dart';
import '../support/help_center_screen.dart';
import '../support/tactical_support_screen.dart';
import '../support/safety_center_screen.dart';
import '../settings/settings_screen.dart';
import 'partner_benefits_screen.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  String _driverName = 'Partner';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await DeliveryAuthService.getDriverName();
    if (mounted) setState(() => _driverName = name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildPrimeProfileHeader(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
              child: Column(
                children: [
                  _buildPrimeIdentityCard(),
                  const SizedBox(height: 32),
                  _buildPrimeMenuHub(),
                  const SizedBox(height: 48),
                  _buildQuickSupportSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimeProfileHeader() {
    return SliverAppBar(
      expandedHeight: 100,
      backgroundColor: AppTheme.lightBg,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.darkText),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text('PROFILE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: AppTheme.darkText)),
        centerTitle: true,
      ),
    );
  }

  Widget _buildPrimeIdentityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Hero(
                tag: 'profile_pic',
                child: Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.lightBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 4),
                    image: const DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?q=80&w=200&auto=format&fit=crop'), fit: BoxFit.cover),
                    boxShadow: AppTheme.softShadow,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_driverName.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('VERIFIED PARTNER', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 8),
                    Text('ID: #RD-9982-PRIME', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPrimeMetric('1.2K', 'JOBS'),
              Container(width: 1, height: 24, color: AppTheme.lightBg),
              _buildPrimeMetric('4.9★', 'RATING'),
              Container(width: 1, height: 24, color: AppTheme.lightBg),
              _buildPrimeMetric('Gold', 'TIER'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPrimeMetric(String val, String label) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildPrimeMenuHub() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildPrimeMenuItem(icons.Iconsax.wallet_2_copy, 'Earnings & Payments', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen()))),
          _buildPrimeMenuItem(icons.Iconsax.medal_star_copy, 'Partner Tiers', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderTiersScreen()))),
          _buildPrimeMenuItem(icons.Iconsax.ranking_1_copy, 'Partner Perks & Benefits', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PartnerBenefitsScreen()))),
          _buildPrimeMenuItem(icons.Iconsax.document_copy, 'Document Verification', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentStatusScreen()))),
          _buildPrimeMenuItem(icons.Iconsax.gift_copy, 'Refer & Earn', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferEarnScreen()))),
          const Divider(height: 1, color: AppTheme.lightBg),
          _buildPrimeMenuItem(icons.Iconsax.messages_2_copy, 'Support Center', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TacticalSupportScreen()))),
          _buildPrimeMenuItem(icons.Iconsax.setting_2_copy, 'Settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          _buildPrimeMenuItem(
            icons.Iconsax.logout_copy, 
            'Logout Account', 
            () async {
              final driverId = await DeliveryAuthService.getDriverId();
              if (driverId.isNotEmpty) {
                await DeliveryAuthService.setDriverStatus(driverId, false);
              }
              await DeliveryAuthService.logout();
              if (mounted) {
                Provider.of<DeliveryProvider>(context, listen: false).setAuthenticated(false);
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()), (route) => false);
              }
            }, 
            color: AppTheme.signalRed,
            isLast: true,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildPrimeMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color, bool isLast = false}) {
    final activeColor = color ?? AppTheme.primaryOrange;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isLast ? 28 : 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppTheme.lightBg))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: activeColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: activeColor, size: 18),
            ),
            const SizedBox(width: 18),
            Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: color ?? AppTheme.darkText)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.lightText),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSupportSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyCenterScreen())),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.signalRed.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.signalRed.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(icons.Iconsax.shield_tick_copy, color: AppTheme.signalRed, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SAFETY CENTER', style: GoogleFonts.outfit(color: AppTheme.signalRed, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text('Emergency SOS & Help', style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
}
