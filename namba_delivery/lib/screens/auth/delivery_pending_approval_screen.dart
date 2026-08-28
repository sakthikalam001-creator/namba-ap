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
import '../profile/document_status_screen.dart';
import '../docs/document_upload_screen.dart';
import '../docs/bank_details_screen.dart';
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
  bool _isRefreshing = false;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _connectSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStatus(silent: true);
    });
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
        context.read<DeliveryProvider>().fetchDocumentStatuses();
      });
    } catch (e) {
      debugPrint('Socket error: $e');
    }
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    if (!silent) setState(() => _isRefreshing = true);
    try {
      await context.read<DeliveryProvider>().fetchDocumentStatuses();
      final provider = context.read<DeliveryProvider>();
      if (mounted) {
        setState(() {
          _status = provider.approvalStatus;
          _statusMessage = provider.rejectionReason;
        });
      }
    } catch (_) {}
    if (mounted && !silent) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status refreshed from server', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFF4F46E5),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
    final provider = context.watch<DeliveryProvider>();
    if (provider.pendingAssignment != null || provider.approvalStatus == 'approved' || _status == 'approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DeliveryDashboardScreen()),
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('APPLICATION STATUS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: const Color(0xFF0F172A))),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))
                : const Icon(Icons.refresh_rounded, color: Color(0xFF4F46E5)),
            tooltip: 'Refresh Status',
            onPressed: _isRefreshing ? null : () => _refreshStatus(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B), size: 20),
            tooltip: 'Exit / Logout',
            onPressed: () async {
              await DeliveryAuthService.logout();
              if (mounted) {
                Provider.of<DeliveryProvider>(context, listen: false).setAuthenticated(false);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()));
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refreshStatus(),
          color: const Color(0xFF4F46E5),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _buildPrimeStatusContent(provider),
                const SizedBox(height: 32),
                _buildLiveDocumentChecklist(provider),
                const SizedBox(height: 32),
                _buildTimelineFlow(provider),
                const SizedBox(height: 36),
                _buildPrimaryActionButtons(provider),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimeStatusContent(DeliveryProvider provider) {
    if (_status == 'approved') {
      return _buildApprovedState();
    } else if (_status == 'rejected' || provider.approvalStatus == 'rejected') {
      return _buildRejectedState(provider);
    }
    return _buildPendingState(provider);
  }

  Widget _buildPendingState(DeliveryProvider provider) {
    final docs = provider.documents;
    final int uploadedCount = [
      docs['selfie'],
      docs['aadhar'] ?? docs['aadhaar'],
      docs['license'],
      docs['bankDetails'] ?? docs['bankStatement'],
    ].where((d) => d is Map && (d['front'] ?? '').toString().isNotEmpty || (d is Map && ((d['accountNumber'] ?? '').toString().isNotEmpty || (d['upiId'] ?? '').toString().isNotEmpty))).length;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(180, 180),
                  painter: PrimeRadarPainter(progress: _radarController.value),
                );
              },
            ),
            Container(
              width: 74, height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(icons.Iconsax.security_user_copy, color: AppTheme.primaryOrange, size: 30),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(duration: 2.seconds, begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(
                uploadedCount < 4 ? 'DOCUMENTS REQUIRED ($uploadedCount/4)' : 'UNDER ADMIN REVIEW',
                style: GoogleFonts.outfit(color: const Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Application Submitted',
          style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Partner: ${widget.driverName.toUpperCase()}',
          style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          uploadedCount < 4
              ? 'Please upload all 4 required documents (Selfie, Aadhaar, License, Bank/UPI) for Super Admin verification.'
              : 'All required documents submitted. Super Admin is reviewing your KYC paperwork.',
          style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showLockedAuditDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Access Locked',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All your required documents are submitted and under Super Admin KYC Audit.',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                'Document editing is locked while verification is in progress. If Admin requests any correction or unlocks re-upload, you will be able to edit them here.',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('UNDERSTOOD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveDocumentChecklist(DeliveryProvider provider) {
    final docs = provider.documents;

    final bool selfieDone = docs['selfie'] is Map && ((docs['selfie']['front'] ?? '').toString().isNotEmpty);
    final bool aadharDone = (docs['aadhar'] ?? docs['aadhaar']) is Map && (((docs['aadhar'] ?? docs['aadhaar'])['front'] ?? '').toString().isNotEmpty);
    final bool licenseDone = docs['license'] is Map && ((docs['license']['front'] ?? '').toString().isNotEmpty);
    final bool bankDone = (docs['bankDetails'] ?? docs['bankStatement']) is Map &&
        (((docs['bankDetails'] ?? docs['bankStatement'])['accountNumber'] ?? '').toString().isNotEmpty ||
            ((docs['bankDetails'] ?? docs['bankStatement'])['upiId'] ?? '').toString().isNotEmpty);
    final int uploadedCount = (selfieDone ? 1 : 0) + (aadharDone ? 1 : 0) + (licenseDone ? 1 : 0) + (bankDone ? 1 : 0);

    bool isDocRejected(String key) {
      final d = docs[key];
      if (d is! Map) return false;
      return (d['status'] ?? '').toString().toLowerCase() == 'rejected';
    }

    final bool hasRejections = isDocRejected('selfie') ||
        isDocRejected('aadhar') ||
        isDocRejected('aadhaar') ||
        isDocRejected('license') ||
        isDocRejected('bankDetails') ||
        isDocRejected('bankStatement') ||
        _status == 'rejected' ||
        provider.approvalStatus == 'rejected';

    final bool isUnderAudit = uploadedCount >= 4 && !hasRejections && _status != 'approved' && provider.approvalStatus != 'approved';

    Widget buildDocCheckItem(String title, IconData icon, dynamic docData, VoidCallback onTap, {bool isBank = false}) {
      final String st = (docData is Map ? docData['status'] ?? '' : '').toString().toLowerCase();
      final bool hasContent = docData is Map &&
          ((docData['front'] ?? '').toString().isNotEmpty ||
              (isBank && ((docData['accountNumber'] ?? '').toString().isNotEmpty || (docData['upiId'] ?? '').toString().isNotEmpty)));

      Color badgeColor = const Color(0xFFF59E0B);
      String badgeLabel = 'Missing';
      IconData badgeIcon = Icons.warning_amber_rounded;

      if (st == 'verified' || st == 'approved') {
        badgeColor = const Color(0xFF10B981);
        badgeLabel = 'Verified';
        badgeIcon = Icons.check_circle_rounded;
      } else if (st == 'rejected') {
        badgeColor = const Color(0xFFEF4444);
        badgeLabel = 'Action Needed';
        badgeIcon = Icons.cancel_rounded;
      } else if (hasContent || st == 'pending') {
        badgeColor = const Color(0xFF3B82F6);
        badgeLabel = 'Pending Review';
        badgeIcon = Icons.hourglass_top_rounded;
      }

      final bool isItemLocked = isUnderAudit && (st != 'rejected');

      return InkWell(
        onTap: () {
          if (isItemLocked) {
            _showLockedAuditDialog();
          } else {
            onTap();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isItemLocked ? const Color(0xFFE2E8F0) : (st == 'rejected' ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0))),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: badgeColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF1E293B))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 12),
                    const SizedBox(width: 4),
                    Text(badgeLabel, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isItemLocked ? Icons.lock_outline_rounded : Icons.arrow_forward_ios_rounded,
                size: isItemLocked ? 14 : 11,
                color: isItemLocked ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LIVE DOCUMENT STATUS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.6)),
              Text(
                isUnderAudit ? '🔒 Locked Under Audit' : (hasRejections ? '⚠️ Re-upload Unlocked' : 'Tap item to upload'),
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isUnderAudit ? const Color(0xFF64748B) : (hasRejections ? const Color(0xFFDC2626) : const Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          buildDocCheckItem(
            'Profile Selfie',
            Icons.camera_alt_rounded,
            docs['selfie'],
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentUploadScreen(docType: 'selfie', title: 'Profile Selfie'))),
          ),
          buildDocCheckItem(
            'Aadhaar Card',
            Icons.badge_rounded,
            docs['aadhar'] ?? docs['aadhaar'],
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentUploadScreen(docType: 'aadhar', title: 'Aadhar Card'))),
          ),
          buildDocCheckItem(
            'Driving License',
            Icons.drive_eta_rounded,
            docs['license'],
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentUploadScreen(docType: 'license', title: 'Driving License'))),
          ),
          buildDocCheckItem(
            'Bank & UPI Details',
            Icons.account_balance_rounded,
            docs['bankDetails'] ?? docs['bankStatement'],
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankDetailsScreen())),
            isBank: true,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedState() {
    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFDCFCE7),
          ),
          child: const Icon(Icons.verified_rounded, color: Color(0xFF166534), size: 56),
        ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text('ACCOUNT READY & VERIFIED', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Your partner account is active. You can now access your live dispatch dashboard.', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildRejectedState(DeliveryProvider provider) {
    final reason = _statusMessage.isNotEmpty ? _statusMessage : provider.rejectionReason;

    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFEF2F2),
          ),
          child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 56),
        ).animate().shake(),
        const SizedBox(height: 24),
        Text('CORRECTION REQUIRED', style: GoogleFonts.outfit(color: const Color(0xFFDC2626), fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Text(
            reason.isNotEmpty ? 'Admin Feedback: $reason' : 'One or more of your documents require re-upload or clarification.',
            style: GoogleFonts.outfit(color: const Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w700, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineFlow(DeliveryProvider provider) {
    final docs = provider.documents;
    final bool selfieDone = docs['selfie'] is Map && ((docs['selfie']['front'] ?? '').toString().isNotEmpty);
    final bool aadharDone = (docs['aadhar'] ?? docs['aadhaar']) is Map && (((docs['aadhar'] ?? docs['aadhaar'])['front'] ?? '').toString().isNotEmpty);
    final bool licenseDone = docs['license'] is Map && ((docs['license']['front'] ?? '').toString().isNotEmpty);
    final bool bankDone = (docs['bankDetails'] ?? docs['bankStatement']) is Map &&
        (((docs['bankDetails'] ?? docs['bankStatement'])['accountNumber'] ?? '').toString().isNotEmpty ||
            ((docs['bankDetails'] ?? docs['bankStatement'])['upiId'] ?? '').toString().isNotEmpty);

    final bool allDocsUploaded = selfieDone && aadharDone && licenseDone && bankDone;
    final bool isApproved = _status == 'approved' || provider.approvalStatus == 'approved';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPLICATION PROGRESS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.6)),
          const SizedBox(height: 18),
          _buildStatusNode('Account Registered', true),
          _buildStatusConnector(allDocsUploaded),
          _buildStatusNode('Documents Uploaded', allDocsUploaded, isCurrent: !allDocsUploaded),
          _buildStatusConnector(isApproved),
          _buildStatusNode('Admin KYC Audit', isApproved, isCurrent: allDocsUploaded && !isApproved),
          _buildStatusConnector(isApproved),
          _buildStatusNode('Ready for Orders', isApproved),
        ],
      ),
    );
  }

  Widget _buildStatusNode(String label, bool isDone, {bool isCurrent = false}) {
    return Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? const Color(0xFF10B981) : (isCurrent ? Colors.white : const Color(0xFFF1F5F9)),
            border: Border.all(
              color: isDone ? const Color(0xFF10B981) : (isCurrent ? AppTheme.primaryOrange : const Color(0xFFCBD5E1)),
              width: 2,
            ),
          ),
          child: isDone
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
              : (isCurrent
                  ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primaryOrange, shape: BoxShape.circle)))
                  : null),
        ),
        const SizedBox(width: 14),
        Text(label, style: GoogleFonts.outfit(
          color: isDone ? const Color(0xFF0F172A) : (isCurrent ? AppTheme.primaryOrange : const Color(0xFF94A3B8)),
          fontSize: 13, fontWeight: isDone || isCurrent ? FontWeight.w800 : FontWeight.w600,
        )),
      ],
    );
  }

  Widget _buildStatusConnector(bool active) {
    return Container(
      margin: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
      width: 2, height: 18,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildPrimaryActionButtons(DeliveryProvider provider) {
    final isApproved = _status == 'approved' || provider.approvalStatus == 'approved';
    if (isApproved) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryDashboardScreen())),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text('LOAD DASHBOARD', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        ),
      );
    }

    final docs = provider.documents;
    final bool selfieDone = docs['selfie'] is Map && ((docs['selfie']['front'] ?? '').toString().isNotEmpty);
    final bool aadharDone = (docs['aadhar'] ?? docs['aadhaar']) is Map && (((docs['aadhar'] ?? docs['aadhaar'])['front'] ?? '').toString().isNotEmpty);
    final bool licenseDone = docs['license'] is Map && ((docs['license']['front'] ?? '').toString().isNotEmpty);
    final bool bankDone = (docs['bankDetails'] ?? docs['bankStatement']) is Map &&
        (((docs['bankDetails'] ?? docs['bankStatement'])['accountNumber'] ?? '').toString().isNotEmpty ||
            ((docs['bankDetails'] ?? docs['bankStatement'])['upiId'] ?? '').toString().isNotEmpty);
    final int uploadedCount = (selfieDone ? 1 : 0) + (aadharDone ? 1 : 0) + (licenseDone ? 1 : 0) + (bankDone ? 1 : 0);

    bool isDocRejected(String key) {
      final d = docs[key];
      if (d is! Map) return false;
      return (d['status'] ?? '').toString().toLowerCase() == 'rejected';
    }

    final bool hasRejections = isDocRejected('selfie') ||
        isDocRejected('aadhar') ||
        isDocRejected('aadhaar') ||
        isDocRejected('license') ||
        isDocRejected('bankDetails') ||
        isDocRejected('bankStatement') ||
        _status == 'rejected' ||
        provider.approvalStatus == 'rejected';

    final bool isUnderAudit = uploadedCount >= 4 && !hasRejections;

    return Column(
      children: [
        if (isUnderAudit) ...[
          // ── LOCKED UNDER AUDIT BUTTON ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _showLockedAuditDialog(),
              icon: const Icon(Icons.lock_rounded, size: 20, color: Color(0xFF64748B)),
              label: Text(
                'DOCUMENTS LOCKED (UNDER AUDIT)',
                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: const Color(0xFF475569)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2E8F0),
                foregroundColor: const Color(0xFF475569),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Admin review in progress. Re-upload will unlock if Admin requests corrections.',
            style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ] else if (hasRejections) ...[
          // ── UNLOCKED RE-UPLOAD BUTTON (ADMIN REQUESTED CORRECTION) ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentStatusScreen())),
              icon: const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.white),
              label: Text(
                'CORRECTION REQUESTED - RE-UPLOAD',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ] else ...[
          // ── MISSING DOCUMENTS UPLOAD BUTTON ──
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentStatusScreen())),
              icon: const Icon(Icons.document_scanner_rounded, size: 20),
              label: Text(
                'UPLOAD REMAINING DOCUMENTS (${4 - uploadedCount} MISSING)',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isRefreshing ? null : () => _refreshStatus(),
            icon: const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF4F46E5)),
            label: Text('CHECK LATEST STATUS', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
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
