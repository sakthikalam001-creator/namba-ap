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
  List<dynamic> _benefits = [];

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
          final settings = result['data'] ?? {};
          final rawList = settings['partnerBenefitsList'];
          if (rawList is List && rawList.isNotEmpty) {
            _benefits = rawList.where((item) => item is Map && item['enabled'] == true).toList();
          } else {
            // Fallback to legacy toggle flags if list is not configured yet
            _benefits = [];
            if (settings['partnerInsuranceEnabled'] ?? true) {
              _benefits.add({
                'title': 'INSURANCE PROTECTION',
                'description': 'Comprehensive accidental and health coverage for you and your family.',
                'icon': 'shield_tick',
                'color': 'blue',
                'points': [
                  '₹5 Lakh Accidental Cover',
                  '₹1 Lakh Medical Expenses',
                  'Life Insurance Support'
                ]
              });
            }
            if (settings['partnerFlexibilityEnabled'] ?? true) {
              _benefits.add({
                'title': 'OPERATIONAL FLEXIBILITY',
                'description': 'Total freedom to choose when and where you want to work.',
                'icon': 'timer_1',
                'color': 'orange',
                'points': [
                  'No Fixed Logins',
                  'Choose Your Own Shifts',
                  'Weekly Direct Settlements'
                ]
              });
            }
            if (settings['partnerIncentivesEnabled'] ?? true) {
              _benefits.add({
                'title': 'GROWTH & INCENTIVES',
                'description': 'Maximize your earnings with tiered bonuses and referral rewards.',
                'icon': 'ranking',
                'color': 'green',
                'points': [
                  'Peak Hour Surge Pay',
                  'Weekly Target Bonuses',
                  '₹500 Referral Bonus'
                ]
              });
            }
            if (settings['partnerWelfareEnabled'] ?? true) {
              _benefits.add({
                'title': 'SOCIAL WELFARE',
                'description': 'We care about your well-being beyond the deliveries.',
                'icon': 'heart',
                'color': 'pink',
                'points': [
                  'Period Rest Days for Women',
                  'National Pension (NPS) Help',
                  'Income Tax Filing Assist'
                ]
              });
            }
          }
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
        title: Text(
          'PARTNER BENEFITS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : RefreshIndicator(
              color: AppTheme.primaryOrange,
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    if (_benefits.isEmpty)
                      _buildEmptyState()
                    else
                      ..._benefits.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value as Map<String, dynamic>;
                        final title = (item['title'] ?? 'BENEFIT').toString().toUpperCase();
                        final desc = (item['description'] ?? '').toString();
                        final rawPoints = item['points'];
                        final List<String> points = (rawPoints is List)
                            ? rawPoints.map((p) => p.toString()).toList()
                            : [];
                        final icon = _resolveIcon(item['icon']?.toString() ?? '');
                        final color = _resolveColor(item['color']?.toString() ?? '');

                        return _buildBenefitCard(
                          title: title,
                          desc: desc,
                          icon: icon,
                          color: color,
                          bulletPoints: points,
                          delayMs: 100 * (idx + 1),
                        );
                      }),
                    const SizedBox(height: 24),
                    _buildSupportCallout(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NAMBA DELIVERY BENEFITS',
          style: GoogleFonts.outfit(
            color: AppTheme.primaryOrange,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Exclusive Perks for our Elite Fleet',
          style: GoogleFonts.outfit(
            color: AppTheme.darkText,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          const Icon(icons.Iconsax.award_copy, color: Color(0xFF94A3B8), size: 40),
          const SizedBox(height: 16),
          Text(
            'NO ACTIVE BENEFITS',
            style: GoogleFonts.outfit(
              color: AppTheme.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Partner perks and benefits are currently being updated. Pull down to refresh.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.lightText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required List<String> bulletPoints,
    required int delayMs,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.outfit(
                          color: AppTheme.darkText.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 18),
            ...bulletPoints.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: const Icon(
                          icons.Iconsax.tick_circle_copy,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          point,
                          style: GoogleFonts.outfit(
                            color: AppTheme.darkText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    ).animate().fadeIn(delay: delayMs.ms).slideY(begin: 0.08);
  }

  Widget _buildSupportCallout() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            'NEED CLARIFICATION?',
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Our Partner Success team is here to help you 24/7',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'BACK TO PROFILE',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1);
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'shield':
      case 'shield_tick':
        return icons.Iconsax.shield_tick_copy;
      case 'timer':
      case 'timer_1':
      case 'clock':
        return icons.Iconsax.timer_1_copy;
      case 'ranking':
      case 'trending':
      case 'chart':
        return icons.Iconsax.ranking_copy;
      case 'heart':
      case 'health':
        return icons.Iconsax.heart_copy;
      case 'wallet':
      case 'money':
      case 'bank':
        return icons.Iconsax.wallet_3_copy;
      case 'gift':
        return icons.Iconsax.gift_copy;
      case 'medal':
      case 'award':
        return icons.Iconsax.medal_star_copy;
      default:
        return icons.Iconsax.star_copy;
    }
  }

  Color _resolveColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'orange':
        return const Color(0xFFF97316);
      case 'green':
        return const Color(0xFF10B981);
      case 'pink':
      case 'red':
        return const Color(0xFFEC4899);
      case 'purple':
      case 'indigo':
        return const Color(0xFF8B5CF6);
      case 'teal':
      case 'cyan':
        return const Color(0xFF14B8A6);
      case 'amber':
      case 'yellow':
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.primaryOrange;
    }
  }
}

