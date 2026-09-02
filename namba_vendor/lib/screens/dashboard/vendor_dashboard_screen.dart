import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/vendor_order_provider.dart';
import '../../services/alert_service.dart';
import '../../services/language_provider.dart';
import '../../services/theme_provider.dart';
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
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../widgets/shimmer_loading.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/earnings_screen.dart';
import '../profile/subscription_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../widgets/permissions_wizard_sheet.dart';
import '../../services/api_service.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isOnline = context.watch<VendorOrderProvider>().isStoreOpen;
    
    return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
        child: Consumer<VendorOrderProvider>(
          builder: (context, orderProvider, _) {
            if (orderProvider.isLocked) {
              return _buildLockedScreen(context, orderProvider, lang);
            }
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                              : _buildOrderReportGrid(orderProvider, context, lang),
                          _buildActivityTimeline(orderProvider, context, lang),
                          _buildSalesTrendSection(orderProvider, lang, context), 
                          const SizedBox(height: 32),
                          _buildTopProductsSection(orderProvider, lang),
                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            context,
                            lang.translate('quick_actions'),
                            null,
                          ),
                          const SizedBox(height: 16),
                          _buildQuickActions(context, lang),
                          const SizedBox(height: 32),
                          _buildSectionHeader(
                            context,
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
                  _buildSectionHeader(context, lang.translate('revenue_overview'), null),
                  const SizedBox(height: 16),
                  Consumer<VendorOrderProvider>(
                    builder: (context, op, _) => _buildRevenueChart(op, lang),
                  ),
                  const SizedBox(height: 100), // Bottom padding
                ],
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildPulsingStatus(orderProvider.isStoreOpen),
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
                const SizedBox(height: 10),
                Text(
                  'Welcome back,',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightText,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  orderProvider.profile?.storeName ?? 'My Store',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
            Row(
              children: [
                _buildCircularAction(
                  context,
                  icon: Iconsax.notification,
                  onTap: () => _showNotificationsSheet(context),
                  color: AppTheme.accentBlue,
                  badge: true,
                ),
                const SizedBox(width: 12),
                _buildCircularAction(
                  context,
                  icon: Iconsax.setting_2,
                  onTap: () => _showSettingsSheet(context),
                  color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
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

  Widget _buildCircularAction(BuildContext context, {required IconData icon, required VoidCallback onTap, required Color color, bool badge = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
              ],
              border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
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
                  border: Border.all(color: isDark ? const Color(0xFF131B2E) : Colors.white, width: 2),
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
                            lang.translate('total_revenue'),
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
                                lang.translate('total_sales_today'),
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
                        Expanded(
                          child: _buildGlassBadge(Iconsax.bag_2, '${op.totalOrdersCount} Orders'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildGlassBadge(
                            Iconsax.wallet_3, 
                            'Avg: ₹${op.totalOrdersCount > 0 ? (op.todaysSales / op.totalOrdersCount).round() : 0}',
                          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blue.shade200, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 0.2,
              ),
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

  Widget _buildOrderReportGrid(VendorOrderProvider op, BuildContext context, LanguageProvider lang) {
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
        _buildSectionHeader(context, lang.isTamil ? 'இன்றைய சுருக்கம்' : 'Today\'s Overview', null),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildReportCard(context, lang.translate('total_orders'), totalOrders.toString(), const Color(0xFF4F46E5))),
                const SizedBox(width: 16),
                Expanded(child: _buildReportCard(context, lang.isTamil ? 'முடிக்கப்பட்டது' : 'Completed', completedOrders.toString(), AppTheme.accentGreen)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildReportCard(context, lang.translate('revenue'), '₹${revenue.toStringAsFixed(0)}', const Color(0xFF7C3AED))),
                const SizedBox(width: 16),
                Expanded(child: _buildReportCard(context, lang.isTamil ? 'சராசரி ஆர்டர்' : 'Avg Order', '₹${avgOrder.toStringAsFixed(0)}', AppTheme.primaryOrange)),
              ],
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildReportCard(BuildContext context, String title, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText,
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
                lang.translate('low_stock'), 
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
              lang.translate('accepted_today'), 
              Iconsax.tick_circle, 
              AppTheme.accentGreen,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const VendorOrdersScreen()));
              }
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(
              orderProvider.declinedOrdersToday.toString(), 
              lang.translate('declined_today'), 
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
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.25) : baseColor.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: isDark ? const Color(0xFF273552) : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
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
                        color: baseColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: baseColor.withValues(alpha: 0.2)),
                      ),
                      child: Icon(icon, color: baseColor, size: 24),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 12, color: AppTheme.accentGreen),
                          const SizedBox(width: 4),
                          Text(
                            '2.1%',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        Expanded(child: _buildActionChip(context, lang.isTamil ? 'சந்தா' : 'Subscription', Iconsax.card_pos, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())))),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildActionChip(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.02 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: isDark ? const Color(0xFF273552) : color.withValues(alpha: 0.1), width: 1.5),
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
                color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Combine events for timeline
    final List<Map<String, dynamic>> events = [];
    
    for (var order in orderProvider.orders.take(3)) {
      events.add({
        'type': 'order',
        'title': lang.isTamil ? 'புதிய ஆர்டர் ${order.displayId}' : 'New Order ${order.displayId}',
        'subtitle': lang.isTamil ? 'வாடிக்கையாளர்: ${order.customerName}' : 'from ${order.customerName}',
        'time': lang.isTamil ? 'இப்போது' : 'Just now',
        'icon': Iconsax.bag_2,
        'color': AppTheme.accentBlue,
      });
    }

    if (inventoryProvider.lowStockCount > 0) {
      events.add({
        'type': 'inventory',
        'title': lang.isTamil ? 'குறைந்த இருப்பு எச்சரிக்கை' : 'Low Stock Alert',
        'subtitle': lang.isTamil ? '${inventoryProvider.lowStockCount} பொருட்களுக்கு இருப்பு தேவை' : '${inventoryProvider.lowStockCount} items need restocking',
        'time': lang.isTamil ? 'கவனம் தேவை' : 'Action Required',
        'icon': Iconsax.warning_2,
        'color': AppTheme.primaryOrange,
      });
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        _buildSectionHeader(context, lang.isTamil ? 'நேரலை நடவடிக்கைகள்' : 'Live Activity Feed', lang.isTamil ? 'வரலாறு' : 'View History'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: isDark ? [] : AppTheme.cardShadow,
            border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
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
                              color: isDark ? const Color(0xFF273552) : Colors.grey.shade100,
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
                                    color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                                  ),
                                ),
                                Text(
                                  event['time'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                                color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText,
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

  Widget _buildSectionHeader(BuildContext context, String title, String? action, {VoidCallback? onActionTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
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
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade200, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    action,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Iconsax.arrow_right_3, size: 12, color: AppTheme.accentBlue),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveOrdersList(BuildContext context, VendorOrderProvider orderProvider, LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (orderProvider.orders.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? const Color(0xFF273552) : AppTheme.lightSurface),
        ),
        child: Text(lang.translate('no_active_orders'), style: GoogleFonts.outfit(color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText, fontWeight: FontWeight.w600)),
      );
    }
    return Column(
      children: orderProvider.orders.take(3).map((order) {
        final statusString = order.status.name[0].toUpperCase() + order.status.name.substring(1);
        final formattedStatus = statusString == 'HandedOver' ? 'Delivered' : statusString;
        final itemsLabel = lang.isTamil ? '${order.items.length} பொருட்கள்' : '${order.items.length} items';
        return _buildOrderListItem(context, order.displayId, '₹${order.totalAmount.toStringAsFixed(0)}', itemsLabel, formattedStatus, lang);
      }).toList(),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildOrderListItem(BuildContext context, String id, String amount, String items, String status, LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    String statusDisplay = status;
    switch (status) {
      case 'Pending':
        statusColor = AppTheme.primaryRed;
        statusDisplay = lang.isTamil ? 'புதியது' : 'PENDING';
        break;
      case 'Accepted':
        statusColor = AppTheme.primaryOrange;
        statusDisplay = lang.isTamil ? 'ஏற்கப்பட்டது' : 'ACCEPTED';
        break;
      case 'Preparing':
        statusColor = AppTheme.accentBlue;
        statusDisplay = lang.isTamil ? 'சமையலில்' : 'PREPARING';
        break;
      case 'Ready':
        statusColor = AppTheme.accentGreen;
        statusDisplay = lang.isTamil ? 'தயார்' : 'READY';
        break;
      default:
        statusColor = AppTheme.lightText;
        statusDisplay = status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
        boxShadow: isDark ? [] : AppTheme.cardShadow,
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
                Text(id, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText)),
                Text('$items • $amount', style: GoogleFonts.outfit(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(
              statusDisplay,
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrendSection(VendorOrderProvider op, LanguageProvider lang, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lang.isTamil ? 'வாராந்திர வருவாய் வரைபடம்' : 'Weekly Revenue Trend', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(lang.isTamil ? 'இந்த வாரம்' : 'This Week', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: isDark ? [] : [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 12))],
            border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
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
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, lang.translate('top_products'), null),
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
                      color: isDark ? const Color(0xFF131B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isDark ? [] : [BoxShadow(color: AppTheme.accentTeal.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
                      border: Border.all(color: isDark ? const Color(0xFF273552) : AppTheme.accentTeal.withValues(alpha: 0.1), width: 1.5),
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
                              Text(entry.key, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${entry.value} ${lang.isTamil ? 'விற்பனையானது' : 'Units Sold'}', style: GoogleFonts.outfit(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText, fontWeight: FontWeight.w600)),
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
      },
    );
  }

  Widget _buildRevenueChart(VendorOrderProvider op, LanguageProvider lang) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: 240,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: isDark ? [] : [
              BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 12)),
            ],
            border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
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
                          color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                        ),
                      ),
                      Text(
                        lang.isTamil ? 'இந்த வார வளர்ச்சி' : 'Growth this week',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText,
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
  },
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool notificationsEnabled = true;
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final isDark = themeProvider.isDarkMode;
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.65,
                  minChildSize: 0.4,
                  maxChildSize: 0.9,
                  expand: false,
                  builder: (context, scrollController) {
                    final langProvider = Provider.of<LanguageProvider>(context);
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.transparent),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Iconsax.setting_2, color: AppTheme.primaryOrange, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  langProvider.translate('settings'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppTheme.darkText,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Iconsax.close_circle, color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // 1. Store Profile
                            _settingsItem(
                              icon: Iconsax.user,
                              label: langProvider.translate('profile'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const StoreProfileScreen()));
                              },
                            ),
                            // 2. Dark / Light Theme Toggle
                            _settingsItem(
                              icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              label: isDark ? langProvider.translate('dark_mode') : langProvider.translate('light_mode'),
                              onTap: () {
                                themeProvider.toggleTheme();
                              },
                              trailing: CupertinoSwitch(
                                value: isDark,
                                activeColor: AppTheme.primaryOrange,
                                onChanged: (_) {
                                  themeProvider.toggleTheme();
                                },
                              ),
                            ),
                            // 3. Language Settings (English, Tamil, Tanglish)
                            _settingsItem(
                              icon: Iconsax.translate,
                              label: '${langProvider.translate('language')} (${langProvider.languageName})',
                              onTap: () {
                                Navigator.pop(context);
                                _showLanguageDialog(context);
                              },
                            ),
                            // 4. Notification Alerts Toggle
                            _settingsItem(
                              icon: Iconsax.notification,
                              label: langProvider.translate('notifications_alerts'),
                              onTap: () async {
                                final newVal = !notificationsEnabled;
                                setSheetState(() => notificationsEnabled = newVal);
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('vendor_notifications_enabled', newVal);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(newVal ? '🔔 Notifications enabled!' : '🔕 Notifications muted.'),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: newVal ? const Color(0xFF059669) : Colors.grey.shade700,
                                    ),
                                  );
                                }
                              },
                              trailing: CupertinoSwitch(
                                value: notificationsEnabled,
                                activeColor: AppTheme.primaryOrange,
                                onChanged: (v) async {
                                  setSheetState(() => notificationsEnabled = v);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('vendor_notifications_enabled', v);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(v ? '🔔 Notifications enabled!' : '🔕 Notifications muted.'),
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: v ? const Color(0xFF059669) : Colors.grey.shade700,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            // 5. Background Battery Optimization
                            _settingsItem(
                              icon: Iconsax.battery_charging,
                              label: langProvider.translate('allow_background_battery'),
                              onTap: () async {
                                Navigator.pop(context);
                                await PermissionsWizardSheet.show(context);
                              },
                            ),
                            // 6. Contact Admin Support
                            _settingsItem(
                              icon: Iconsax.support,
                              label: langProvider.translate('admin_support'),
                              onTap: () {
                                Navigator.pop(context);
                                _showContactSupportSheet(context);
                              },
                            ),
                            Divider(height: 28, color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                            // 7. Logout
                            _settingsItem(
                              icon: Iconsax.logout,
                              label: langProvider.translate('logout'),
                              isDestructive: true,
                              onTap: () => _handleLogout(context),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final orderProvider = context.read<VendorOrderProvider>();
    final activeOrders = orderProvider.preparingOrders;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Iconsax.notification_bing, color: Color(0xFF4F46E5), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications & Alerts',
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'நேரலை அறிவிப்புகள் மற்றும் எச்சரிக்கைகள்',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Iconsax.close_circle, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  // Item 1: Store Approved Status
                  _buildNotificationCard(
                    icon: Icons.verified_rounded,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                    title: 'Store Approved & Live 🎉',
                    subtitle: 'Your store profile is verified and ready to accept orders.',
                    time: 'Just now',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Item 2: Active Orders Status
                  if (activeOrders.isNotEmpty) ...[
                    _buildNotificationCard(
                      icon: Icons.receipt_long_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      title: '${activeOrders.length} Active Orders in Kitchen 🍳',
                      subtitle: 'Check order manager for rider pickup status.',
                      time: 'Active',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Item 3: Sound Alert Ready
                  _buildNotificationCard(
                    icon: Icons.volume_up_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Loud Order Ringtone Active 🔔',
                    subtitle: 'New orders will ring continuously until accepted.',
                    time: 'System',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Item 4: 24/7 Super Admin Support
                  _buildNotificationCard(
                    icon: Icons.headset_mic_rounded,
                    iconBg: const Color(0xFFFAF5FF),
                    iconColor: const Color(0xFF9333EA),
                    title: 'Super Admin Priority Helpline',
                    subtitle: 'WhatsApp & Direct call assistance available 24/7.',
                    time: 'Helpdesk',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192238) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF273552) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        surfaceTintColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Iconsax.translate, color: Color(0xFF818CF8), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Language',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  Text(
                    'மொழியைத் தேர்வு செய்க',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Option 1: Tamil (தமிழ்)
            _buildLanguageTile(
              flag: '🇮🇳',
              title: 'தமிழ் (Tamil)',
              subtitle: 'செந்தமிழ் முழு வடிவம்',
              isSelected: lang.currentLanguage == AppLanguage.tamil,
              isDark: isDark,
              onTap: () {
                lang.setLanguage(AppLanguage.tamil);
                Navigator.pop(ctx);
                AlertService.showToast('மொழி தமிழுக்கு மாற்றப்பட்டது ✅');
              },
            ),
            const SizedBox(height: 10),
            // Option 2: Tanglish (தமிழ்)
            _buildLanguageTile(
              flag: '🇮🇳',
              title: 'Tanglish (தமிழ்)',
              subtitle: 'இயல்பான பேச்சுத் தமிழ்',
              isSelected: lang.currentLanguage == AppLanguage.tanglish,
              isDark: isDark,
              onTap: () {
                lang.setLanguage(AppLanguage.tanglish);
                Navigator.pop(ctx);
                AlertService.showToast('Language switched to Tanglish ✅');
              },
            ),
            const SizedBox(height: 10),
            // Option 3: English
            _buildLanguageTile(
              flag: '🇬🇧',
              title: 'English',
              subtitle: 'Standard English Interface',
              isSelected: lang.currentLanguage == AppLanguage.english,
              isDark: isDark,
              onTap: () {
                lang.setLanguage(AppLanguage.english);
                Navigator.pop(ctx);
                AlertService.showToast('Language switched to English ✅');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required String flag,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF4338CA).withValues(alpha: 0.3) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isSelected ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 20)
            else
              Icon(Icons.circle_outlined, color: isDark ? const Color(0xFF475569) : Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    );
  }

  void _showContactSupportSheet(BuildContext context) {
    final provider = context.read<VendorOrderProvider>();
    final storeName = provider.profile?.storeName ?? 'Store';
    final vendorId = provider.vendorId;
    final phone = provider.profile?.phone ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Iconsax.headphone, color: Color(0xFF4F46E5), size: 26),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Support Desk', style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                    Text('24/7 Priority Partner Assistance', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Option 1: Raise Support Ticket (Direct to Admin Support Hub)
            _buildSupportOption(
              icon: Iconsax.ticket,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              title: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'புகார் பதிவு' : (Provider.of<LanguageProvider>(context, listen: false).isTanglish ? 'Support Ticket Podunga' : 'Raise Support Ticket'),
              subtitle: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'அட்மின் உதவி மையத்திற்கு நேரடியாகச் செல்லும்' : 'Directly submits to Admin Support Hub',
              badge: 'DIRECT HUB 📌',
              onTap: () {
                Navigator.pop(ctx);
                _showRaiseTicketModal(context);
              },
            ),
            const SizedBox(height: 12),
            // Option 2: WhatsApp Support
            _buildSupportOption(
              icon: Icons.chat_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF16A34A),
              title: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'வாட்ஸ்அப் உதவி (WhatsApp)' : 'Chat on WhatsApp',
              subtitle: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'அட்மினுடன் உடனடி வாட்ஸ்அப் உரையாடல்' : 'Direct instant chat with Super Admin',
              badge: 'FASTEST ⚡',
              onTap: () async {
                Navigator.pop(ctx);
                final text = Uri.encodeComponent('Hello Namba Admin, I am from $storeName (ID: $vendorId, Phone: $phone). I need assistance regarding my store.');
                final uri = Uri.parse('https://wa.me/919363667770?text=$text');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  AlertService.showToast('Opening WhatsApp failed. Please call Admin helpline.');
                }
              },
            ),
            const SizedBox(height: 12),
            // Option 3: Phone Call
            _buildSupportOption(
              icon: Icons.phone_in_talk_rounded,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              title: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'அட்மினை நேரடியாக அழைக்க' : 'Call Admin Hotline',
              subtitle: '+91 93636 67770 (Direct Partner Helpline)',
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('tel:+919363667770');
                try {
                  await launchUrl(uri);
                } catch (e) {
                  AlertService.showToast('Calling helpline failed.');
                }
              },
            ),
            const SizedBox(height: 12),
            // Option 4: Email Support
            _buildSupportOption(
              icon: Icons.mail_outline_rounded,
              iconBg: const Color(0xFFFAF5FF),
              iconColor: const Color(0xFF9333EA),
              title: 'Email Partner Desk',
              subtitle: 'support@nambadelivery.in',
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('mailto:support@nambadelivery.in?subject=Vendor%20Assistance%20-%20$storeName');
                try {
                  await launchUrl(uri);
                } catch (e) {
                  // Fallback
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showRaiseTicketModal(BuildContext context) {
    final provider = context.read<VendorOrderProvider>();
    final storeName = provider.profile?.storeName ?? 'Store';
    final vendorId = provider.vendorId;
    final phone = provider.profile?.phone ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String selectedCategory = 'Order Issue';
    String selectedPriority = 'Medium';
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final orderIdController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Iconsax.ticket, color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raise Support Ticket',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Super Admin Support Hub • உடனடி உதவி',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Iconsax.close_circle, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Category Selector
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'புகார் வகை' : 'Issue Category',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Order Issue',
                    'Payout / Settlement',
                    'Menu & Items',
                    'App & Device',
                    'Account Support',
                  ].map((cat) {
                    final isSel = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12)),
                      selected: isSel,
                      selectedColor: const Color(0xFF4F46E5),
                      labelStyle: TextStyle(color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155))),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val) setModalState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Priority Selector
                Text(
                  Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'முக்கியத்துவம்' : 'Priority Level',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['Medium', 'High', 'Urgent'].map((p) {
                    final isSel = selectedPriority == p;
                    Color pColor = const Color(0xFF3B82F6);
                    if (p == 'High') pColor = const Color(0xFFF59E0B);
                    if (p == 'Urgent') pColor = const Color(0xFFEF4444);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => selectedPriority = p),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? pColor : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSel ? pColor : const Color(0xFFE2E8F0)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Subject Field
                TextField(
                  controller: subjectController,
                  style: GoogleFonts.outfit(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'தலைப்பு' : 'Subject',
                    hintText: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'எ.கா: இன்றைய கொடுப்பனவு பற்றிய கேள்வி' : 'e.g. Settlement inquiry for today',
                    labelStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
                    hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),

                // Order ID (Optional) Field
                TextField(
                  controller: orderIdController,
                  style: GoogleFonts.outfit(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'ஆர்டர் எண் (விருப்பப்பட்டால்)' : 'Order ID (Optional)',
                    hintText: 'e.g. ORD-1042',
                    labelStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
                    hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),

                // Message Field
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  style: GoogleFonts.outfit(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'விவரம் *' : 'Description *',
                    hintText: Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'சிக்கலை விரிவாக எழுதவும்...' : 'Please describe the problem in detail...',
                    labelStyle: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13),
                    hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final subject = subjectController.text.trim();
                            final desc = messageController.text.trim();
                            final isTa = Provider.of<LanguageProvider>(context, listen: false).isTamil;
                            if (desc.isEmpty) {
                              AlertService.showToast(isTa ? 'விளக்கம் எழுதவும்' : 'Please enter problem description', isError: true);
                              return;
                            }

                            setModalState(() => isSubmitting = true);

                            final ticketData = {
                              'userType': 'Vendor',
                              'userId': vendorId,
                              'userName': storeName,
                              'userPhone': phone,
                              'subject': subject.isNotEmpty ? subject : '$selectedCategory Issue - $storeName',
                              'category': selectedCategory,
                              'issueType': selectedCategory,
                              'priority': selectedPriority,
                              'message': desc,
                              'orderDisplayId': orderIdController.text.trim(),
                            };

                            final res = await ApiService().createSupportTicket(ticketData);

                            setModalState(() => isSubmitting = false);

                            if (res != null) {
                              Navigator.pop(ctx);
                              final ticketId = res['ticketId'] ?? 'TKT';
                              AlertService.showToast(isTa ? 'புகார் #$ticketId அட்மினுக்கு அனுப்பப்பட்டது!' : 'Ticket #$ticketId submitted to Super Admin!');
                            } else {
                              AlertService.showToast(isTa ? 'புகார் பதிவு செய்ய முடியவில்லை' : 'Failed to submit ticket.', isError: true);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            Provider.of<LanguageProvider>(context, listen: false).isTamil ? 'அட்மினுக்கு அனுப்பு 🚀' : (Provider.of<LanguageProvider>(context, listen: false).isTanglish ? 'Admin-ku Anuppu 🚀' : 'Submit Ticket to Admin 🚀'),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text(badge, style: TextStyle(color: Colors.green.shade700, fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = isDestructive ? Colors.red.shade500 : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A));
        final bgColor = isDestructive ? Colors.red.shade900.withValues(alpha: 0.2) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                trailing ?? Icon(Icons.arrow_forward_ios_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        surfaceTintColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade500.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.logout, color: Colors.red.shade500, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Confirm Logout',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to log out of your store account?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const VendorLoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTarget(VendorOrderProvider op, LanguageProvider lang) {
    const double goal = 10000.0;
    final progress = (op.todaysSales / goal).clamp(0.0, 1.0);
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.25) : AppTheme.accentBlue.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF273552) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
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
                        Flexible(
                          child: Text(
                            lang.translate('daily_target_tracker'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(progress * 100).toInt()}%', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.accentBlue)),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang.isTamil ? '₹${op.todaysSales.toStringAsFixed(0)} அடைந்தது' : '₹${op.todaysSales.toStringAsFixed(0)} achieved',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    lang.isTamil ? '₹10,000 இலக்கு' : '₹10,000 goal',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _checkAndPromptBatteryOptimization(BuildContext context, {bool forcePrompt = false}) async {
    try {
      final isIgnored = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (isIgnored) {
        if (forcePrompt && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Background usage is already allowed ✅'),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.battery_alert_rounded, color: Color(0xFF4F46E5), size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Allow Background Usage',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'புது ஆர்டர்கள் போன் பூட்டப்பட்டிருந்தாலும் (Lock Screen) உடனுக்குடன் சத்தமாக ஒலிக்க "Allow background usage" அமைப்பை ஆன் செய்ய வேண்டும்.',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ஆஃப் செய்யப்பட்டிருந்தால் புது ஆர்டர் எச்சரிக்கைகள் வராது அல்லது தாமதமாகலாம்.',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('LATER', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await FlutterForegroundTask.requestIgnoreBatteryOptimization();
              },
              child: Text('ENABLE NOW', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Battery optimization dialog error: $e');
    }
  }
}

