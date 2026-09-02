import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';
import '../../services/delivery_auth_service.dart';
import '../earnings/rider_earnings_screen.dart';
import '../auth/delivery_login_screen.dart';
import 'refer_earn_screen.dart';
import 'document_status_screen.dart';
import '../docs/document_upload_screen.dart';
import 'rider_tiers_screen.dart';
import '../support/help_center_screen.dart';
import '../support/rider_chatbot_screen.dart';
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
  String _driverId = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await DeliveryAuthService.getDriverName();
    final id = await DeliveryAuthService.getDriverId();
    if (mounted) {
      setState(() {
        _driverName = name;
        _driverId = id;
      });
    }
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
                  const SizedBox(height: 20),
                  _buildAiAssistantCard(),
                  const SizedBox(height: 24),
                  _buildPrimeMenuHub(),
                  const SizedBox(height: 32),
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
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        final isVerified = provider.isVerifiedPartner;
        final hasRejection = provider.approvalStatus.toLowerCase() == 'rejected' ||
            provider.documents.values.any((doc) => doc is Map && (doc['status'] ?? '').toString().toLowerCase() == 'rejected');

        Color badgeColor = const Color(0xFFF59E0B);
        String badgeText = 'KYC UNDER REVIEW';
        IconData badgeIcon = icons.Iconsax.clock_copy;

        if (isVerified) {
          badgeColor = const Color(0xFF10B981);
          badgeText = 'VERIFIED PARTNER';
          badgeIcon = icons.Iconsax.verify_copy;
        } else if (hasRejection) {
          badgeColor = const Color(0xFFEF4444);
          badgeText = 'ACTION REQUIRED (RE-UPLOAD)';
          badgeIcon = icons.Iconsax.warning_2_copy;
        }

        final selfieDoc = provider.documents['selfie'];
        final String selfieUrl = (selfieDoc is Map ? selfieDoc['front'] ?? '' : '').toString().trim();
        final bool hasSelfie = selfieUrl.isNotEmpty;

        String resolveUrl(String path) {
          if (path.startsWith('http://') || path.startsWith('https://')) return path;
          final base = DeliveryAuthService.baseUrl.replaceAll('/api/v1', '');
          if (path.startsWith('/')) return '$base$path';
          return '$base/$path';
        }

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
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentUploadScreen(docType: 'selfie', title: 'Profile Selfie'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: isVerified ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: 3),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (hasSelfie)
                                Image.network(
                                  resolveUrl(selfieUrl),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'P',
                                      style: GoogleFonts.outfit(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: isVerified ? const Color(0xFF166534) : const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'P',
                                    style: GoogleFonts.outfit(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: isVerified ? const Color(0xFF166534) : const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  color: Colors.black.withValues(alpha: 0.45),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_driverName.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentStatusScreen())),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, color: badgeColor, size: 12),
                                const SizedBox(width: 5),
                                Text(badgeText, style: GoogleFonts.outfit(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _driverId.isNotEmpty 
                              ? 'ID: #RD-${_driverId.substring(_driverId.length > 6 ? _driverId.length - 6 : 0).toUpperCase()}'
                              : 'ID: #RD-PARTNER',
                          style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Builder(
                builder: (_) {
                  final allDelivered = provider.orderHistory.where((o) => o.status == DeliveryStatus.delivered).toList();
                  final allCancelled = provider.orderHistory.where((o) => o.status == DeliveryStatus.cancelled).toList();
                  final int totalEval = allDelivered.length + allCancelled.length;
                  
                  final ratedOrders = allDelivered.where((o) => o.customerRating != null && o.customerRating! > 0).toList();
                  final double? backendRating = provider.realDriverRating;
                  
                  final String realRating = backendRating != null
                      ? backendRating.toStringAsFixed(1)
                      : (ratedOrders.isNotEmpty
                          ? (ratedOrders.map((o) => o.customerRating!).reduce((a, b) => a + b) / ratedOrders.length).toStringAsFixed(1)
                          : (allDelivered.isEmpty ? 'New' : '5.0'));
                      
                  final String tier = allDelivered.length >= 50 ? 'Platinum' : (allDelivered.length >= 20 ? 'Gold' : 'Silver');

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPrimeMetric('${allDelivered.length}', 'JOBS'),
                      Container(width: 1, height: 24, color: AppTheme.lightBg),
                      _buildPrimeMetric(realRating == 'New' ? 'New' : '$realRating★', 'RATING'),
                      Container(width: 1, height: 24, color: AppTheme.lightBg),
                      _buildPrimeMetric(tier, 'TIER'),
                    ],
                  );
                },
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1);
      },
    );
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

  Widget _buildAiAssistantCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RiderChatbotScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4338CA).withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              top: -15,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '24/7 ONLINE',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI FLEET ASSISTANT',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Fleet Help & Live Chat',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Instant Tamil / English help & Admin Desk',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08);
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
          _buildPrimeMenuItem(
            Icons.smart_toy_rounded, 
            'AI Rider Assistant (Chatbot)', 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderChatbotScreen())),
            color: const Color(0xFF4F46E5),
          ),
          _buildPrimeMenuItem(icons.Iconsax.messages_2_copy, 'Support & Help Desk', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()))),
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
