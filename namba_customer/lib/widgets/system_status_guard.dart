import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';
import 'package:google_fonts/google_fonts.dart';

class SystemStatusGuard extends StatefulWidget {
  final Widget child;
  const SystemStatusGuard({super.key, required this.child});

  @override
  State<SystemStatusGuard> createState() => _SystemStatusGuardState();
}

class _SystemStatusGuardState extends State<SystemStatusGuard> with WidgetsBindingObserver {
  bool _hasInternet = true;
  bool _isGpsOn = true;
  bool _userDismissedWarning = false;
  int _consecutiveNetFailures = 0;

  Timer? _statusCheckTimer;
  StreamSubscription<ServiceStatus>? _gpsStreamSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initListeners();
  }

  void _initListeners() {
    // 1. Initial check after app finishes rendering
    Future.delayed(const Duration(milliseconds: 1500), _checkSystemStatus);

    // 2. Periodic check every 8 seconds (low overhead, no battery drain)
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _checkSystemStatus();
    });

    // 3. Listen to Geolocator service status stream
    try {
      _gpsStreamSub = Geolocator.getServiceStatusStream().listen((status) {
        final isEnabled = status == ServiceStatus.enabled;
        if (mounted && _isGpsOn != isEnabled) {
          setState(() {
            _isGpsOn = isEnabled;
            if (isEnabled) _userDismissedWarning = false;
          });
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _userDismissedWarning = false;
      _checkSystemStatus();
    }
  }

  Future<void> _checkSystemStatus() async {
    // Check Internet with multi-endpoint fallback (supports Wi-Fi & 4G/5G mobile data)
    bool netConnected = false;
    try {
      // 1. Fast raw IP lookup (no DNS latency on mobile data)
      final rawIp = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 3));
      if (rawIp.isNotEmpty && rawIp[0].rawAddress.isNotEmpty) {
        netConnected = true;
      }
    } catch (_) {
      // 2. Fallback to DNS lookup
      try {
        final lookup = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
        if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
          netConnected = true;
        }
      } catch (_) {
        netConnected = false;
      }
    }

    if (netConnected) {
      _consecutiveNetFailures = 0;
    } else {
      _consecutiveNetFailures++;
    }

    // Only flag internet down if failed 3 consecutive times (> 15 seconds)
    final bool effectiveNet = _consecutiveNetFailures < 3;

    // Check GPS
    bool gpsEnabled = true;
    try {
      gpsEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {}

    if (mounted) {
      if (_hasInternet != effectiveNet || _isGpsOn != gpsEnabled) {
        setState(() {
          _hasInternet = effectiveNet;
          _isGpsOn = gpsEnabled;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusCheckTimer?.cancel();
    _gpsStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showWarning = (!_hasInternet || !_isGpsOn) && !_userDismissedWarning;

    return Stack(
      children: [
        widget.child,
        if (showWarning)
          Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.65),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: !_hasInternet
                        ? _buildInternetOffCard()
                        : _buildGpsOffCard(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInternetOffCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Pulse Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Internet Connection',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'இணைய இணைப்பு இல்லை',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please turn on your Wi-Fi or Mobile Data to browse restaurants, view menus, and track your orders in real-time.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _checkSystemStatus();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'RETRY',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await AppSettings.openAppSettings(type: AppSettingsType.wireless);
                    } catch (_) {
                      try {
                        await AppSettings.openAppSettings(type: AppSettingsType.wifi);
                      } catch (_) {}
                    }
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: Text(
                    'TURN ON NET',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _userDismissedWarning = true;
              });
            },
            child: Text(
              'Continue to App anyway',
              style: GoogleFonts.outfit(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsOffCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Pulse Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A), width: 2),
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: Color(0xFFD97706),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'GPS Location Disabled',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ஜிபிஎஸ் இருப்பிடம் முடக்கப்பட்டுள்ளது',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We need your device GPS Location to discover nearby restaurants, calculate accurate delivery fees, and show live rider tracking.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Geolocator.openLocationSettings();
                } catch (_) {
                  try {
                    await AppSettings.openAppSettings(type: AppSettingsType.location);
                  } catch (_) {}
                }
              },
              icon: const Icon(Icons.location_on_rounded, size: 20),
              label: Text(
                'ENABLE GPS LOCATION',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _userDismissedWarning = true;
              });
            },
            child: Text(
              'Set Location Manually on Map',
              style: GoogleFonts.outfit(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
