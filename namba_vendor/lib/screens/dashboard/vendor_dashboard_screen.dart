import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/vendor_order_provider.dart';
import '../../services/language_provider.dart';
import '../orders/order_history_screen.dart';
import 'analytics_screen.dart';
import '../profile/reviews_screen.dart';
import '../profile/promotions_screen.dart';
import '../auth/vendor_login_screen.dart';
import '../profile/store_profile_screen.dart';
import '../../services/vendor_inventory_provider.dart';
import '../../models/vendor_order_model.dart';
import '../orders/vendor_orders_screen.dart';
import '../inventory/inventory_screen.dart';
import '../orders/order_tracking_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/earnings_screen.dart';
import '../profile/subscription_screen.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Consumer<VendorOrderProvider>(
          builder: (context, orderProvider, _) {
            if (orderProvider.isLocked) {
              return _buildLockedScreen(context, orderProvider, lang);
            }
            return AnimationLimiter(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 600),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      _buildHeader(context, lang),
                      Consumer<VendorOrderProvider>(
                        builder: (context, op, _) {
                          if (!op.isExpiringSoon) return const SizedBox.shrink();
                          return _buildExpiryBanner(context, op, lang);
                        },
                      ),
                      const SizedBox(height: 32),
                      Consumer<VendorOrderProvider>(
                        builder: (context, orderProvider, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              orderProvider.isLoading 
                                ? const ShimmerLoading(child: SizedBox(height: 200, width: double.infinity, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(32))))))
                                : _buildRevenuePulse(context, orderProvider, lang),
                              const SizedBox(height: 24),
                              orderProvider.isLoading 
                                  ? const SizedBox.shrink() 
                                  : _buildDailyTarget(orderProvider, lang),
                              orderProvider.isLoading 
                                  ? const SizedBox.shrink() 
                                  : const SizedBox(height: 24),
                              orderProvider.isLoading 
                                  ? const SizedBox.shrink() 
                                  : _buildStoreControls(context, orderProvider, lang),
                              orderProvider.isLoading 
                                ? Row(children: const [DashboardCardShimmer(), DashboardCardShimmer()])
                                : _buildHeroStatsRow(orderProvider, context, lang),
                              const SizedBox(height: 24),
                              orderProvider.isLoading 
                                ? Row(children: const [DashboardCardShimmer(), DashboardCardShimmer()])
                                : _buildStatsGrid(orderProvider, context, lang),
                              const SizedBox(height: 32),
                              orderProvider.isLoading 
                                  ? const SizedBox.shrink() 
                                  : _buildOrderReportGrid(orderProvider),
                              _buildActivityTimeline(orderProvider, context, lang),
                              _buildSalesTrendSection(orderProvider, lang), 
                              const SizedBox(height: 32),
                              _buildTopProductsSection(orderProvider, lang),
                              const SizedBox(height: 24),
                              _buildSectionHeader(
                                lang.translate('quick_actions'),
                                null,
                              ),
                              const SizedBox(height: 16),
                              _buildQuickActions(context, lang),
                              const SizedBox(height: 32),
                              _buildSectionHeader(
                                lang.translate('active_orders'),
                                lang.translate('view_all'),
                                onActionTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                                ),
                              ),
                              const SizedBox(height: 16),
                              orderProvider.isLoading
                                ? Column(children: const [OrderCardShimmer(), OrderCardShimmer()])
                                : _buildActiveOrdersList(context, orderProvider, lang),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildSectionHeader(lang.translate('revenue_overview'), null),
                      const SizedBox(height: 16),
                      Consumer<VendorOrderProvider>(
                        builder: (context, op, _) => _buildRevenueChart(op, lang),
                      ),
                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLockedScreen(BuildContext context, VendorOrderProvider op, LanguageProvider lang) {
    final reason = op.lockReason ?? 'Please contact administration support.';
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade100, width: 2),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.red,
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'ACCOUNT LOCKED',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.red.shade800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your vendor account has been restricted by administration.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Reason for restriction:',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                SharedPreferences.getInstance().then((prefs) {
                  prefs.clear();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const VendorLoginScreen()),
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'LOG OUT',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LanguageProvider lang) {
    return Consumer<VendorOrderProvider>(
      builder: (context, orderProvider, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildPulsingStatus(orderProvider.isStoreOpen),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: orderProvider.isStoreOpen ? AppTheme.accentGreen.withValues(alpha: 0.1) : AppTheme.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: orderProvider.isStoreOpen ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.primaryRed.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        orderProvider.isStoreOpen ? lang.translate('store_online').toUpperCase() : lang.translate('store_offline').toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: orderProvider.isStoreOpen ? AppTheme.accentGreen : AppTheme.primaryRed,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // NEW SUBSCRIPTION BADGE
                    Visibility(
                      visible: orderProvider.showSubscriptionBadge,
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: orderProvider.isSubscriptionActive ? Colors.amber.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: orderProvider.isSubscriptionActive ? Colors.amber.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.verify, color: orderProvider.isSubscriptionActive ? Colors.amber : Colors.grey, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                orderProvider.isSubscriptionActive ? (orderProvider.profile?.subscriptionPlan == 'None' ? 'TRIAL' : 'PRO') : 'INACTIVE',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: orderProvider.isSubscriptionActive ? Colors.amber.shade700 : Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    debugPrint('👆 TOGGLE AREA CLICKED');
                    orderProvider.toggleStoreStatus(
                      onError: (msg) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      },
                    );
                  },
                  child: Row(
                    children: [
                      IgnorePointer( // Ignore internal switch interaction to let GestureDetector handle it
                        child: CupertinoSwitch(
                          value: orderProvider.isStoreOpen,
                          onChanged: (_) {},
                          activeColor: AppTheme.accentGreen,
                          trackColor: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        orderProvider.isStoreOpen ? 'ONLINE' : 'OFFLINE',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: orderProvider.isStoreOpen ? AppTheme.accentGreen : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome back,',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightText,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  orderProvider.profile?.storeName ?? 'My Store',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkText,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildCircularAction(
                  icon: Iconsax.notification,
                  onTap: () {},
                  color: AppTheme.accentBlue,
                  badge: true,
                ),
                const SizedBox(width: 12),
                _buildCircularAction(
                  icon: Iconsax.setting_2,
                  onTap: () => _showSettingsSheet(context),
                  color: AppTheme.darkText,
                ),
              ],
            ),
          ],
        );
      },
    ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut).slideY(begin: -0.1, end: 0);
  }

  Widget _buildPulsingStatus(bool isOpen) {
    final color = isOpen ? AppTheme.accentGreen : AppTheme.primaryRed;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.4, 1.4),
          duration: 1000.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildCircularAction({required IconData icon, required VoidCallback onTap, required Color color, bool badge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
              ],
              border: Border.all(color: Colors.grey.shade100, width: 2),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          if (badge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRevenuePulse(BuildContext context, VendorOrderProvider op, LanguageProvider lang) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen())),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0B0F19), Color(0xFF151B2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        const Color(0xFF3B82F6).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -150,
                left: -80,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                      ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            'TOTAL REVENUE',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.accentGreen.withOpacity(0.2)),
                          ),
                          child: Text(
                            '+18.5%',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${op.todaysSales.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                'Total sales today',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        _buildGlassBadge(Iconsax.bag_2, '${op.totalOrdersCount} Orders'),
                        const SizedBox(width: 12),
                        _buildGlassBadge(
                          Iconsax.wallet_3, 
                          'Avg. Basket: ₹${op.totalOrdersCount > 0 ? (op.todaysSales / op.totalOrdersCount).round() : 0}'
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuart);
  }

  Widget _buildHeroStatsRow(VendorOrderProvider op, BuildContext context, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildHeroStatCard(
            '₹${op.todaysSales.toStringAsFixed(0)}',
            'REVENUE',
            Iconsax.wallet_money,
            AppTheme.accentBlue,
          ),
          const SizedBox(width: 12),
          _buildHeroStatCard(
            op.totalOrdersCount.toString(),
            'ORDERS',
            Iconsax.bag_2,
            AppTheme.primaryOrange,
          ),
          const SizedBox(width: 12),
          _buildHeroStatCard(
            '4.9',
            'RATING',
            Iconsax.star,
            AppTheme.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkText,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blue.shade200, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPulseStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
            Text(value, style: GoogleFonts.outfit(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800, height: 1.1)),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderReportGrid(VendorOrderProvider op) {
    final now = DateTime.now();
    final todaysOrdersList = op.orders.where((o) => 
        o.timestamp.day == now.day && 
        o.timestamp.month == now.month && 
        o.timestamp.year == now.year).toList();
        
    final totalOrders = todaysOrdersList.length;
    final completedOrders = todaysOrdersList.where((o) => o.status == VendorOrderStatus.handedOver).length;
    final revenue = op.todaysSales;
    final avgOrder = completedOrders > 0 ? (revenue / completedOrders) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Today\'s Overview', null),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildReportCard('Total Orders', totalOrders.toString(), const Color(0xFF4F46E5))),
                const SizedBox(width: 16),
                Expanded(child: _buildReportCard('Completed', completedOrders.toString(), AppTheme.accentGreen)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReportCard('Revenue', '₹${revenue.toStringAsFixed(0)}', const Color(0xFF7C3AED))),
                const SizedBox(width: 16),
                Expanded(child: _buildReportCard('Avg Order', '₹${avgOrder.toStringAsFixed(0)}', AppTheme.primaryOrange)),
              ],
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildReportCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.mediumText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(VendorOrderProvider orderProvider, BuildContext context, LanguageProvider lang) {
    final inventoryProvider = Provider.of<VendorInventoryProvider>(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(
              orderProvider.newOrders.length.toString(), 
              lang.translate('pending_orders'), 
              Iconsax.timer_1, 
              AppTheme.primaryRed,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorOrdersScreen()));
              }
            )),
            const SizedBox(width: 16),
            if (inventoryProvider.lowStockCount > 0)
              Expanded(child: _buildStatCard(
                inventoryProvider.lowStockCount.toString(), 
                'Low Stock', 
                Iconsax.warning_2, 
                AppTheme.primaryOrange,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
                }
              ))
            else
              Expanded(child: _buildStatCard(
                '4.8', 
                lang.translate('store_rating'), 
                Iconsax.star, 
                AppTheme.accentTeal,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReviewsScreen()));
                }
              )),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              orderProvider.acceptedOrdersToday.toString(), 
              'Accepted Today', 
              Iconsax.tick_circle, 
              AppTheme.accentGreen,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorOrdersScreen()));
              }
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(
              orderProvider.declinedOrdersToday.toString(), 
              'Declined Today', 
              Iconsax.close_circle, 
              const Color(0xFFE11D48), // Deep Red
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorOrdersScreen()));
              }
            )),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color baseColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: baseColor.withValues(alpha: 0.15)),
                ),
                child: Icon(icon, color: baseColor, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 12, color: AppTheme.accentGreen),
                    const SizedBox(width: 4),
                    Text('2.1%', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accentGreen)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w900, color: AppTheme.darkText, height: 1.1, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.mediumText, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildQuickActions(BuildContext context, LanguageProvider lang) {
    return Row(
      children: [
        Expanded(child: _buildActionChip(context, lang.translate('analytics'), Iconsax.graph, AppTheme.accentBlue, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen())))),
        const SizedBox(width: 12),
        Expanded(child: _buildActionChip(context, lang.translate('reviews'), Iconsax.star, AppTheme.primaryOrange, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReviewsScreen())))),
        const SizedBox(width: 12),
        Expanded(child: _buildActionChip(context, lang.translate('promotions'), Iconsax.ticket_discount, AppTheme.accentTeal, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PromotionsScreen())))),
        const SizedBox(width: 12),
        Expanded(child: _buildActionChip(context, 'Subscription', Iconsax.card_pos, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())))),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildActionChip(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.darkText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTimeline(VendorOrderProvider orderProvider, BuildContext context, LanguageProvider lang) {
    final inventoryProvider = Provider.of<VendorInventoryProvider>(context);
    
    // Combine events for timeline
    final List<Map<String, dynamic>> events = [];
    
    for (var order in orderProvider.orders.take(3)) {
      events.add({
        'type': 'order',
        'title': 'New Order ${order.displayId}',
        'subtitle': 'from ${order.customerName}',
        'time': 'Just now',
        'icon': Iconsax.bag_2,
        'color': AppTheme.accentBlue,
      });
    }

    if (inventoryProvider.lowStockCount > 0) {
      events.add({
        'type': 'inventory',
        'title': 'Low Stock Alert',
        'subtitle': '${inventoryProvider.lowStockCount} items need restocking',
        'time': 'Action Required',
        'icon': Iconsax.warning_2,
        'color': AppTheme.primaryOrange,
      });
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _buildSectionHeader('Live Activity Feed', 'View History'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: Colors.grey.shade100, width: 2),
          ),
          child: Column(
            children: events.map((event) {
              final isLast = events.indexOf(event) == events.length - 1;
              return IntrinsicHeight(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: event['color'].withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(event['icon'], color: event['color'], size: 16),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.grey.shade100,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  event['title'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                Text(
                                  event['time'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.lightText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event['subtitle'],
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.mediumText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String? action, {VoidCallback? onActionTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.accentBlue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title, 
              style: GoogleFonts.outfit(
                fontSize: 20, 
                fontWeight: FontWeight.w900, 
                color: AppTheme.darkText,
                letterSpacing: -0.3,
              )
            ),
          ],
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                action.toUpperCase(), 
                style: GoogleFonts.outfit(
                  fontSize: 11, 
                  fontWeight: FontWeight.w800, 
                  color: AppTheme.darkText,
                  letterSpacing: 0.5,
                )
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveOrdersList(BuildContext context, VendorOrderProvider orderProvider, LanguageProvider lang) {
    if (orderProvider.orders.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.lightSurface)),
        child: Text(lang.translate('no_active_orders'), style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.w600)),
      );
    }
    return Column(
      children: orderProvider.orders.take(3).map((order) {
        final statusString = order.status.name[0].toUpperCase() + order.status.name.substring(1);
        final formattedStatus = statusString == 'HandedOver' ? 'Delivered' : statusString;
        return _buildOrderListItem(context, order.displayId, '₹${order.totalAmount.toStringAsFixed(0)}', '${order.items.length} items', formattedStatus);
      }).toList(),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildOrderListItem(BuildContext context, String id, String amount, String items, String status) {
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Pending': statusColor = AppTheme.primaryRed; statusIcon = Iconsax.timer_1; break;
      case 'Accepted': statusColor = AppTheme.primaryOrange; statusIcon = Iconsax.receipt_2; break;
      case 'Preparing': statusColor = AppTheme.accentBlue; statusIcon = Iconsax.box; break;
      case 'Ready': statusColor = AppTheme.accentGreen; statusIcon = Iconsax.tick_circle; break;
      default: statusColor = AppTheme.lightText; statusIcon = Iconsax.document;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.2),
              child: Text(id.substring(id.length - 1).toUpperCase(), style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                Text('$items • $amount', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.lightText, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(
                    orderId: id,
                    storeName: 'My Store',
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(12)
              ),
              child: const Icon(Iconsax.location, color: AppTheme.accentBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrendSection(VendorOrderProvider op, LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Weekly Revenue Trend', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('This Week', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 12))],
            border: Border.all(color: Colors.grey.shade100, width: 2),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1000,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade100,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      if (value.toInt() < 0 || value.toInt() >= days.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(days[value.toInt()], style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.lightText)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2000,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      return Text('₹${(value / 1000).toStringAsFixed(0)}k', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.lightText));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: op.weeklyRevenue.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                  isCurved: true,
                  color: AppTheme.primaryOrange,
                  barWidth: 5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: index == op.weeklyRevenue.length - 1 ? 6 : 0,
                      color: AppTheme.primaryOrange,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryOrange.withValues(alpha: 0.4), AppTheme.primaryOrange.withValues(alpha: 0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildTopProductsSection(VendorOrderProvider op, LanguageProvider lang) {
    final tops = op.topSellingProducts;
    if (tops.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Top Performing Items', null),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tops.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final entry = tops.entries.elementAt(index);
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.accentTeal.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
                  border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.1), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.accentTeal.withValues(alpha: 0.2), AppTheme.accentTeal.withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Iconsax.box, color: AppTheme.accentTeal, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(entry.key, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkText, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${entry.value} Units Sold', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.lightText, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (400 + (index * 100)).ms).slideX(begin: 0.1, end: 0);
            },
          ),
        ),
      ],
    );
  }
  Widget _buildRevenueChart(VendorOrderProvider op, LanguageProvider lang) {
    return Container(
      height: 240,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 12)),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('revenue_overview'),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkText,
                    ),
                  ),
                  Text(
                    'Growth this week',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.lightText,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, color: AppTheme.accentGreen, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+14.5%',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Expanded(
            flex: 4,
            child: LineChart(
              LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1000,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade100,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      if (value.toInt() < 0 || value.toInt() >= days.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(days[value.toInt()], style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.lightText)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2000,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      return Text('₹${(value / 1000).toStringAsFixed(0)}k', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.lightText));
                    },
                  ),
                ),
              ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: op.weeklyRevenue.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: AppTheme.accentBlue,
                    barWidth: 5,
                    isStrokeCapRound: true,
                    shadow: Shadow(
                      color: AppTheme.accentBlue.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentBlue.withValues(alpha: 0.3),
                          AppTheme.accentBlue.withValues(alpha: 0),
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
  Widget _buildChartBar(double height, int index) {
    return Container(
      width: 14,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withValues(alpha: 0.8),
            AppTheme.primaryOrange,
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
    ).animate().scaleY(
          begin: 0,
          end: 1,
          duration: 600.ms,
          delay: (index * 100).ms,
          curve: Curves.easeOutBack,
        );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Settings',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Iconsax.close_circle, color: AppTheme.lightText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _settingsItem(
                    icon: Iconsax.user,
                    label: 'Store Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const StoreProfileScreen()));
                    },
                  ),
                  _settingsItem(
                    icon: Iconsax.translate,
                    label: 'Language Settings',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _settingsItem(
                    icon: Iconsax.notification,
                    label: 'Notification Alerts',
                    trailing: Switch(
                      value: true,
                      onChanged: (v) {},
                      activeTrackColor: AppTheme.accentBlue.withOpacity(0.3),
                      activeColor: AppTheme.accentBlue,
                    ),
                  ),
                  _settingsItem(
                    icon: Iconsax.support,
                    label: 'Contact Support',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connecting to Namaba Admin Support...')),
                      );
                    },
                  ),
                  const Divider(height: 32),
                  _settingsItem(
                    icon: Iconsax.logout,
                    label: 'Logout',
                    isDestructive: true,
                    onTap: () => _handleLogout(context),
                  ),
                  const SizedBox(height: 32), // Extra space for scrolling comfort
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red.shade600 : AppTheme.darkText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive ? Colors.red.shade50 : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            trailing ?? Icon(Iconsax.arrow_right_3, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Logout', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to log out of your store?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.mediumText)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Clear session
              } catch (_) {}
              
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const VendorLoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTarget(VendorOrderProvider op, LanguageProvider lang) {
    const double goal = 10000.0;
    final progress = (op.todaysSales / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentBlue.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Iconsax.chart_2, color: AppTheme.accentTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Daily Target Tracker', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                ],
              ),
              Text('${(progress * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.accentBlue)),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${op.todaysSales.toStringAsFixed(0)} achieved', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.mediumText)),
              Text('₹10,000 goal', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.lightText)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStoreControls(BuildContext context, VendorOrderProvider op, LanguageProvider lang) {
    final bool hasAutoAccept = op.profile?.allowAutoAccept ?? false;
    final bool hasSurgeBoost = op.profile?.allowSurgeBoost ?? false;
    final bool hasExtraWait = op.profile?.allowExtraWait ?? false;

    if (!hasAutoAccept && !hasSurgeBoost && !hasExtraWait) {
      return const SizedBox.shrink();
    }

    // Current visual states (ideally these would be synced with backend state too)
    bool autoAccept = hasAutoAccept;
    bool surgeBoost = false;
    bool waitTime = false;
    
    return StatefulBuilder(
      builder: (context, setState) {
        final List<Widget> children = [];
        
        if (hasAutoAccept) {
          children.add(
            _buildControlPill(
              context,
              Iconsax.magic_star, 
              'Auto-Accept', 
              autoAccept, 
              AppTheme.accentGreen, 
              true,
              (v) => setState(() => autoAccept = v)
            ),
          );
        }
        
        if (hasSurgeBoost) {
          if (children.isNotEmpty) {
            children.add(const SizedBox(width: 16));
          }
          children.add(
            _buildControlPill(
              context,
              Iconsax.flash, 
              'Surge Boost', 
              surgeBoost, 
              AppTheme.primaryRed, 
              true,
              (v) => setState(() => surgeBoost = v)
            ),
          );
        }
        
        if (hasExtraWait) {
          if (children.isNotEmpty) {
            children.add(const SizedBox(width: 16));
          }
          children.add(
            _buildControlPill(
              context,
              Iconsax.clock, 
              '+10m Wait', 
              waitTime, 
              AppTheme.accentTeal, 
              true,
              (v) => setState(() => waitTime = v)
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: children,
          ),
        ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.1, end: 0);
      }
    );
  }

  Widget _buildControlPill(
    BuildContext context, 
    IconData icon, 
    String title, 
    bool isActive, 
    Color activeColor, 
    bool hasPermission,
    ValueChanged<bool> onChanged
  ) {
    return GestureDetector(
      onTap: () {
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔒 Admin approval required to use $title.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
        onChanged(!isActive);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: !hasPermission ? Colors.grey.shade100 : (isActive ? activeColor.withValues(alpha: 0.1) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: !hasPermission ? Colors.grey.shade300 : (isActive ? activeColor.withValues(alpha: 0.3) : Colors.grey.shade200),
            width: 2,
          ),
          boxShadow: (isActive || !hasPermission) ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              !hasPermission ? Icons.lock_outline_rounded : icon, 
              color: !hasPermission ? Colors.grey.shade400 : (isActive ? activeColor : AppTheme.lightText), 
              size: 20
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: !hasPermission ? Colors.grey.shade400 : (isActive ? activeColor : AppTheme.mediumText),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 32,
              height: 20,
              child: FittedBox(
                fit: BoxFit.fill,
                child: Switch(
                  value: hasPermission && isActive,
                  onChanged: hasPermission ? onChanged : null,
                  activeColor: Colors.white,
                  activeTrackColor: activeColor,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryBanner(BuildContext context, VendorOrderProvider op, LanguageProvider lang) {
    final days = op.expiringDaysRemaining;
    final isTrial = op.profile?.subscriptionPlan == 'None';
    final planName = isTrial ? 'Free Trial' : 'Subscription Plan';
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withValues(alpha: 0.1),
            AppTheme.primaryRed.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.timer_1, color: AppTheme.primaryOrange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your $planName expires in $days ${days == 1 ? 'day' : 'days'}!',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkText,
                  ),
                ),
                Text(
                  'Renew now to keep your store online.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mediumText,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'RENEW',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.2));
  }
}

