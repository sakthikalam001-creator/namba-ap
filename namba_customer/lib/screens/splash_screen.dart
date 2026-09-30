import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:async';
import 'onboarding_screen.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'map_location_picker_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _entranceCtrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<double> _slideY;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseGlow;

  DateTime? _startTime;
  Timer? _autoCheckTimer;
  StreamSubscription<ServiceStatus>? _gpsStatusSub;
  bool _isDialogShowing = false;
  String _loadingStatus = 'Initializing secure connection...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now();

    // 1. Entrance animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scale = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutBack,
    );
    _fade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );
    _slideY = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: Curves.easeOutCubic,
      ),
    );
    _entranceCtrl.forward();

    // 2. Ambient breathing pulse animation
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseGlow = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // 3. Status text cycle for executive polish
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _loadingStatus = 'Locating nearby partners...');
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _loadingStatus = 'Welcome to Namba...');
    });

    // 4. GPS hardware listener
    try {
      _gpsStatusSub = Geolocator.getServiceStatusStream().listen((status) {
        if (status == ServiceStatus.enabled) {
          _onServiceRestored();
        }
      });
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _checkPrerequisites();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatusOnResume();
    }
  }

  void _checkStatusOnResume() async {
    if (!_isDialogShowing) return;
    try {
      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (isGpsOn) {
        _onServiceRestored();
      }
    } catch (_) {}
  }

  void _onServiceRestored() {
    if (mounted && _isDialogShowing) {
      _autoCheckTimer?.cancel();
      Navigator.of(context, rootNavigator: true).pop();
      _isDialogShowing = false;
      _checkPrerequisites();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsStatusSub?.cancel();
    _autoCheckTimer?.cancel();
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPrerequisites() async {
    // 1. Check Internet
    bool isConnected = false;
    try {
      final resIp = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 3));
      if (resIp.isNotEmpty && resIp[0].rawAddress.isNotEmpty) {
        isConnected = true;
      }
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          isConnected = true;
        }
      } catch (_) {
        isConnected = true;
      }
    }

    if (!isConnected) {
      _showModernErrorDialog(
        title: 'No Internet Connection',
        message: 'Please turn on your Wi-Fi or Mobile Data to continue using Namba.',
        icon: Icons.wifi_off_rounded,
        isLocation: false,
      );
      return;
    }

    if (!mounted) return;

    // Wait for AuthProvider to finish loading SharedPreferences
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.initFuture != null) {
      await auth.initFuture;
    }

    if (!mounted) return;

    final bool hasSavedLocation = auth.hasConfirmedLocation;

    // 2. Check Location Service (Only block if brand new install without any saved address)
    bool isLocationOn = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!isLocationOn && !hasSavedLocation) {
      _showModernErrorDialog(
        title: 'Location Disabled',
        message: 'We need your GPS location to find the best food and delivery partners near you.',
        icon: Icons.location_off_rounded,
        isLocation: true,
      );
      return;
    }

    // 3. Request Permission
    if (!hasSavedLocation) {
      await _requestLocationPermissionOnStartup();
    } else {
      _requestLocationPermissionOnStartup();
    }

    // 4. Smooth minimum display duration (1300ms) for high-end cinematic feel
    if (_startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
      if (elapsed < 1300) {
        await Future.delayed(Duration(milliseconds: 1300 - elapsed));
      }
    }

    // 5. Proceed directly to target screen
    if (!mounted) return;
    final Widget targetScreen = !auth.isLoggedIn
        ? const OnboardingScreen()
        : (!auth.hasConfirmedLocation
            ? const MapLocationPickerScreen(isInitialSetup: true)
            : const HomeScreen());

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 550),
      ),
    );
  }

  void _showModernErrorDialog({
    required String title,
    required String message,
    required IconData icon,
    required bool isLocation,
  }) {
    if (!mounted || _isDialogShowing) return;
    _isDialogShowing = true;

    _autoCheckTimer?.cancel();
    _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) async {
      bool connected = false;
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) connected = true;
      } catch (_) {}
      bool locationOn = await Geolocator.isLocationServiceEnabled();

      bool isResolved = isLocation ? locationOn : connected;

      if (isResolved) {
        timer.cancel();
        if (mounted && _isDialogShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          _isDialogShowing = false;
          _checkPrerequisites();
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogCtx) {
        final screenW = MediaQuery.of(dialogCtx).size.width;
        final screenH = MediaQuery.of(dialogCtx).size.height;
        final dialogMaxW = (screenW * 0.88).clamp(280.0, 390.0);
        final isSmall = screenH < 650;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: dialogMaxW),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 20 : 28,
                vertical: isSmall ? 22 : 30,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isSmall ? 64 : 76,
                      height: isSmall ? 64 : 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: isSmall ? 30 : 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 16 : 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: isSmall ? 19 : 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isSmall ? 8 : 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: isSmall ? 13.5 : 14.5,
                        color: const Color(0xFF94A3B8),
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isSmall ? 20 : 28),
                    if (isLocation)
                      SizedBox(
                        width: double.infinity,
                        height: isSmall ? 48 : 52,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                if (Platform.isAndroid) {
                                  const platform = MethodChannel('com.namaba.namaba_customer/settings');
                                  await platform.invokeMethod('openLocationSettings');
                                  return;
                                }
                                await Geolocator.openLocationSettings();
                              } catch (_) {
                                try {
                                  await Geolocator.openLocationSettings();
                                } catch (_) {
                                  try {
                                    await AppSettings.openAppSettings(
                                        type: AppSettingsType.location);
                                  } catch (_) {}
                                }
                              }
                            },
                            child: Text(
                              'Open Settings',
                              style: GoogleFonts.outfit(
                                fontSize: isSmall ? 15 : 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF818CF8)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Waiting for connection...',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
        );
      },
    ).then((_) {
      _isDialogShowing = false;
      _autoCheckTimer?.cancel();
    });
  }

  Future<void> _requestLocationPermissionOnStartup() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double maxAllowedLogo = size.height * 0.28;
    final double idealLogo = size.width * 0.52;
    final double logoSize = idealLogo > maxAllowedLogo
        ? maxAllowedLogo
        : (idealLogo > 220 ? 220 : (idealLogo < 150 ? 150 : idealLogo));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        children: [
          // ── 1. Luxury Midnight Mesh Background ──────────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0E1A), // Deep Obsidian
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E1B4B), // Midnight Indigo
                  Color(0xFF0A0E1A),
                ],
                stops: [0.0, 0.35, 0.75, 1.0],
              ),
            ),
          ),

          // ── 2. Animated Ambient Glowing Orbs ────────────────────────────────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return Stack(
                children: [
                  // Upper Indigo Ambient Glow
                  Positioned(
                    top: size.height * 0.18,
                    left: size.width * 0.5 - 140,
                    child: Container(
                      width: 280 * _pulseGlow.value,
                      height: 280 * _pulseGlow.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF4F46E5).withValues(alpha: 0.22),
                            const Color(0xFF4F46E5).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Lower Sunset Orange Warmth
                  Positioned(
                    bottom: size.height * 0.22,
                    left: size.width * 0.5 - 120,
                    child: Container(
                      width: 240 * (2.0 - _pulseGlow.value),
                      height: 240 * (2.0 - _pulseGlow.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF6D00).withValues(alpha: 0.16),
                            const Color(0xFFFF6D00).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── 3. Foreground Brand & Experience ───────────────────────────────
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Center Animated Brand Showcase
                  AnimatedBuilder(
                    animation: _entranceCtrl,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideY.value),
                        child: FadeTransition(
                          opacity: _fade,
                          child: ScaleTransition(
                            scale: _scale,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ultra-Premium Glassmorphic Logo Shield
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(logoSize * 0.26),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1E293B).withValues(alpha: 0.85),
                                const Color(0xFF0F172A).withValues(alpha: 0.95),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6D00).withValues(alpha: 0.28),
                                blurRadius: 42,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                blurRadius: 36,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(logoSize * 0.12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(logoSize * 0.18),
                            child: Image.asset(
                              'assets/images/splash_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFFF6D00),
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        // Title with luxury tracking & glow
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'NAMBA',
                              style: GoogleFonts.outfit(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFF6D00).withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Executive Tagline Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF10B981),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'HYPERLOCAL • INSTANT • FRESH',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE2E8F0),
                                  letterSpacing: 2.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 38),

                        // Sleek Linear Shimmer / Animated Loader
                        SizedBox(
                          width: 130,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              minHeight: 3.5,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6D00)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Micro status label
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _loadingStatus,
                            key: ValueKey<String>(_loadingStatus),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Bottom Brand Trust Footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                size: 13,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '100% SECURE & HYPERLOCAL ECOSYSTEM',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'v1.0.0 • Made with ❤️ for Tamil Nadu',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.4),
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
          ),
        ],
      ),
    );
  }
}
