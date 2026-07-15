import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../services/delivery_auth_service.dart';
import '../dashboard/delivery_dashboard_screen.dart';
import 'delivery_login_screen.dart';

class DeliveryPendingApprovalScreen extends StatefulWidget {
  final String driverName;
  final String driverId;

  const DeliveryPendingApprovalScreen({
    super.key,
    required this.driverName,
    required this.driverId,
  });

  @override
  State<DeliveryPendingApprovalScreen> createState() => _DeliveryPendingApprovalScreenState();
}

class _DeliveryPendingApprovalScreenState extends State<DeliveryPendingApprovalScreen> with TickerProviderStateMixin {
  io.Socket? _socket;
  String _status = 'pending'; 
  String _statusMessage = '';
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _connectSocket();
  }

  void _connectSocket() {
    try {
      _socket = io.io(
        DeliveryAuthService.baseUrl.replaceAll('/api/v1', ''),
        io.OptionBuilder().setTransports(['websocket']).enableAutoConnect().build(),
      );

      _socket!.onConnect((_) {
        debugPrint('✅ Registration Screen: Socket connected');
        if (widget.driverId.isNotEmpty) {
          _socket!.emit('join_driver_room', {'driverId': widget.driverId});
        }
      });

      _socket!.on('driver_approval_update', (data) {
        if (!mounted) return;
        final newStatus = data['status'] ?? 'pending';
        final message = data['message'] ?? '';

        setState(() {
          _status = newStatus;
          _statusMessage = message;
        });

        if (newStatus == 'approved') {
          DeliveryAuthService.updateApprovalStatus('approved');
          _showApprovedDialog();
        } else if (newStatus == 'rejected') {
          DeliveryAuthService.updateApprovalStatus('rejected');
        }
      });
    } catch (e) {
      debugPrint('Socket error: $e');
    }
  }

  void _showApprovedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(icons.Iconsax.verify_copy, color: AppTheme.accentGreen, size: 48),
              ),
              const SizedBox(height: 24),
              Text('REGISTRATION APPROVED', style: GoogleFonts.outfit(
                color: AppTheme.darkText, fontSize: 20, fontWeight: FontWeight.w900,
              )),
              const SizedBox(height: 12),
              Text(
                'YOUR PARTNER APPLICATION HAS BEEN VERIFIED. YOU CAN NOW ACCESS THE DASHBOARD.',
                style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DeliveryDashboardScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Center(
                    child: Text('LOAD DASHBOARD', style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1,
                    )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socket?.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              _buildPrimeStatusContent(),
              const Spacer(),
              _buildPrimeBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimeStatusContent() {
    if (_status == 'approved') {
      return _buildApprovedState();
    } else if (_status == 'rejected') {
      return _buildRejectedState();
    }
    return _buildPendingState();
  }

  Widget _buildPendingState() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(220, 220),
                  painter: PrimeRadarPainter(progress: _radarController.value),
                );
              },
            ),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(icons.Iconsax.security_user_copy, color: AppTheme.primaryOrange, size: 32),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(duration: 2.seconds, begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
          ],
        ),
        const SizedBox(height: 48),
        Text('REGISTRATION PENDING', style: GoogleFonts.outfit(
          color: AppTheme.darkText, fontSize: 24, fontWeight: FontWeight.w900,
        )).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 12),
        Text(
          'WE ARE VERIFYING YOUR DOCUMENTS FOR ${widget.driverName.toUpperCase()}. THIS PROCESS USUALLY TAKES 24-48 HOURS.',
          style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, height: 1.6),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 60),
        _buildStatusNode('Application Submitted', true, isCurrent: true),
        _buildStatusConnector(true),
        _buildStatusNode('Document Verification', false, isCurrent: true),
        _buildStatusConnector(false),
        _buildStatusNode('Final Approval', false),
        _buildStatusConnector(false),
        _buildStatusNode('Partner Ready', false),
      ],
    );
  }

  Widget _buildApprovedState() {
    return Column(
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            color: AppTheme.accentGreen.withValues(alpha: 0.1),
          ),
          child: const Icon(icons.Iconsax.verify_copy, color: AppTheme.accentGreen, size: 64),
        ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 40),
        Text('ACCOUNT READY', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Text('YOUR PARTNER ACCOUNT IS NOW ACTIVE. START EARNING TODAY.', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 48),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryDashboardScreen())),
          child: Container(
            height: 60, width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen, 
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(
              child: Text('LOAD DASHBOARD', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedState() {
    return Column(
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            color: AppTheme.signalRed.withValues(alpha: 0.1),
          ),
          child: const Icon(icons.Iconsax.close_circle_copy, color: AppTheme.signalRed, size: 64),
        ).animate().shake(),
        const SizedBox(height: 40),
        Text('APPLICATION DECLINED', style: GoogleFonts.outfit(color: AppTheme.signalRed, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(
          _statusMessage.isNotEmpty ? _statusMessage : 'THERE WAS AN ISSUE VERIFYING YOUR DOCUMENTS. PLEASE CONTACT SUPPORT.',
          style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 12, fontWeight: FontWeight.w700, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        GestureDetector(
          onTap: () async {
            await DeliveryAuthService.logout();
            if (mounted) {
              Provider.of<DeliveryProvider>(context, listen: false).setAuthenticated(false);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()));
            }
          },
          child: Container(
            height: 56, padding: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: AppTheme.softShadow,
            ),
            child: Center(
              child: Text('RETRY APPLICATION', style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusNode(String label, bool isDone, {bool isCurrent = false}) {
    return Row(
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? AppTheme.accentGreen : (isCurrent ? Colors.white : AppTheme.lightBg),
            border: Border.all(
              color: isDone ? AppTheme.accentGreen : (isCurrent ? AppTheme.primaryOrange : AppTheme.lightBg),
              width: 2,
            ),
            boxShadow: isCurrent ? AppTheme.softShadow : null,
          ),
          child: isDone
              ? const Icon(icons.Iconsax.tick_circle_copy, color: Colors.white, size: 12)
              : (isCurrent
                  ? Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle)))
                      .animate(onPlay: (c) => c.repeat()).scale(duration: 1.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2))
                  : null),
        ),
        const SizedBox(width: 16),
        Text(label, style: GoogleFonts.outfit(
          color: isDone ? AppTheme.darkText : (isCurrent ? AppTheme.primaryOrange : AppTheme.lightText),
          fontSize: 13, fontWeight: FontWeight.w700,
        )),
      ],
    );
  }

  Widget _buildStatusConnector(bool active) {
    return Container(
      margin: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
      width: 2, height: 16,
      decoration: BoxDecoration(
        color: active ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.lightBg,
      ),
    );
  }

  Widget _buildPrimeBottomActions() {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            await DeliveryAuthService.logout();
            if (mounted) {
              Provider.of<DeliveryProvider>(context, listen: false).setAuthenticated(false);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()),
              );
            }
          },
          child: Text('EXIT PORTAL', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ),
      ],
    );
  }
}

class PrimeRadarPainter extends CustomPainter {
  final double progress;
  PrimeRadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    
    final paint = Paint()
      ..color = AppTheme.primaryOrange.withValues(alpha: (1.0 - progress) * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
        final currentProgress = (progress + (i / 3.0)) % 1.0;
        canvas.drawCircle(center, maxRadius * currentProgress, paint..color = AppTheme.primaryOrange.withValues(alpha: (1.0 - currentProgress) * 0.08));
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.transparent, AppTheme.primaryOrange.withValues(alpha: 0.15)],
        stops: const [0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * 2 * 3.14159);
    canvas.drawCircle(Offset.zero, maxRadius, sweepPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PrimeRadarPainter oldDelegate) => oldDelegate.progress != progress;
}
