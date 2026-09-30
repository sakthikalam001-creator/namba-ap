import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../rider_permissions_wizard_screen.dart';

class RiderSplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const RiderSplashScreen({super.key, required this.nextScreen});

  @override
  State<RiderSplashScreen> createState() => _RiderSplashScreenState();
}

class _RiderSplashScreenState extends State<RiderSplashScreen> {
  DateTime? _startTime;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBootSequence();
    });
  }

  Future<void> _startBootSequence() async {
    // 1. Check if permission wizard is needed
    bool shouldShowWizard = false;
    try {
      shouldShowWizard = await RiderPermissionsWizardScreen.shouldShowWizard();
    } catch (e) {
      debugPrint('[Splash] Error checking wizard: $e');
    }

    // 2. Minimum display duration for a smooth, premium feel (1.6s)
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
      if (elapsed < 1600) {
        await Future.delayed(Duration(milliseconds: 1600 - elapsed));
      }
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    final targetScreen = shouldShowWizard
        ? RiderPermissionsWizardScreen(nextScreen: widget.nextScreen)
        : widget.nextScreen;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double logoSize = (size.width * 0.42).clamp(130.0, 180.0);

    return Scaffold(
      backgroundColor: const Color(0xFF050811),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.15),
            radius: 0.95,
            colors: [
              Color(0xFF16253D), // Ambient dark navy matching the 3D icon
              Color(0xFF0C1424), // Mid deep navy
              Color(0xFF050811), // Bottom dark
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Center Brand Emblem & Title ──
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 3D Metallic NB Rider Squircle Logo
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(logoSize * 0.22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFA5A05).withValues(alpha: 0.28),
                          blurRadius: 40,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(logoSize * 0.22),
                      child: Image.asset(
                        'assets/images/rider_splash_logo.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 650.ms, curve: Curves.easeOut)
                      .scale(
                        begin: const Offset(0.78, 0.78),
                        end: const Offset(1.0, 1.0),
                        duration: 850.ms,
                        curve: Curves.easeOutBack,
                      ),

                  const SizedBox(height: 28),

                  // Brand Title
                  Text(
                    'NAMBA RIDER',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.2,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.25, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),

                  const SizedBox(height: 10),

                  // Portal Subtitle Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981), // Live Emerald
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DELIVERY PARTNER APP',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 350.ms, duration: 550.ms),

                  const SizedBox(height: 38),

                  // Progress Indicator
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFA5A05),
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms, duration: 500.ms),

                  const SizedBox(height: 14),

                  Text(
                    'STARTING DISPATCH ENGINE...',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 2.0,
                    ),
                  ).animate().fadeIn(delay: 550.ms, duration: 500.ms),
                ],
              ),

              const Spacer(flex: 3),

              // ── Bottom Tagline & Version Footer ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FAST • RELIABLE • EMPOWERING RIDERS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v2.4.0 • PRODUCTION BUILD',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.25),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
