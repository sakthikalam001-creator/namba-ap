import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../models/delivery_order.dart';
import '../../services/delivery_auth_service.dart';
import '../../services/voice_dispatch_service.dart';

import '../orders/delivery_order_detail_screen.dart';
import '../orders/delivery_order_history_screen.dart';
import '../auth/delivery_login_screen.dart';
import '../profile/rider_profile_screen.dart';
import '../profile/document_status_screen.dart';
import '../earnings/rider_earnings_screen.dart';
import '../map/rider_heatmap_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen>
    with TickerProviderStateMixin {
  String _driverName = 'Partner';
  late AnimationController _pulseController;
  late AnimationController _radarController;
  bool _showAssignmentOverlay = false;
  Map<String, dynamic>? _overlayAssignment;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _radarController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _loadProfile();

    // Register callback for new assignment socket event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DeliveryProvider>(context, listen: false);
      
      // Check if there's already a pending assignment
      if (provider.pendingAssignment != null) {
        setState(() {
          _overlayAssignment = provider.pendingAssignment;
          _showAssignmentOverlay = true;
        });
      }

      provider.onNewAssignment = (data) {
        if (mounted) {
          setState(() {
            _overlayAssignment = data;
            _showAssignmentOverlay = true;
          });
        }
      };

      provider.onForceLogout = (message) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.phonelink_erase_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 8),
                  Text('Session Terminated', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Text(message, style: GoogleFonts.outfit(fontSize: 14)),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      };
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final name = await DeliveryAuthService.getDriverName();
    if (mounted) setState(() => _driverName = name);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeliveryProvider>(context);
    final isOnline = provider.isOnline;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [

          // ── Ambient Pulse ─────────────────────────────────────────────────
          if (isOnline)
            Positioned(
              top: -100, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen.withValues(alpha: 0.03),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(duration: 3.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
            ),

          // ── Main Scrollable Content ───────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildPrimeHeader(provider),
                        _buildKycStatusBanner(provider),
                        const SizedBox(height: 24),
                        _buildStatusToggle(),
                        const SizedBox(height: 24),
                        _buildPrimeEarningsCard(),
                        const SizedBox(height: 32),
                        Text('TODAY\'S METRICS',
                            style: GoogleFonts.outfit(
                                color: AppTheme.darkText.withValues(alpha: 0.3),
                                fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        _buildPrimeMetricGrid(),
                        if (provider.isHotZonesEnabled) ...[
                          const SizedBox(height: 24),
                          _buildHeatmapBanner(context),
                        ],
                        const SizedBox(height: 32),
                        _buildMissionQueueSection(),
                        const SizedBox(height: 140), // Extra space for sticky bar
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky Active Order Bar (Only shown if ONLINE) ─────────────────
          if (provider.isOnline && provider.activeOrders.isNotEmpty)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildStickyLiveOrderBar(provider.activeOrders.first),
            ),

          // ── System Status Overlays (GPS Off / No Internet) ────────────────
          if (!provider.isLocationServiceEnabled)
            _buildGpsOffOverlay(provider),
          if (!provider.isNetworkConnected)
            _buildNoNetworkOverlay(provider),

          // ── New Assignment Overlay ────────────────────────────────────────
          if (_showAssignmentOverlay && _overlayAssignment != null)
            _buildNewAssignmentOverlay(_overlayAssignment!),
        ],
      ),
    );
  }

  // ── GPS OFF FULL-SCREEN MODAL OVERLAY ─────────────────────────────────────
  Widget _buildGpsOffOverlay(DeliveryProvider provider) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.75)),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.gps_off_rounded, color: Colors.red.shade700, size: 44),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'GPS REQUIRED',
                      style: GoogleFonts.outfit(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'GPS Location Services Off',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your device location services are turned off. Rider App requires active GPS to track your delivery location and receive new order assignments.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Geolocator.openLocationSettings();
                      await provider.checkLocationService();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.location_on_rounded, size: 20),
                    label: Text(
                      'TURN ON GPS LOCATION',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => provider.checkLocationService(),
                    child: Text(
                      'I HAVE TURNED IT ON',
                      style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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

  // ── NO INTERNET FULL-SCREEN MODAL OVERLAY ──────────────────────────────────
  Widget _buildNoNetworkOverlay(DeliveryProvider provider) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.75)),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.wifi_off_rounded, color: Colors.orange.shade800, size: 44),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'NETWORK DISCONNECTED',
                      style: GoogleFonts.outfit(color: Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Internet Connection',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your phone appears to be disconnected from the internet. Please check your Mobile Data or Wi-Fi to keep your status online.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () => provider.checkNetworkConnectivity(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      'RETRY CONNECTION',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
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

  // ── NEW ASSIGNMENT FULL-SCREEN OVERLAY ────────────────────────────────────
  // ── NEW ASSIGNMENT FULL-SCREEN OVERLAY ────────────────────────────────────
  Widget _buildNewAssignmentOverlay(Map<String, dynamic> data) {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final orderId = data['orderId']?.toString() ?? '';
    final displayId = data['displayId']?.toString() ?? '';
    final vendorName = data['vendorName']?.toString() ?? 'Store';
    final vendorAddress = data['vendorAddress']?.toString() ?? '';
    final paymentMethod = (data['paymentMethod'] ?? 'ONLINE').toString().toUpperCase();

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    final rawPay = data['driverEarnings']?.toString() ?? data['amount']?.toString();
    final rawDist = data['distanceKm']?.toString();

    double distKm = (rawDist != null && double.tryParse(rawDist) != null) ? double.parse(rawDist) : 0.0;
    final incoming = provider.incomingRequests.where((o) => o.id == orderId).firstOrNull;
    if (distKm <= 0 && incoming != null && incoming.distanceInKm > 0) {
      distKm = incoming.distanceInKm;
    }

    double payValNum = (rawPay != null && double.tryParse(rawPay) != null && double.parse(rawPay) > 0)
        ? double.parse(rawPay)
        : (incoming != null
            ? incoming.computedDriverEarnings
            : (distKm > 0 ? (distKm <= 50 ? distKm * 7.0 : (50 * 7.0) + ((distKm - 50) * 9.0)) : 14.0));
    if (payValNum < 10) payValNum = 10;

    final payValStr = payValNum.toStringAsFixed(0);
    final distValStr = distKm > 0 
        ? '${distKm.toStringAsFixed(1)} KM' 
        : (incoming != null && incoming.distanceInKm > 0 ? '${incoming.distanceInKm.toStringAsFixed(1)} KM' : '1.9 KM');

    final pStatus = (data['paymentStatus'] ?? '').toString().toUpperCase();
    final cPaid = data['customerPaid'] == true;
    final isPaidOnline = pStatus == 'COMPLETED' || pStatus == 'PAID' || cPaid || (paymentMethod != 'COD' && paymentMethod.isNotEmpty);

    return AnimatedOpacity(
      opacity: _showAssignmentOverlay ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dark Frosted Glass Blur Background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: const Color(0xFF0F172A).withValues(alpha: 0.8)),
              ),
            ),

            // Pulsing Glowing Radar Rings
            Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25), width: 2),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(duration: 1600.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.12, 1.12))
               .fade(begin: 0.2, end: 0.7),
            ),

            // ── MAIN FLOATING DISPATCH CARD ─────────────────────────────
            Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 22),
                padding: EdgeInsets.all(isCompact ? 18 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🚨 Top Header Badge & Pulse Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.3, end: 1.0),
                              const SizedBox(width: 6),
                              Text(
                                'NEW ORDER ASSIGNED',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (displayId.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ORDER #$displayId',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF475569),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 🏬 Store Info & Payment Tag
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vendorName,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF0F172A),
                                  fontSize: isCompact ? 17 : 20,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPaidOnline
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isPaidOnline
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Text(
                                      isPaidOnline ? '💳 PAID ONLINE' : '💸 CASH ON DELIVERY',
                                      style: GoogleFonts.outfit(
                                        color: isPaidOnline
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFD97706),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (vendorAddress.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        vendorAddress,
                                        style: GoogleFonts.outfit(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 💰 ULTRA-HERO EARNINGS & KM CALCULATION CARD (Amount Page)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF312E81).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GUARANTEED EARNINGS (வருமானம்)',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF818CF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹$payValStr',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF34D399),
                                      fontSize: isCompact ? 30 : 36,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(icons.Iconsax.routing_copy, color: Color(0xFFFDE047), size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          distValStr,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Total Distance',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.speed_rounded, size: 14, color: Color(0xFF34D399)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Rate: ₹7 / KM Base Calculation ($distValStr Trip)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFE0E7FF),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // 🚀 Action Buttons (Decline / Accept)
                    Row(
                      children: [
                        // Decline Button
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: const Color(0xFFF8FAFC),
                            ),
                            onPressed: () async {
                              setState(() => _showAssignmentOverlay = false);
                              provider.stopAlarmSound();
                              if (orderId.isNotEmpty) {
                                await provider.declineAssignment(orderId);
                              }
                              provider.clearPendingAssignment();
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'DECLINE (நிராகரி)',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Accept Order Button
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF059669), Color(0xFF10B981)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () async {
                                setState(() => _showAssignmentOverlay = false);
                                provider.stopAlarmSound();
                                VoiceDispatchService.missionAccepted();
                                if (orderId.isNotEmpty) {
                                  await provider.acceptAssignment(orderId);
                                }
                                provider.clearPendingAssignment();
                                if (mounted && orderId.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: orderId)),
                                  );
                                }
                              },
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ACCEPT ORDER • ஏற்க',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack, duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  String _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  Widget _buildPrimeHeader(DeliveryProvider provider) {
    final isVerified = provider.isVerifiedPartner;
    final isOnline = provider.isOnline;
    final selfieDoc = provider.documents['selfie'];
    final String selfieUrl = (selfieDoc is Map ? selfieDoc['front'] ?? '' : '').toString().trim();
    final bool hasSelfie = selfieUrl.isNotEmpty;

    String resolveUrl(String path) {
      if (path.startsWith('http://') || path.startsWith('https://')) return path;
      final base = DeliveryAuthService.baseUrl.replaceAll('/api/v1', '');
      if (path.startsWith('/')) return '$base$path';
      return '$base/$path';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderProfileScreen())),
          child: Row(
            children: [
              Hero(
                tag: 'profile_pic',
                child: Stack(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: isVerified ? AppTheme.accentGreen : const Color(0xFFE2E8F0),
                          width: 2.5,
                        ),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: hasSelfie
                              ? Image.network(
                                  resolveUrl(selfieUrl),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(isVerified),
                                )
                              : Image.network(
                                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(isVerified),
                                ),
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_getGreeting()},',
                        style: GoogleFonts.outfit(
                          color: AppTheme.lightText,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(_getGreetingIcon(), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _driverName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: AppTheme.darkText,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(icons.Iconsax.verify_copy, color: AppTheme.accentGreen, size: 16),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
            boxShadow: AppTheme.softShadow,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(icons.Iconsax.notification_copy, color: AppTheme.darkText, size: 22),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05);
  }

  Widget _buildAvatarFallback(bool isVerified) {
    return Container(
      width: 52,
      height: 52,
      color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
      alignment: Alignment.center,
      child: Text(
        _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'P',
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: isVerified ? const Color(0xFF166534) : const Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _buildKycStatusBanner(DeliveryProvider provider) {
    final isVerified = provider.isVerifiedPartner;
    final hasRejection = provider.approvalStatus.toLowerCase() == 'rejected' ||
        provider.documents.values.any((doc) => doc is Map && (doc['status'] ?? '').toString().toLowerCase() == 'rejected');

    // Verified status is now displayed only inside RiderProfileScreen / DocumentStatusScreen
    if (isVerified) {
      return const SizedBox.shrink();
    }

    if (hasRejection) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(icons.Iconsax.warning_2_copy, color: Color(0xFFEF4444), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DOCUMENT CORRECTION REQUIRED', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: const Color(0xFF991B1B))),
                  const SizedBox(height: 2),
                  Text('Admin requested re-upload for rejected documents.', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentStatusScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text('RE-UPLOAD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFD97706).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(icons.Iconsax.clock_copy, color: Color(0xFFD97706), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KYC UNDER REVIEW', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, color: const Color(0xFF92400E))),
                const SizedBox(height: 2),
                Text('Documents submitted and pending Admin verification.', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFB45309), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentStatusScreen())),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              side: const BorderSide(color: Color(0xFFF59E0B)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('VIEW STATUS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 10.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggle() {
    final provider = Provider.of<DeliveryProvider>(context);
    final isOnline = provider.isOnline;

    return Container(
      width: double.infinity,
      height: 76,
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: _StatusSwipeSlider(
        isOnline: isOnline,
        onChanged: (newStatus) async {
          final result = await provider.updateOnlineStatus(newStatus);
          if (result['success'] == false) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Status Update Failed: ${result['error']}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            if (newStatus) VoiceDispatchService.systemOnline();
          }
        },
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildPrimeEarningsCard() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        double totalEarnings = 0.0;
        for (final o in provider.orderHistory) {
          if (o.status == DeliveryStatus.delivered) {
            final earn = o.computedDriverEarnings > 0 ? o.computedDriverEarnings : (o.driverEarningsBackend ?? 10.0);
            totalEarnings += earn;
          }
        }
        final String formattedEarnings = totalEarnings > 0 
            ? totalEarnings.toStringAsFixed(2) 
            : '0.00';
        final parts = formattedEarnings.split('.');
        final mainAmount = parts[0];
        final decimalAmount = parts.length > 1 ? '.${parts[1]}' : '.00';

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Ambient Glow in top right corner
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    ),
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(icons.Iconsax.wallet_money_copy, color: Color(0xFF818CF8), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'TOTAL REVENUE',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFCBD5E1),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.3)),
                          ),
                          child: const Icon(icons.Iconsax.wallet_3_copy, color: Color(0xFF818CF8), size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF34D399),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mainAmount,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          decimalAmount,
                          style: GoogleFonts.outfit(
                            color: Colors.white38,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF065F46),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(icons.Iconsax.trend_up_copy, color: Color(0xFF34D399), size: 12),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '+0% FROM YESTERDAY',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF34D399),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VIEW DETAILS',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 10),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildHeatmapBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderHeatmapScreen())),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFFF8E53)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(icons.Iconsax.radar_copy, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIND HOT ZONES',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Discover surge order clusters in your city',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.05);
  }

  Widget _buildPrimeMetricGrid() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        final allDelivered = provider.orderHistory.where((o) => o.status == DeliveryStatus.delivered).toList();
        final allCancelled = provider.orderHistory.where((o) => o.status == DeliveryStatus.cancelled).toList();
        final int totalEval = allDelivered.length + allCancelled.length;
        
        final ratedOrders = allDelivered.where((o) => o.customerRating != null && o.customerRating! > 0).toList();
        final String realRating = ratedOrders.isNotEmpty
            ? (ratedOrders.map((o) => o.customerRating!).reduce((a, b) => a + b) / ratedOrders.length).toStringAsFixed(1)
            : (allDelivered.isNotEmpty ? (allCancelled.isEmpty ? '5.0' : (4.0 + (allDelivered.length / totalEval) * 1.0).toStringAsFixed(1)) : '5.0');

        final now = DateTime.now();
        final todayDelivered = allDelivered.where((o) =>
            o.timestamp.year == now.year &&
            o.timestamp.month == now.month &&
            o.timestamp.day == now.day).toList();

        return Row(
          children: [
            Expanded(
              child: _metricTile(
                icon: icons.Iconsax.box_copy,
                label: 'ORDERS',
                sublabel: 'COMPLETED TODAY',
                value: '${todayDelivered.length}',
                color: AppTheme.accentGreen,
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFFA7F3D0),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryOrderHistoryScreen())),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _metricTile(
                icon: icons.Iconsax.star_copy,
                label: 'RATING',
                sublabel: 'CUSTOMER RATING',
                value: realRating,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
              ),
            ),
          ],
        );
      },
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required String value,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 12),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: AppTheme.darkText,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: AppTheme.darkText,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.outfit(
                color: AppTheme.lightText,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionQueueSection() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        if (!provider.isOnline) return _buildOfflinePlaceholder();

        final active = provider.activeOrders;
        final incoming = provider.incomingRequests;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ACTIVE MISSIONS ─────────────────────────────────────────────
            if (active.isNotEmpty) ...[
              Text('ACTIVE MISSIONS', style: GoogleFonts.outfit(color: AppTheme.primaryOrange.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 20),
              ...active.map((order) => _buildActiveMissionCard(order)),
              const SizedBox(height: 32),
            ],

            // ── INCOMING JOBS ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AVAILABLE JOBS', style: GoogleFonts.outfit(color: AppTheme.darkText.withValues(alpha: 0.3), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                if (incoming.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${incoming.length} NEARBY', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            if (incoming.isEmpty)
              _buildSearchingState()
            else
              Column(children: incoming.map((order) => _buildPrimeJobCard(order)).toList()),
          ],
        ).animate().fadeIn(delay: 500.ms);
      },
    );
  }

  Widget _buildOfflinePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            ),
            child: const Icon(icons.Iconsax.radar_copy, color: Color(0xFF94A3B8), size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            'YOU ARE OFFLINE',
            style: GoogleFonts.outfit(
              color: AppTheme.darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Swipe the toggle at the top or tap below to go live and receive customer orders.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.mediumText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final provider = context.read<DeliveryProvider>();
                final result = await provider.updateOnlineStatus(true);
                if (result['success'] == true) {
                  VoiceDispatchService.systemOnline();
                }
              },
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: Text(
                'GO ONLINE NOW',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildSearchingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.25), width: 2),
                ),
              ).animate(onPlay: (c) => c.repeat())
               .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.9, 1.9))
               .fade(),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(icons.Iconsax.radar_2_copy, color: AppTheme.accentGreen, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'SCANNING FOR MISSIONS',
            style: GoogleFonts.outfit(
              color: AppTheme.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stay online to receive instant delivery requests nearby...',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.lightText,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── JOB CARD (Incoming request shown as list — has Accept/Decline) ─────────
  Widget _buildPrimeJobCard(dynamic order) {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final String earningsStr = order.computedDriverEarnings > 0 
        ? '₹${order.computedDriverEarnings.toStringAsFixed(0)}' 
        : '₹${order.totalAmount.toStringAsFixed(0)}';
    final String distStr = order.formattedDistance;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.lightBg, width: 1.5),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(icons.Iconsax.box_copy, color: AppTheme.primaryOrange, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: AppTheme.darkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (order.displayId.isNotEmpty)
                          Text(
                            'ORDER #${order.displayId} • ',
                            style: GoogleFonts.outfit(
                              color: AppTheme.lightText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.paymentMethod == 'COD' ? 'COD' : 'PAID',
                            style: GoogleFonts.outfit(
                              color: order.paymentMethod == 'COD' ? Colors.orange : AppTheme.accentGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 🟢 ULTRA-PROFESSIONAL KM DISTANCE & PAYOUT BADGES
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentGreen.withValues(alpha: 0.12),
                  AppTheme.primaryOrange.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: AppTheme.accentGreen, size: 20),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RIDER PAYOUT',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          earningsStr,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(icons.Iconsax.routing_copy, color: AppTheme.primaryOrange, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        distStr,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Items preview
          if (order.items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                order.items.take(3).join(' • ') + (order.items.length > 3 ? ' +${order.items.length - 3} more' : ''),
                style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          Row(children: [
            // Accept
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  VoiceDispatchService.missionAccepted();
                  final ok = await provider.acceptAssignment(order.id);
                  if (ok && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: order.id)));
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Center(child: Text('ACCEPT JOB', style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
                ),
              ),
            ),
          ]),
        ],
      ),
    ).animate().slideX(begin: 0.1);
  }

  // ── ACTIVE MISSION CARD (with live status badge) ──────────────────────────
  Widget _buildActiveMissionCard(order) {
    final String rawStatus = order.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white, AppTheme.primaryOrange.withValues(alpha: 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle),
              child: const Icon(icons.Iconsax.routing_copy, color: Colors.white, size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MISSION IN PROGRESS', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(order.storeName.toUpperCase(), style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 18, fontWeight: FontWeight.w900)),
            ])),
            // LIVE STATUS BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withValues(alpha: 0.2))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
                const SizedBox(width: 6),
                Text(statusLabel, style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
          const Divider(height: 24, color: AppTheme.lightBg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(icons.Iconsax.box_copy, color: AppTheme.lightText, size: 14),
                const SizedBox(width: 8),
                Text('${order.items.length} ITEMS', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('VIEW DETAILS →', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ]),
      ),
    ).animate().shimmer(duration: 2.seconds).slideX(begin: -0.05);
  }

  Widget _buildStickyLiveOrderBar(order) {
    final String rawStatus = order.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: AppTheme.primaryOrange, shape: BoxShape.circle),
                  child: const Icon(icons.Iconsax.routing_copy,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LIVE MISSION',
                          style: GoogleFonts.outfit(
                              color: AppTheme.primaryOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5)),
                      Text(order.storeName.toUpperCase(),
                          style: GoogleFonts.outfit(
                              color: AppTheme.darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(statusLabel,
                              style: GoogleFonts.outfit(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DeliveryOrderDetailScreen(orderId: order.id))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.darkText,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('VIEW →',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutBack);
  }

  String _getLiveStatusLabel(String rawStatus) {
    switch (rawStatus) {
      case 'Assigned': return 'HEAD TO VENDOR';
      case 'Ready':    return 'READY FOR PICKUP';
      case 'PickedUp': return 'HEADING TO CUSTOMER';
      case 'OutForDelivery': return 'OUT FOR DELIVERY';
      default: return rawStatus.toUpperCase();
    }
  }

  Color _getLiveStatusColor(String rawStatus) {
    switch (rawStatus) {
      case 'Ready':    return AppTheme.accentGreen;
      case 'Assigned': return AppTheme.primaryOrange;
      case 'PickedUp': return Colors.indigo;
      case 'OutForDelivery': return AppTheme.accentGreen;
      default: return AppTheme.lightText;
    }
  }
}

// ── Status Swipe Slider ────────────────────────────────────────────────────────
class _StatusSwipeSlider extends StatefulWidget {
  final bool isOnline;
  final Function(bool) onChanged;
  const _StatusSwipeSlider({required this.isOnline, required this.onChanged});
  @override
  State<_StatusSwipeSlider> createState() => _StatusSwipeSliderState();
}

class _StatusSwipeSliderState extends State<_StatusSwipeSlider> {
  double _dragValue = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dragValue = widget.isOnline ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_StatusSwipeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOnline != widget.isOnline && !_isDragging) {
      setState(() => _dragValue = widget.isOnline ? 1.0 : 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      const margin = 6.0;
      const handleSize = 62.0;
      final usableWidth = maxWidth - (margin * 2) - handleSize;

      return Padding(
        padding: const EdgeInsets.all(margin),
        child: GestureDetector(
          onHorizontalDragStart: (_) => setState(() => _isDragging = true),
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragValue += details.primaryDelta! / usableWidth;
              _dragValue = _dragValue.clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (details) async {
            setState(() => _isDragging = false);
            if (widget.isOnline) {
              if (_dragValue < 0.35) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    backgroundColor: Colors.white,
                    title: Row(children: [
                      const Icon(icons.Iconsax.warning_2, color: Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Text('Go Offline?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
                    ]),
                    content: Text(
                      'Are you sure you want to go offline? You will stop receiving new delivery requests.',
                      style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 14, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('CANCEL', style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('GO OFFLINE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ) ?? false;
                
                if (confirm) {
                  widget.onChanged(false);
                } else {
                  if (mounted) setState(() => _dragValue = 1.0);
                }
              } else {
                if (mounted) setState(() => _dragValue = 1.0);
              }
            } else {
              if (_dragValue > 0.65) {
                widget.onChanged(true);
              } else {
                if (mounted) setState(() => _dragValue = 0.0);
              }
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Active fill bar
                AnimatedContainer(
                  duration: _isDragging ? Duration.zero : 250.ms,
                  width: handleSize + (_dragValue * usableWidth),
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isOnline
                          ? const [Color(0xFF10B981), Color(0xFF059669)]
                          : const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),

                // Center Track Labels (Clean & never overlapping)
                Positioned.fill(
                  child: Center(
                    child: widget.isOnline
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ).animate(onPlay: (c) => c.repeat(reverse: true))
                               .scale(duration: 800.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3)),
                              const SizedBox(width: 8),
                              Text(
                                'ONLINE • READY FOR MISSIONS',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 36),
                              Text(
                                'SWIPE TO GO ONLINE',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 13),
                            ],
                          ),
                  ),
                ),

                // Draggable Handle / Thumb
                AnimatedPositioned(
                  duration: _isDragging ? Duration.zero : 250.ms,
                  left: _dragValue * usableWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: handleSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isOnline ? const Color(0xFF059669) : const Color(0xFF4F46E5)).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        const BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.isOnline ? Icons.power_settings_new_rounded : Icons.bolt_rounded,
                        color: widget.isOnline ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
