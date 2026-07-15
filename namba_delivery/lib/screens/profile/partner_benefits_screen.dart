import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';

class PartnerBenefitsScreen extends StatefulWidget {
  const PartnerBenefitsScreen({super.key});

  @override
  State<PartnerBenefitsScreen> createState() => _PartnerBenefitsScreenState();
}

class _PartnerBenefitsScreenState extends State<PartnerBenefitsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final result = await DeliveryAuthService.getSettings();
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _settings = result['data'];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('PARTNER BENEFITS',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  if (_settings['partnerInsuranceEnabled'] ?? true)
                    _buildBenefitCard(
                      'INSURANCE PROTECTION',
                      'Comprehensive accidental and health coverage for you and your family.',
                      icons.Iconsax.shield_tick_copy,
                      Colors.blue,
                      [
                        '₹5 Lakh Accidental Cover',
                        '₹1 Lakh Medical Expenses',
                        'Life Insurance Support'
                      ],
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                  if (_settings['partnerFlexibilityEnabled'] ?? true)
                    _buildBenefitCard(
                      'OPERATIONAL FLEXIBILITY',
                      'Total freedom to choose when and where you want to work.',
                      icons.Iconsax.timer_1_copy,
                      Colors.orange,
                      [
                        'No Fixed Logins',
                        'Choose Your Own Shifts',
                        'Withdraw Earnings Weekly'
                      ],
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                  if (_settings['partnerIncentivesEnabled'] ?? true)
                    _buildBenefitCard(
                      'GROWTH & INCENTIVES',
                      'Maximize your earnings with tiered bonuses and referral rewards.',
                      icons.Iconsax.ranking_copy,
                      Colors.green,
                      [
                        'Peak Hour Surge Pay',
                        'Weekly Target Bonuses',
                        '₹500 Referral Bonus'
                      ],
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                  if (_settings['partnerWelfareEnabled'] ?? true)
                    _buildBenefitCard(
                      'SOCIAL WELFARE',
                      'We care about your well-being beyond the deliveries.',
                      icons.Iconsax.heart_copy,
                      Colors.pink,
                      [
                        'Period Rest Days for Women',
                        'National Pension (NPS) Help',
                        'Income Tax Filing Assist'
                      ],
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 48),
                  _buildSupportCallout(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NAMBA PRIME BENEFITS',
            style: GoogleFonts.outfit(
                color: AppTheme.primaryOrange,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text('Exclusive Perks for our Elite Fleet',
            style: GoogleFonts.outfit(
                color: AppTheme.darkText,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
      ],
    ).animate().fadeIn();
  }

  Widget _buildBenefitCard(String title, String desc, IconData icon, Color color, List<String> bulletPoints) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.outfit(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                    Text(desc,
                        style: GoogleFonts.outfit(
                            color: AppTheme.darkText.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          ...bulletPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(icons.Iconsax.tick_circle_copy,
                        color: AppTheme.accentGreen, size: 16),
                    const SizedBox(width: 12),
                    Text(point,
                        style: GoogleFonts.outfit(
                            color: AppTheme.darkText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSupportCallout() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.darkText,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: AppTheme.darkText.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Text('NEED CLARIFICATION?',
              style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          const SizedBox(height: 12),
          Text('Our Partner Success team is here to help you 24/7',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('CHAT WITH SUPPORT',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1);
  }
}
