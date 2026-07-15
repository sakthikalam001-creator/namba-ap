import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class SecureScanScreen extends StatefulWidget {
  final String orderId;
  const SecureScanScreen({super.key, required this.orderId});

  @override
  State<SecureScanScreen> createState() => _SecureScanScreenState();
}

class _SecureScanScreenState extends State<SecureScanScreen> with TickerProviderStateMixin {
  late AnimationController _scannerController;
  bool _isScanning = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    _scannerController.repeat();
    
    // Simulated scan sequence
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      _scannerController.stop();
      setState(() {
        _isScanning = false;
        _isComplete = true;
      });
      
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('SECURE VERIFICATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: AppTheme.darkText)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Scanning Interface
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCaptureFrame(),
                const SizedBox(height: 50),
                _buildInterfaceStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureFrame() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera View Container
        Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: AppTheme.cardShadow,
          ),
          child: _isComplete 
              ? Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 80).animate().scale(duration: 400.ms, curve: Curves.bounceOut)
              : Icon(icons.Iconsax.camera_copy, color: AppTheme.lightBg, size: 60),
        ),

        // Scanning Laser
        if (_isScanning)
          AnimatedBuilder(
            animation: _scannerController,
            builder: (context, child) {
              return Positioned(
                top: 280 * _scannerController.value,
                child: Container(
                  width: 280, height: 4,
                  decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.5), blurRadius: 15)],
                    gradient: LinearGradient(colors: [Colors.transparent, AppTheme.accentGreen, Colors.transparent]),
                  ),
                ),
              );
            },
          ),

        // Style Guides
        ...List.generate(4, (i) => Positioned(
          top: i < 2 ? -2 : null, bottom: i >= 2 ? -2 : null,
          left: i % 2 == 0 ? -2 : null, right: i % 2 != 0 ? -2 : null,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              border: Border(
                top: i < 2 ? const BorderSide(color: AppTheme.accentGreen, width: 4) : BorderSide.none,
                bottom: i >= 2 ? const BorderSide(color: AppTheme.accentGreen, width: 4) : BorderSide.none,
                left: i % 2 == 0 ? const BorderSide(color: AppTheme.accentGreen, width: 4) : BorderSide.none,
                right: i % 2 != 0 ? const BorderSide(color: AppTheme.accentGreen, width: 4) : BorderSide.none,
              ),
            ).copyWith(borderRadius: BorderRadius.circular(8)),
          ),
        )),
      ],
    );
  }

  Widget _buildInterfaceStatus() {
    return Column(
      children: [
        Text(
          _isComplete ? 'VERIFIED' : (_isScanning ? 'SCANNING SECURE TAG...' : 'ALIGN CARGO CODE'),
          style: GoogleFonts.outfit(color: _isComplete ? AppTheme.accentGreen : AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
        ).animate(target: _isScanning ? 1 : 0).shimmer(duration: 1.seconds),
        const SizedBox(height: 32),
        if (!_isComplete && !_isScanning)
          GestureDetector(
            onTap: _startScan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(icons.Iconsax.maximize_copy, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('INITIATE SCAN', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                ],
              ),
            ),
          ).animate().fadeIn().scale(),
      ],
    );
  }
}
