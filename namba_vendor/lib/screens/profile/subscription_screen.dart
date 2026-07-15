import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/vendor_order_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<dynamic> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    final api = VendorApiService();
    final plans = await api.getSubscriptions();
    if (mounted) {
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'flash_circle':
        return Iconsax.flash_circle;
      case 'crown':
        return Iconsax.crown;
      case 'award':
        return Iconsax.award;
      case 'star':
        return Icons.star_rounded;
      default:
        return Iconsax.flash_circle;
    }
  }

  Color _getColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppTheme.primaryOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription Plans',
          style: GoogleFonts.outfit(
            color: AppTheme.darkText,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<VendorOrderProvider>(
        builder: (context, provider, child) {
          final profile = provider.profile;
          final bool hasActiveTrial = profile?.trialExpiry != null && profile!.trialExpiry!.isAfter(DateTime.now());
          
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_plans.isEmpty) {
            return Center(
              child: Text(
                'No plans available at the moment.',
                style: GoogleFonts.outfit(color: AppTheme.mediumText),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasActiveTrial)
                  _buildTrialCard(profile!.trialExpiry!),
                const SizedBox(height: 24),
                Text(
                  'Choose your grow plan',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkText,
                  ),
                ),
                Text(
                  'Scale your business with simplified pricing',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppTheme.mediumText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                ..._plans.map((plan) {
                  final String name = plan['name'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildPlanCard(
                      context,
                      title: name,
                      price: '₹${plan['price']}',
                      period: '/${plan['period'] ?? 'month'}',
                      icon: _getIconData(plan['icon'] ?? 'flash_circle'),
                      color: _getColor(plan['color'] ?? '#00BFA5'),
                      features: List<String>.from(plan['features'] ?? []),
                      isPopular: plan['isPopular'] ?? false,
                      currentPlan: profile?.subscriptionPlan == name,
                    ),
                  );
                }),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrialCard(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentGreen, AppTheme.accentGreen.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.timer_1, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free Trial Active',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'You have $daysLeft days left of full access.',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required String period,
    required IconData icon,
    required Color color,
    required List<String> features,
    required bool isPopular,
    required bool currentPlan,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: currentPlan ? color : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Center(
                child: Text(
                  'MOST POPULAR',
                  style: GoogleFonts.outfit(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    if (currentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'CURRENT',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkText,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        period,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.mediumText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.mediumText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: currentPlan ? null : () {}, // Simulated payment
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentPlan ? Colors.grey.shade100 : AppTheme.darkText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      currentPlan ? 'ACTIVE PLAN' : 'UPGRADE NOW',
                      style: GoogleFonts.outfit(
                        color: currentPlan ? Colors.grey : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: isPopular ? 100.ms : 200.ms).scale(begin: const Offset(1, 0.95));
  }
}
