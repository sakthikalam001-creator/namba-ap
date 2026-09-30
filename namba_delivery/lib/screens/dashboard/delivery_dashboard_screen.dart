import 'dart:async';
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
import '../../services/delivery_language_provider.dart';

import '../orders/delivery_order_detail_screen.dart';
import '../orders/delivery_order_history_screen.dart';
import '../auth/delivery_login_screen.dart';
import '../profile/rider_profile_screen.dart';
import '../profile/rider_ratings_screen.dart';
import '../profile/document_status_screen.dart';
import '../earnings/rider_earnings_screen.dart';
import '../map/rider_heatmap_screen.dart';
import '../notifications/rider_notifications_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String _driverName = 'Partner';
  late AnimationController _pulseController;
  late AnimationController _radarController;
  bool _showAssignmentOverlay = false;
  Map<String, dynamic>? _overlayAssignment;
  Timer? _statusSyncTimer;
  final Set<String> _declinedOrderIdsThisSession = {};
  int _selectedBatchTab = 0;
  int _selectedStickyBatchTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _radarController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _loadProfile();

    // Background sync only if driver is pending verification
    _statusSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        final provider = Provider.of<DeliveryProvider>(context, listen: false);
        if (!provider.isVerifiedPartner) {
          provider.fetchDocumentStatuses();
        } else {
          _statusSyncTimer?.cancel();
        }
      }
    });

    // Register callback for new assignment socket event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DeliveryProvider>(context, listen: false);
      provider.fetchDocumentStatuses();
      provider.fetchHistory();
      
      // Auto-check for pending orders whether opened via notification or directly opened app
      _checkAndShowPendingAssignment();

      provider.onNewAssignment = (data) {
        if (mounted) {
          final orderId = data['orderId']?.toString() ?? data['_id']?.toString() ?? '';
          if (orderId.isEmpty || !_declinedOrderIdsThisSession.contains(orderId)) {
            setState(() {
              _overlayAssignment = data;
              _showAssignmentOverlay = true;
            });
          }
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = Provider.of<DeliveryProvider>(context, listen: false);
      provider.syncOrdersSilently();
      _checkAndShowPendingAssignment();
    }
  }

  void _checkAndShowPendingAssignment() {
    if (!mounted) return;
    final provider = Provider.of<DeliveryProvider>(context, listen: false);

    // 1. Pending Assignment from socket / notification
    if (provider.pendingAssignment != null) {
      final orderId = provider.pendingAssignment?['orderId']?.toString() ?? provider.pendingAssignment?['_id']?.toString() ?? '';
      if (orderId.isEmpty || !_declinedOrderIdsThisSession.contains(orderId)) {
        setState(() {
          _overlayAssignment = provider.pendingAssignment;
          _showAssignmentOverlay = true;
        });
        return;
      }
    }

    // 2. Incoming Requests from API
    final incomingMap = _getIncomingAssignmentMap(provider);
    if (incomingMap != null) {
      setState(() {
        _overlayAssignment = incomingMap;
        _showAssignmentOverlay = true;
      });
    }
  }

  Map<String, dynamic>? _getIncomingAssignmentMap(DeliveryProvider provider) {
    DeliveryOrder? target;
    for (final req in provider.incomingRequests) {
      if (!_declinedOrderIdsThisSession.contains(req.id)) {
        target = req;
        break;
      }
    }

    // Check activeOrders for any order awaiting pickup not yet accepted locally
    if (target == null) {
      for (final act in provider.activeOrders) {
        if ((act.status == DeliveryStatus.allocated || act.status == DeliveryStatus.pickingUp) &&
            !_declinedOrderIdsThisSession.contains(act.id) &&
            !provider.locallyAcceptedOrderIds.contains(act.id)) {
          target = act;
          break;
        }
      }
    }
    if (target == null) return null;

    final dist = target.distanceInKm;
    final earnings = target.computedDriverEarnings > 0
        ? target.computedDriverEarnings
        : (dist > 0 ? (dist <= 50 ? dist * 7.0 : (50 * 7.0) + ((dist - 50) * 9.0)) : 14.0);

    return {
      'orderId': target.id,
      'displayId': target.displayId,
      'vendorName': target.storeName,
      'vendorAddress': target.storeAddress,
      'amount': earnings.toString(),
      'driverEarnings': earnings.toString(),
      'distanceKm': dist.toString(),
      'paymentMethod': target.paymentMethod,
      'paymentStatus': target.paymentStatus,
      'customerPaid': target.paymentStatus.toUpperCase() == 'COMPLETED' || target.paymentStatus.toUpperCase() == 'PAID',
      'isOfficeDelivery': target.isOfficeDelivery,
      'deliveryAddressLabel': target.deliveryAddressLabel,
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSyncTimer?.cancel();
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

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: Stack(
        children: [

          // ── Main Scrollable Content ───────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        _buildPrimeHeader(provider),
                        _buildKycStatusBanner(provider),
                        const SizedBox(height: 20),
                        _buildStatusToggle(),
                        const SizedBox(height: 20),
                        _buildPrimeEarningsCard(),
                        const SizedBox(height: 28),
                        Text('TODAY\'S METRICS',
                            style: GoogleFonts.outfit(
                                color: const Color(0xFF475569),
                                fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 14),
                        _buildPrimeMetricGrid(),
                        if (provider.isHotZonesEnabled) ...[
                          const SizedBox(height: 20),
                          _buildHeatmapBanner(context),
                        ],
                        const SizedBox(height: 28),
                        _buildMissionQueueSection(),
                        SizedBox(height: (provider.activeOrders.isNotEmpty ? 220 : 60) + MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky Active Order Bar ─────────────────────────────────────────
          if (provider.activeOrders.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                bottom: true,
                child: provider.activeOrders.length >= 2
                    ? _buildBatchStickyLiveOrderBar(provider.activeOrders)
                    : _buildStickyLiveOrderBar(provider.activeOrders.first),
              ),
            ),

          // ── System Status Overlays (GPS Off / No Internet) ────────────────
          if (!provider.isLocationServiceEnabled)
            _buildGpsOffOverlay(provider),
          if (!provider.isNetworkConnected)
            _buildNoNetworkOverlay(provider),

          // ── New Assignment Overlay (Notification or Direct App Open) ─────────
          Builder(builder: (context) {
            final incomingList = provider.incomingRequests
                .where((r) => !_declinedOrderIdsThisSession.contains(r.id))
                .toList();

            if (incomingList.length >= 2) {
              return _buildBatchAssignmentOverlay(incomingList);
            }

            Map<String, dynamic>? activeAssignment = (_showAssignmentOverlay && _overlayAssignment != null)
                ? _overlayAssignment
                : (provider.pendingAssignment ?? _getIncomingAssignmentMap(provider));

            if (activeAssignment != null) {
              final orderId = activeAssignment['orderId']?.toString() ?? activeAssignment['_id']?.toString() ?? '';
              if (orderId.isEmpty || !_declinedOrderIdsThisSession.contains(orderId)) {
                return _buildNewAssignmentOverlay(activeAssignment);
              }
            }
            return const SizedBox.shrink();
          }),
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

  // ── BATCH ASSIGNMENT FULL-SCREEN OVERLAY (2+ ORDERS) ────────────────────
  Widget _buildBatchAssignmentOverlay(List<DeliveryOrder> incomingList) {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final lang = Provider.of<DeliveryLanguageProvider>(context, listen: false);

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    double totalEarnings = 0;
    double totalKm = 0;
    for (var o in incomingList) {
      final pay = o.computedDriverEarnings > 0 ? o.computedDriverEarnings : 14.0;
      totalEarnings += pay;
      totalKm += o.distanceInKm;
    }
    if (totalKm <= 0) totalKm = 4.2;

    final payValStr = totalEarnings.toStringAsFixed(0);
    final distValStr = '${totalKm.toStringAsFixed(1)} KM';

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dark Frosted Glass Blur Background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: const Color(0xFF0F172A).withValues(alpha: 0.88)),
              ),
            ),

            // Pulsing Glowing Radar Rings
            Center(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.25), width: 2),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(duration: 1600.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15))
               .fade(begin: 0.2, end: 0.7),
            ),

            // Main Floating Dispatch Card
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20),
                    padding: EdgeInsets.all(isCompact ? 16 : 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Header Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.35),
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
                                  const SizedBox(width: 8),
                                  Text(
                                    lang.text(
                                      en: 'BATCH ASSIGNMENT (2 ORDERS)',
                                      ta: '2 புதிய ஆர்டர்கள் ஒதுக்கப்பட்டுள்ளன',
                                      tanglish: 'BATCH ASSIGNMENT (2 ORDERS)',
                                    ),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                '${incomingList.length} STOPS',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1D4ED8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Subtitle
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            lang.text(
                              en: 'Combined Multi-Pickup & Delivery Route',
                              ta: 'வரிசைப்படுத்தப்பட்ட பிக்கப் மற்றும் டெலிவரி பாதை',
                              tanglish: 'Combined Multi-Pickup & Delivery Route',
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ultra-Hero Combined Earnings Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang.text(
                                          en: 'TOTAL BATCH EARNINGS',
                                          ta: 'மொத்த தொகுப்பு வருமானம்',
                                          tanglish: 'TOTAL BATCH EARNINGS',
                                        ),
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF94A3B8),
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
                                          fontSize: isCompact ? 28 : 34,
                                          fontWeight: FontWeight.w900,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(icons.Iconsax.routing_copy, color: Color(0xFFFDE047), size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              distValStr,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          lang.text(en: 'Total Route', ta: 'மொத்த தூரம்', tanglish: 'Total Route'),
                                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 8.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      lang.text(
                                        en: '2 Trips Completed in 1 Single Route',
                                        ta: 'ஒரே பயணத்தில் 2 ஆர்டர்களை முடிக்கலாம்',
                                        tanglish: 'Ore trip-la 2 Orders Mudikkalam',
                                      ),
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFFE2E8F0),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section Header: The Two Orders ("வகுத்தல்")
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            lang.text(
                              en: 'ORDERS IN THIS BATCH',
                              ta: 'தொகுப்பில் உள்ள ஆர்டர்கள்',
                              tanglish: 'ORDERS IN THIS BATCH',
                            ),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF475569),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // List of the two orders
                        ...incomingList.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final ord = entry.value;
                          final isFirst = idx == 0;
                          final stopBadgeColor = isFirst ? const Color(0xFFF97316) : const Color(0xFF3B82F6);
                          final ordPay = ord.computedDriverEarnings > 0 ? ord.computedDriverEarnings : 14.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: stopBadgeColor.withValues(alpha: 0.3), width: 1.2),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: stopBadgeColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${lang.text(en: 'STOP', ta: 'நிறுத்தம்', tanglish: 'STOP')} ${idx + 1}',
                                            style: GoogleFonts.outfit(
                                              color: stopBadgeColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (ord.displayId.isNotEmpty)
                                          Text(
                                            '#${ord.displayId}',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF64748B),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      '₹${ordPay.toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF475569)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        ord.storeName.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (ord.storeAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 22),
                                    child: Text(
                                      ord.storeAddress,
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        ord.customerAddress.isNotEmpty ? ord.customerAddress : 'Customer Delivery Address',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF334155),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),

                        // Action Buttons
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
                                onPressed: () {
                                  setState(() {
                                    for (var o in incomingList) {
                                      _declinedOrderIdsThisSession.add(o.id);
                                    }
                                    _showAssignmentOverlay = false;
                                    _overlayAssignment = null;
                                  });
                                },
                                child: Text(
                                  lang.text(en: 'DECLINE', ta: 'நிராகரி', tanglish: 'DECLINE'),
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Accept Batch Button
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
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () async {
                                    setState(() {
                                      _showAssignmentOverlay = false;
                                      _overlayAssignment = null;
                                    });
                                    final orderIds = incomingList.map((o) => o.id).toList();
                                    final success = await provider.acceptBatchAssignments(orderIds);
                                    if (context.mounted && success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            lang.text(
                                              en: 'Batch Orders Accepted Successfully!',
                                              ta: '2 ஆர்டர்களும் வெற்றிகரமாக ஏற்கப்பட்டன!',
                                              tanglish: '2 Orders Accept Aagivittathu!',
                                            ),
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                                          ),
                                          backgroundColor: const Color(0xFF059669),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    lang.text(
                                      en: 'ACCEPT BATCH (2) ➔',
                                      ta: '2 ஆர்டர்களையும் ஏற்கவும் ➔',
                                      tanglish: 'ACCEPT BATCH (2) ➔',
                                    ),
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NEW ASSIGNMENT FULL-SCREEN OVERLAY ────────────────────────────────────
  Widget _buildNewAssignmentOverlay(Map<String, dynamic> data) {
    final provider = Provider.of<DeliveryProvider>(context, listen: false);
    final orderId = data['orderId']?.toString() ?? '';
    final displayId = data['displayId']?.toString() ?? '';
    final vendorName = data['vendorName']?.toString() ?? 'Store';
    final vendorAddress = data['vendorAddress']?.toString() ?? '';
    final paymentMethod = (data['paymentMethod'] ?? 'ONLINE').toString().toUpperCase();
    final bool isOfficeDelivery = data['isOfficeDelivery'] == true || 
        (data['deliveryAddressLabel']?.toString().toLowerCase() == 'office');

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;

    final rawDist = data['distanceKm']?.toString();
    double distKm = (rawDist != null && double.tryParse(rawDist) != null) ? double.parse(rawDist) : 0.0;
    final incoming = provider.incomingRequests.where((o) => o.id == orderId).firstOrNull;
    if (distKm <= 0 && incoming != null && incoming.distanceInKm > 0) {
      distKm = incoming.distanceInKm;
    }

    // Accurate KM-based formula:
    // Rate: ₹7.0 / KM. Minimum guarantee: ₹10 (or ₹14 for short trips up to 2 KM).
    // Never fall back to data['amount'] which represents the customer's food bill total.
    double computeRiderEarnings(double km) {
      if (km <= 0) return 14.0;
      double pay = km <= 50 ? km * 7.0 : (50 * 7.0) + ((km - 50) * 9.0);
      return pay < 10.0 ? 10.0 : pay.roundToDouble();
    }

    double payValNum;
    final rawDriverEarnings = data['driverEarnings'] != null ? double.tryParse(data['driverEarnings'].toString()) : null;

    if (distKm > 0) {
      payValNum = computeRiderEarnings(distKm);
    } else if (rawDriverEarnings != null && rawDriverEarnings > 0 && rawDriverEarnings < 150) {
      payValNum = rawDriverEarnings;
    } else if (incoming != null && incoming.computedDriverEarnings > 0) {
      payValNum = incoming.computedDriverEarnings;
    } else {
      payValNum = 14.0;
    }
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
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 24),
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
                                  if (isOfficeDelivery) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.business_center_rounded, size: 10, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 3),
                                          Text(
                                            'OFFICE',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF1D4ED8),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Provider.of<DeliveryLanguageProvider>(context, listen: false).text(
                                        en: 'GUARANTEED EARNINGS',
                                        ta: 'உறுதிசெய்யப்பட்ட வருமானம்',
                                        tanglish: 'GUARANTEED EARNINGS',
                                      ),
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF818CF8),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹$payValStr',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF34D399),
                                        fontSize: isCompact ? 28 : 34,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(icons.Iconsax.routing_copy, color: Color(0xFFFDE047), size: 14),
                                        const SizedBox(width: 5),
                                        Text(
                                          distValStr,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Trip Distance',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 8.5,
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
                              setState(() {
                                _showAssignmentOverlay = false;
                                _overlayAssignment = null;
                                if (orderId.isNotEmpty) {
                                  _declinedOrderIdsThisSession.add(orderId);
                                }
                              });
                              provider.stopAlarmSound();
                              if (orderId.isNotEmpty) {
                                await provider.declineAssignment(orderId);
                              }
                              provider.clearPendingAssignment();
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                Provider.of<DeliveryLanguageProvider>(context, listen: false).text(
                                  en: 'DECLINE',
                                  ta: 'நிராகரி',
                                  tanglish: 'DECLINE',
                                ),
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
                                setState(() {
                                  _showAssignmentOverlay = false;
                                  _overlayAssignment = null;
                                });
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
                                      Provider.of<DeliveryLanguageProvider>(context, listen: false).text(
                                        en: 'ACCEPT ORDER',
                                        ta: 'ஏற்கவும்',
                                        tanglish: 'ACCEPT ORDER',
                                      ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.tr('good_morning');
    if (hour < 17) return context.tr('good_afternoon');
    return context.tr('good_evening');
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
    String selfieUrl = (selfieDoc is Map ? selfieDoc['front'] ?? '' : '').toString().trim();
    if (selfieUrl.isEmpty) {
      selfieUrl = provider.cachedProfilePhoto.trim();
    }
    final bool hasSelfie = selfieUrl.isNotEmpty;
    final double? backendRating = provider.realDriverRating;
    final int ratingCount = provider.realRatingCount;
    final String ratingStr = (backendRating != null && backendRating > 0 && ratingCount > 0)
        ? backendRating.toStringAsFixed(1)
        : (ratingCount > 0 ? (backendRating?.toStringAsFixed(1) ?? '0.0') : '0.0');

    String resolveUrl(String path) {
      if (path.startsWith('http://') || path.startsWith('https://')) return path;
      final base = DeliveryAuthService.baseUrl.replaceAll('/api/v1', '');
      if (path.startsWith('/')) return '$base$path';
      return '$base/$path';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderProfileScreen())),
            child: Row(
              children: [
                Hero(
                  tag: 'profile_pic',
                  child: Stack(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: isOnline ? AppTheme.accentGreen : AppTheme.slate300,
                            width: 2.5,
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: ClipOval(
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: hasSelfie
                                ? Image.network(
                                    resolveUrl(selfieUrl),
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return _buildAvatarFallback(isVerified);
                                    },
                                    errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(isVerified),
                                  )
                                : _buildAvatarFallback(isVerified),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isOnline ? AppTheme.accentGreen : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${_getGreeting(context)},',
                            style: GoogleFonts.outfit(
                              color: AppTheme.lightText,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(_getGreetingIcon(), style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _driverName.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: AppTheme.darkText,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(icons.Iconsax.verify_copy, color: AppTheme.accentGreen, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Online / Offline Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isOnline ? AppTheme.accentGreen : const Color(0xFF94A3B8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isOnline ? 'ONLINE' : 'OFFLINE',
                                  style: GoogleFonts.outfit(
                                    color: isOnline ? const Color(0xFF065F46) : const Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Rating Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 3),
                                Text(
                                  ratingStr,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF92400E),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
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
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RiderNotificationsScreen()),
            );
          },
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: provider.unreadNotificationsCount > 0
                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: AppTheme.softShadow,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(icons.Iconsax.notification_copy, color: AppTheme.darkText, size: 21),
                if (provider.unreadNotificationsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        provider.unreadNotificationsCount > 9 ? '9+' : '${provider.unreadNotificationsCount}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarFallback(bool isVerified) {
    return Container(
      width: 52,
      height: 52,
      color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
      alignment: Alignment.center,
      child: Text(
        _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'P',
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: isVerified ? const Color(0xFF166534) : AppTheme.primaryOrange,
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
            if (mounted) {
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
    );
  }

  Widget _buildPrimeEarningsCard() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        final double pendingEarnings = provider.pendingPayoutEarnings;
        final double settledEarnings = provider.settledPayoutEarnings;
        final int pendingCount = provider.pendingSettlementOrders.length;

        // When all earnings are settled by admin, pending payout drops to 0.00!
        final double displayAmount = pendingEarnings;
        final String formattedEarnings = displayAmount.toStringAsFixed(2);
        final parts = formattedEarnings.split('.');
        final mainAmount = parts[0];
        final decimalAmount = parts.length > 1 ? '.${parts[1]}' : '.00';

        final bool isFullySettled = (pendingEarnings == 0 && settledEarnings > 0);
        final bool hasPending = pendingEarnings > 0;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isFullySettled
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : (hasPending ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                width: 1.5,
              ),
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
                      color: (isFullySettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
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
                              Icon(
                                isFullySettled ? icons.Iconsax.wallet_check_copy : icons.Iconsax.wallet_money_copy,
                                color: isFullySettled ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('pending_payout'),
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
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isFullySettled
                                ? const Color(0xFF065F46).withValues(alpha: 0.4)
                                : (hasPending
                                    ? const Color(0xFF78350F).withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFullySettled
                                  ? const Color(0xFF34D399).withValues(alpha: 0.4)
                                  : (hasPending
                                      ? const Color(0xFFFBBF24).withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.15)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFullySettled ? Icons.check_circle_rounded : (hasPending ? Icons.hourglass_top_rounded : Icons.info_outline_rounded),
                                color: isFullySettled ? const Color(0xFF34D399) : (hasPending ? const Color(0xFFFBBF24) : Colors.white70),
                                size: 12,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isFullySettled ? 'ALL SETTLED' : (hasPending ? '$pendingCount PENDING' : 'NO DUES'),
                                style: GoogleFonts.outfit(
                                  color: isFullySettled ? const Color(0xFF34D399) : (hasPending ? const Color(0xFFFBBF24) : Colors.white70),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹',
                          style: GoogleFonts.outfit(
                            color: isFullySettled ? const Color(0xFF34D399) : (hasPending ? const Color(0xFFFBBF24) : Colors.white70),
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
                    const SizedBox(height: 6),
                    Text(
                      isFullySettled
                          ? '🎉 All delivery earnings (₹${settledEarnings.toStringAsFixed(0)}) settled by Admin to your UPI/Bank!'
                          : (hasPending
                              ? '₹${pendingEarnings.toStringAsFixed(0)} awaiting payout • ₹${settledEarnings.toStringAsFixed(0)} already settled'
                              : 'Complete deliveries to earn verified payouts'),
                      style: GoogleFonts.outfit(
                        color: isFullySettled ? const Color(0xFFA7F3D0) : (hasPending ? const Color(0xFFFDE68A) : Colors.white60),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
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
                            decoration: BoxDecoration(
                              color: isFullySettled ? const Color(0xFF065F46) : const Color(0xFF78350F),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFullySettled ? icons.Iconsax.tick_circle_copy : icons.Iconsax.timer_1_copy,
                              color: isFullySettled ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Settled: ₹${settledEarnings.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF34D399),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('view_details'),
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 10.5,
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
    );
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
    );
  }

  Widget _buildPrimeMetricGrid() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        final allDelivered = provider.orderHistory.where((o) => o.status == DeliveryStatus.delivered).toList();
        
        final ratedOrders = allDelivered.where((o) => o.customerRating != null && o.customerRating! > 0).toList();
        final double? backendRating = provider.realDriverRating;
        final int ratingCount = provider.realRatingCount > 0 ? provider.realRatingCount : ratedOrders.length;
        
        final String realRating = (ratingCount > 0 && backendRating != null && backendRating > 0)
            ? backendRating.toStringAsFixed(1)
            : (ratedOrders.isNotEmpty
                ? (ratedOrders.map((o) => o.customerRating!).reduce((a, b) => a + b) / ratedOrders.length).toStringAsFixed(1)
                : (ratingCount > 0 && backendRating != null ? backendRating.toStringAsFixed(1) : '0.0'));

        final String ratingSublabel = ratingCount > 0 
            ? '$ratingCount Customer Ratings'
            : (allDelivered.isEmpty ? 'New Rider (0.0★)' : '0 Customer Ratings');

        final now = DateTime.now();
        final todayDelivered = allDelivered.where((o) {
          final dt = o.timestamp.toLocal();
          return dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day;
        }).toList();

        final String orderCountDisplay = todayDelivered.isNotEmpty 
            ? '${todayDelivered.length}'
            : (allDelivered.isNotEmpty ? '${allDelivered.length}' : '0');

        final String orderSublabel = todayDelivered.isNotEmpty
            ? '${context.tr('completed_today')} (${allDelivered.length} Total)'
            : (allDelivered.isNotEmpty ? 'Total Completed Orders' : context.tr('completed_today'));

        return Row(
          children: [
            Expanded(
              child: _metricTile(
                icon: icons.Iconsax.box_copy,
                label: context.tr('orders'),
                sublabel: orderSublabel,
                value: orderCountDisplay,
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
                label: context.tr('rating'),
                sublabel: ratingSublabel,
                value: '$realRating★',
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderRatingsScreen())),
              ),
            ),
          ],
        );
      },
    );
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
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
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
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 12),
              ],
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionQueueSection() {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, child) {
        if (!provider.isOnline && provider.incomingRequests.isEmpty && provider.activeOrders.isEmpty) {
          return _buildOfflinePlaceholder();
        }

        final active = provider.activeOrders;
        final incoming = provider.incomingRequests;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ACTIVE MISSIONS ─────────────────────────────────────────────
            if (active.isNotEmpty) ...[
              if (active.length >= 2)
                _buildBatchActiveMissionsSection(active)
              else ...[
                Text(context.tr('active_missions'), style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 20),
                ...active.map((order) => _buildActiveMissionCard(order)),
              ],
              const SizedBox(height: 32),
            ],

            // ── INCOMING JOBS ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('available_jobs'), style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                if (incoming.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      incoming.length >= 2 ? '${incoming.length} BATCH ASSIGNED' : '${incoming.length} NEARBY',
                      style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            if (incoming.isEmpty)
              _buildSearchingState()
            else
              Column(children: incoming.map((order) => _buildPrimeJobCard(order)).toList()),
          ],
        );
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
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
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
            context.tr('you_are_offline'),
            style: GoogleFonts.outfit(
              color: AppTheme.darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('offline_prompt'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.mediumText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () async {
                final provider = context.read<DeliveryProvider>();
                final result = await provider.updateOnlineStatus(true);
                if (result['success'] == true) {
                  VoiceDispatchService.systemOnline();
                }
              },
              icon: const Icon(Icons.bolt_rounded, size: 22, color: Colors.white),
              label: Text(
                context.tr('go_online_now'),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
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
            context.tr('scanning_missions'),
            style: GoogleFonts.outfit(
              color: AppTheme.darkText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('stay_online_desc'),
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E7FF)),
                ),
                child: const Icon(icons.Iconsax.box_copy, color: AppTheme.primaryOrange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: AppTheme.darkText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (order.displayId.isNotEmpty)
                          Text(
                            'ORDER #${order.displayId} • ',
                            style: GoogleFonts.outfit(
                              color: AppTheme.mediumText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: order.paymentMethod == 'COD' ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: order.paymentMethod == 'COD' ? const Color(0xFFFFEDD5) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Text(
                            order.paymentMethod == 'COD' ? 'COD' : 'ONLINE PAID',
                            style: GoogleFonts.outfit(
                              color: order.paymentMethod == 'COD' ? const Color(0xFFEA580C) : const Color(0xFF059669),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (order.isOfficeDelivery) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_center_rounded, size: 10, color: Color(0xFF2563EB)),
                                const SizedBox(width: 3),
                                Text(
                                  'OFFICE',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF1D4ED8),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
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
          const SizedBox(height: 14),
          // 🟢 KM DISTANCE & PAYOUT BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: AppTheme.accentGreen, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR EARNING',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF059669),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          earningsStr,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(icons.Iconsax.routing_copy, color: AppTheme.primaryOrange, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        distStr,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Items preview
          if (order.items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text(
                order.items.take(3).join(' • ') + (order.items.length > 3 ? ' +${order.items.length - 3} more' : ''),
                style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 11.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  VoiceDispatchService.missionAccepted();
                  final ok = await provider.acceptAssignment(order.id);
                  if (ok && mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: order.id)));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('ACCEPT ORDER', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── BATCH ACTIVE MISSIONS SECTION (2+ ACTIVE DELIVERIES) ──────────────────
  Widget _buildBatchActiveMissionsSection(List<DeliveryOrder> active) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);

    double totalEarnings = 0;
    int totalItems = 0;
    for (var o in active) {
      totalEarnings += o.computedDriverEarnings > 0 ? o.computedDriverEarnings : 14.0;
      totalItems += o.items.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master Batch Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                      const SizedBox(width: 8),
                      Text(
                        lang.text(
                          en: 'BATCH TRIP IN PROGRESS',
                          ta: 'தொகுப்பு டெலிவரி செயலில் உள்ளது',
                          tanglish: 'BATCH TRIP IN PROGRESS',
                        ),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF34D399),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${active.length} ${lang.text(en: 'ORDERS', ta: 'ஆர்டர்கள்', tanglish: 'ORDERS')}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFF97316),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Trip Metric Highlights
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.text(
                          en: 'Combined Payout',
                          ta: 'மொத்த வருமானம்',
                          tanglish: 'Combined Payout',
                        ),
                        style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '₹${totalEarnings.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lang.text(
                          en: 'Total Cargo',
                          ta: 'மொத்த பொருட்கள்',
                          tanglish: 'Total Items',
                        ),
                        style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$totalItems ${lang.text(en: 'Items', ta: 'பொருட்கள்', tanglish: 'Items')}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFDE047),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Visual Step Sequence ("வகுத்த பாதை")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRouteNode('1', active[0].storeName, true),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 14),
                    _buildRouteNode('2', active.length > 1 ? active[1].storeName : 'Stop 2', false),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 14),
                    _buildRouteNode('3', active[0].customerName.isNotEmpty ? active[0].customerName : 'Cust 1', false),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 14),
                    _buildRouteNode('4', active.length > 1 && active[1].customerName.isNotEmpty ? active[1].customerName : 'Cust 2', false),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Distinct Cards for Mission 1 and Mission 2 ("வகுத்தல்")
        ...active.asMap().entries.map((entry) {
          final idx = entry.key;
          final order = entry.value;
          return _buildNumberedActiveMissionCard(order, idx + 1, active.length);
        }),
      ],
    );
  }

  Widget _buildRouteNode(String step, String label, bool isCurrent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isCurrent ? const Color(0xFFF97316) : Colors.white12,
            shape: BoxShape.circle,
            border: Border.all(color: isCurrent ? Colors.white : Colors.white24, width: 1.5),
          ),
          child: Center(
            child: Text(
              step,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isCurrent ? const Color(0xFFFDE047) : Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberedActiveMissionCard(DeliveryOrder order, int missionNumber, int totalMissions) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);
    final String rawStatus = order.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);
    final isFirst = missionNumber == 1;
    final accentColor = isFirst ? const Color(0xFFF97316) : const Color(0xFF3B82F6);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Mission Number Tag + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${lang.text(en: 'MISSION', ta: 'ஆர்டர்', tanglish: 'MISSION')} $missionNumber / $totalMissions',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (order.displayId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '#${order.displayId}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: GoogleFonts.outfit(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Store Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icons.Iconsax.shop_copy, color: accentColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.storeName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: AppTheme.darkText,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (order.storeAddress.isNotEmpty)
                        Text(
                          order.storeAddress,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName.isNotEmpty ? order.customerName : 'Customer',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E293B),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        order.customerAddress.isNotEmpty ? order.customerAddress : 'Delivery Address',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),

            // Bottom Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(icons.Iconsax.box_copy, color: AppTheme.mediumText, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${order.items.length} ${lang.text(en: 'ITEMS', ta: 'பொருட்கள்', tanglish: 'ITEMS')}',
                      style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${lang.text(en: 'VIEW ORDER', ta: 'ஆர்டரை பார்க்க', tanglish: 'VIEW ORDER')} $missionNumber',
                        style: GoogleFonts.outfit(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: accentColor, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── ACTIVE MISSION CARD (with live status badge) ──────────────────────────
  Widget _buildActiveMissionCard(order) {
    final String rawStatus = order.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: order.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryOrange.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Active Mission tag + Live Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms, begin: const Offset(0.7, 0.7), end: const Offset(1.3, 1.3)),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE MISSION',
                      style: GoogleFonts.outfit(
                        color: AppTheme.primaryOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order.isOfficeDelivery) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business_center_rounded, size: 11, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              'OFFICE',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1D4ED8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // LIVE STATUS BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: GoogleFonts.outfit(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Store Row with full card width
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(icons.Iconsax.shop_copy, color: AppTheme.primaryOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.storeName.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: AppTheme.darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            // Bottom Row: Items count + View Details button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(icons.Iconsax.box_copy, color: AppTheme.mediumText, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${order.items.length} ITEMS',
                      style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VIEW DETAILS',
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryOrange,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryOrange, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyLiveOrderBar(order) {
    final String rawStatus = order.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.3), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x180F172A), blurRadius: 20, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x080F172A), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.primaryOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(icons.Iconsax.routing_copy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACTIVE MISSION',
                      style: GoogleFonts.outfit(
                          color: AppTheme.primaryOrange,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 1),
                  Text(order.storeName.toUpperCase(),
                      style: GoogleFonts.outfit(
                          color: AppTheme.darkText,
                          fontSize: 13,
                          fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(statusLabel,
                            style: GoogleFonts.outfit(
                                color: statusColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DeliveryOrderDetailScreen(orderId: order.id))),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('VIEW →',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchStickyLiveOrderBar(List<DeliveryOrder> activeOrders) {
    final lang = Provider.of<DeliveryLanguageProvider>(context);
    final clampedIndex = _selectedStickyBatchTab.clamp(0, activeOrders.length - 1);
    final currentOrder = activeOrders[clampedIndex];
    final String rawStatus = currentOrder.rawStatus ?? '';
    final statusLabel = _getLiveStatusLabel(rawStatus);
    final statusColor = _getLiveStatusColor(rawStatus);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.4), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x180F172A), blurRadius: 20, offset: Offset(0, 8)),
          BoxShadow(color: Color(0x080F172A), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Selector Row: Switch between Order 1 and Order 2
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Colors.orange.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEA580C),
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                    const SizedBox(width: 6),
                    Text(
                      lang.text(
                        en: 'BATCH TRIP (2 ORDERS)',
                        ta: 'தொகுப்பு டெலிவரி (2 ஆர்டர்கள்)',
                        tanglish: 'BATCH TRIP (2 ORDERS)',
                      ),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFC2410C),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                // Tab switcher pills
                Row(
                  children: activeOrders.asMap().entries.map((e) {
                    final idx = e.key;
                    final isSelected = idx == clampedIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedStickyBatchTab = idx),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEA580C) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? const Color(0xFFEA580C) : Colors.orange.shade200),
                        ),
                        child: Text(
                          '#${idx + 1}',
                          style: GoogleFonts.outfit(
                            color: isSelected ? Colors.white : const Color(0xFFC2410C),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Main Row: Order Info & View Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(icons.Iconsax.routing_copy, color: Color(0xFFEA580C), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentOrder.storeName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: AppTheme.darkText,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.outfit(
                                color: statusColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeliveryOrderDetailScreen(orderId: currentOrder.id),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${lang.text(en: 'VIEW', ta: 'பார்', tanglish: 'VIEW')} #${clampedIndex + 1}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                      Text(context.tr('go_offline_q'), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 20)),
                    ]),
                    content: Text(
                      context.tr('go_offline_desc'),
                      style: GoogleFonts.outfit(color: AppTheme.mediumText, fontSize: 14, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(context.tr('cancel'), style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.bold)),
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
                        child: Text(context.tr('go_offline'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                          : const [Color(0xFFEA580C), Color(0xFFF97316)],
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
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('online_ready'),
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
                                context.tr('swipe_to_go_online'),
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
                          color: (widget.isOnline ? const Color(0xFF059669) : const Color(0xFFEA580C)).withValues(alpha: 0.25),
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
                        color: widget.isOnline ? const Color(0xFF10B981) : const Color(0xFFEA580C),
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
