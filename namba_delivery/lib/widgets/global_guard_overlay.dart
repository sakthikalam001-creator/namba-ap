import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/delivery_provider.dart';
import '../theme/app_theme.dart';

class GlobalConnectivityAndGpsGuard extends StatefulWidget {
  final Widget child;

  const GlobalConnectivityAndGpsGuard({super.key, required this.child});

  @override
  State<GlobalConnectivityAndGpsGuard> createState() => _GlobalConnectivityAndGpsGuardState();
}

class _GlobalConnectivityAndGpsGuardState extends State<GlobalConnectivityAndGpsGuard> with WidgetsBindingObserver {
  bool _isRechecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recheckStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckStatus();
    }
  }

  Future<void> _recheckStatus() async {
    if (_isRechecking) return;
    setState(() => _isRechecking = true);
    try {
      if (mounted) {
        final provider = context.read<DeliveryProvider>();
        await provider.checkLocationService();
        await provider.checkNetworkConnectivity();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _isRechecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryProvider>(
      builder: (context, provider, _) {
        final bool isGpsOff = !provider.isLocationServiceEnabled;
        final bool isNetOff = !provider.isNetworkConnected;

        return Stack(
          children: [
            widget.child,
            if (isGpsOff || isNetOff)
              _buildModernLuxuryModal(context, provider, isGpsOff, isNetOff),
          ],
        );
      },
    );
  }

  Widget _buildModernLuxuryModal(BuildContext context, DeliveryProvider provider, bool isGpsOff, bool isNetOff) {
    final bool isBothOff = isGpsOff && isNetOff;
    final primaryColor = isBothOff || isGpsOff ? const Color(0xFFEF4444) : const Color(0xFF4F46E5);
    final accentGlow = isBothOff || isGpsOff ? const Color(0x33EF4444) : const Color(0x334F46E5);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Ultra-Premium Deep Frosted Glass Backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                color: const Color(0xFF0B0F19).withValues(alpha: 0.82),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: accentGlow,
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Stack(
                    children: [
                      // Top subtle decorative gradient banner
                      Positioned(
                        top: 0, left: 0, right: 0,
                        height: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isBothOff
                                  ? [const Color(0xFFEF4444), const Color(0xFFF59E0B), const Color(0xFF4F46E5)]
                                  : (isGpsOff
                                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                      : [const Color(0xFF6366F1), const Color(0xFF4F46E5)]),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Multi-Layer Pulsing Radar Beacon ─────────────────
                            _buildPulsingBeacon(isBothOff, isGpsOff, primaryColor),

                            const SizedBox(height: 24),

                            // ── Live Status Indicator Pill ───────────────────────
                            _buildLiveStatusPill(isBothOff, isGpsOff),

                            const SizedBox(height: 18),

                            // ── Main Header Title ───────────────────────────────
                            Text(
                              isBothOff
                                  ? 'GPS & Internet Required'
                                  : (isGpsOff ? 'Location (GPS) is OFF' : 'No Internet Connection'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF0F172A),
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ── Natural Conversational Tamil & English Subtitle ──
                            Text(
                              isBothOff
                                  ? 'ரைடர் ஆப் செயல்பட GPS மற்றும் Internet (Data/Wi-Fi) இரண்டும் ON-ல் இருக்க வேண்டும்.\n\nPlease turn on both Mobile Data and GPS Location.'
                                  : (isGpsOff
                                      ? 'புதிய ஆர்டர்களைப் பெற உங்கள் மொபைலில் GPS Location கட்டாயம் ஆன்-ல் இருக்க வேண்டும்.\n\nPlease enable device location services.'
                                      : 'ஆர்டர்களை உடனுக்குடன் பெற Mobile Data அல்லது Wi-Fi ஆன் செய்யவும்.\n\nPlease check your internet connection.'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Structured Requirement Mini Cards ────────────────
                            if (isGpsOff)
                              _buildRequirementRow(
                                icon: Icons.location_on_rounded,
                                title: 'Device GPS Location',
                                subtitle: 'Required for real-time customer dispatch',
                                isAlert: true,
                              ),
                            if (isGpsOff && isNetOff)
                              const SizedBox(height: 10),
                            if (isNetOff)
                              _buildRequirementRow(
                                icon: Icons.wifi_rounded,
                                title: 'Internet Connection',
                                subtitle: 'Required for live order synchronization',
                                isAlert: true,
                              ),

                            const SizedBox(height: 28),

                            // ── Primary Action Buttons ───────────────────────────
                            if (isGpsOff) ...[
                              _buildPrimaryGradientButton(
                                label: 'TURN ON GPS LOCATION',
                                sublabel: 'Open Phone Location Settings',
                                icon: Icons.my_location_rounded,
                                gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                                onTap: () async {
                                  await Geolocator.openLocationSettings();
                                  await _recheckStatus();
                                },
                              ),
                              const SizedBox(height: 12),
                            ],

                            if (isNetOff && !isGpsOff) ...[
                              _buildPrimaryGradientButton(
                                label: 'CHECK INTERNET CONNECTION',
                                sublabel: 'Tap to retry sync',
                                icon: Icons.refresh_rounded,
                                gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF4338CA)]),
                                onTap: () async {
                                  await _recheckStatus();
                                },
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ── Recheck Floating Glass Button ───────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _isRechecking ? null : _recheckStatus,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                ),
                                child: _isRechecking
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF4F46E5)),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF475569)),
                                          const SizedBox(width: 8),
                                          Text(
                                            'I HAVE TURNED IT ON • RECHECK',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF334155),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
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
    ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutCubic);
  }

  Widget _buildPulsingBeacon(bool isBothOff, bool isGpsOff, Color primaryColor) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow Wave
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.12),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(duration: 1200.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15)),

          // Mid Ring
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.2),
            ),
          ),

          // Inner Solid Icon Circle
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isBothOff || isGpsOff
                    ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                    : [const Color(0xFF6366F1), const Color(0xFF4338CA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isBothOff
                  ? Icons.portable_wifi_off_rounded
                  : (isGpsOff ? Icons.location_off_rounded : Icons.wifi_off_rounded),
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusPill(bool isBothOff, bool isGpsOff) {
    final bgColor = isBothOff || isGpsOff ? const Color(0xFFFEF2F2) : const Color(0xFFEEF2FF);
    final borderColor = isBothOff || isGpsOff ? const Color(0xFFFECACA) : const Color(0xFFC7D2FE);
    final dotColor = isBothOff || isGpsOff ? const Color(0xFFDC2626) : const Color(0xFF4F46E5);
    final textColor = isBothOff || isGpsOff ? const Color(0xFF991B1B) : const Color(0xFF3730A3);
    final label = isBothOff
        ? 'GPS & INTERNET REQUIRED'
        : (isGpsOff ? 'GPS INACTIVE • ACTION REQUIRED' : 'NO NETWORK • ACTION REQUIRED');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.4, 1.4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isAlert,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAlert ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF64748B), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
        ],
      ),
    );
  }

  Widget _buildPrimaryGradientButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        sublabel,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
