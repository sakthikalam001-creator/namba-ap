import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'services/verification_service.dart';

class DriverVerificationScreen extends StatefulWidget {
  const DriverVerificationScreen({super.key});

  static void openAuditModal(BuildContext context, dynamic driver, {VoidCallback? onUpdated}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DriverKYCAuditModal',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => _FullScreenKycAuditDialog(
        initialDriver: driver,
        onDocAction: (dId, dType, status, reason, onSuccess) async {
          final res = await VerificationService.verifyDocument(dId, dType, status, reason: reason);
          if (res['success'] == true) {
            onSuccess();
            if (onUpdated != null) onUpdated();
          }
        },
        onMasterApprove: (dId, name, onSuccess) async {
          final res = await VerificationService.approveDriver(dId);
          if (res['success'] == true) {
            onSuccess();
            if (onUpdated != null) onUpdated();
          }
        },
        onMasterReject: (dId, name, onSuccess) {
          final controller = TextEditingController();
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('REJECT DRIVER APPLICATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF991B1B), fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provide reason for rejecting $name\'s partner account:', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Invalid documents, verification failed...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(c);
                    final res = await VerificationService.rejectDriver(dId, controller.text.trim().isEmpty ? 'Application does not meet requirements' : controller.text.trim());
                    if (res['success'] == true) {
                      onSuccess();
                      if (onUpdated != null) onUpdated();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('REJECT APPLICATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          );
        },
        onImageZoom: (url, title) {
          if (url.isEmpty) return;
          showDialog(
            context: context,
            barrierColor: Colors.black87,
            builder: (c) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(c),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        onCopy: (txt, lbl) {
          Clipboard.setData(ClipboardData(text: txt));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied $lbl to clipboard'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
          );
        },
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  @override
  State<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  List<dynamic> _pendingDrivers = [];
  List<dynamic> _allDrivers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'PENDING'; // 'PENDING', 'COMPLETED', 'ALL'
  Timer? _hubAutoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Live real-time auto refresh every 10 seconds
    _hubAutoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _hubAutoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        VerificationService.getPendingVerifications(),
        VerificationService.getAllDrivers(),
      ]);

      final pendingRes = results[0];
      final allRes = results[1];

      if (!mounted) return;
      setState(() {
        if (pendingRes['success'] == true && pendingRes['data'] != null) {
          _pendingDrivers = pendingRes['data'];
        } else {
          _pendingDrivers = [];
        }

        if (allRes['success'] == true && allRes['data'] != null) {
          _allDrivers = allRes['data'];
        } else {
          _allDrivers = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading verification hub data: $e');
      if (!mounted) return;
      if (!silent) setState(() => _isLoading = false);
    }
  }

  static String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text.trim();
    return text.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  static bool _isKycFullyCompleted(dynamic driver) {
    if (driver == null) return false;
    final approval = (driver['driverApprovalStatus'] ?? 'pending').toString().toLowerCase();
    final rawDocs = driver['documents'];
    if (rawDocs is! Map) return false;
    final docs = rawDocs;

    bool isDocUploadedAndVerified(String key) {
      final doc = docs[key];
      if (doc is! Map) return false;
      final front = (doc['front'] ?? '').toString().trim();
      final status = (doc['status'] ?? 'unloaded').toString().toLowerCase();
      if (front.isEmpty) return false;
      return (status == 'verified' || status == 'approved');
    }

    bool isDocRejected(String key) {
      final doc = docs[key];
      if (doc is! Map) return false;
      final status = (doc['status'] ?? '').toString().toLowerCase();
      return status == 'rejected';
    }

    final bool aadharOk = isDocUploadedAndVerified('aadhar') || isDocUploadedAndVerified('aadhaar');
    final bool licenseOk = isDocUploadedAndVerified('license');
    final bool selfieOk = isDocUploadedAndVerified('selfie');

    final bool anyRejected = isDocRejected('aadhar') ||
        isDocRejected('aadhaar') ||
        isDocRejected('license') ||
        isDocRejected('selfie') ||
        isDocRejected('rc') ||
        isDocRejected('pan') ||
        isDocRejected('bankStatement') ||
        approval == 'rejected';

    if (anyRejected) return false;
    return aadharOk && licenseOk && selfieOk && approval == 'approved';
  }

  static bool _hasAnyDocRejected(dynamic driver) {
    if (driver == null) return false;
    final approval = (driver['driverApprovalStatus'] ?? 'pending').toString().toLowerCase();
    if (approval == 'rejected') return true;
    final rawDocs = driver['documents'];
    if (rawDocs is! Map) return false;
    for (final v in rawDocs.values) {
      if (v is Map && (v['status'] ?? '').toString().toLowerCase() == 'rejected') {
        return true;
      }
    }
    return false;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('$label copied to clipboard!', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        width: 320,
      ),
    );
  }

  Future<void> _handleDocAction(String driverId, String docType, String status, {String? reason, VoidCallback? onSuccess}) async {
    final res = await VerificationService.verifyDocument(
      driverId: driverId,
      docType: docType,
      status: status,
      reason: reason,
    );

    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${docType.toUpperCase()} marked as ${status.toUpperCase()}'),
          backgroundColor: status == 'verified' ? const Color(0xFF10B981) : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
      if (onSuccess != null) onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Action failed'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleMasterApprove(String driverId, String driverName, {VoidCallback? onSuccess}) async {
    final res = await VerificationService.approveDriver(driverId);
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 $driverName application approved successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
      if (onSuccess != null) onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Approval failed'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRejectDocDialog(String driverId, String docType, {VoidCallback? onSuccess}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('REJECT ${docType.toUpperCase()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify the reason for rejecting this document:', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Photo blurry, name mismatch, expired license...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDocAction(
                driverId,
                docType,
                'rejected',
                reason: controller.text.trim().isEmpty ? 'Document unclear or invalid' : controller.text.trim(),
                onSuccess: onSuccess,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('REJECT DOCUMENT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showMasterRejectDialog(String driverId, String driverName, {VoidCallback? onSuccess}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('REJECT DRIVER APPLICATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF991B1B), fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide reason for rejecting $driverName\'s partner account:', style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Invalid documents, verification failed...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final res = await VerificationService.rejectDriver(driverId, controller.text.trim().isEmpty ? 'Application does not meet requirements' : controller.text.trim());
              if (!mounted) return;
              if (res['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application rejected'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
                );
                await _loadData();
                if (onSuccess != null) onSuccess();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('REJECT APPLICATION', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showImageZoomDialog(String? fullUrl, String title) {
    if (fullUrl == null || fullUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF334155), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40)],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: Color(0xFF818CF8), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20),
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Image.network(
                          fullUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            final String cleanPath = fullUrl.replaceAll('http://54.204.9.126:5000/', '').replaceAll('http://localhost:5000/', '');
                            final String localBackendPath = 'D:/New folder (2)/namba_backend/$cleanPath';
                            if (File(localBackendPath).existsSync()) {
                              return Image.file(File(localBackendPath), fit: BoxFit.contain);
                            }
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey.shade600),
                                  const SizedBox(height: 12),
                                  Text('Image not accessible', style: GoogleFonts.outfit(color: Colors.white70)),
                                ],
                              ),
                            );
                          },
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
    );
  }

  void _showDriverKycAuditModal(dynamic driver) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DriverKYCAuditModal',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => _FullScreenKycAuditDialog(
        initialDriver: driver,
        onDocAction: (dId, dType, status, reason, onSuccess) => _handleDocAction(dId, dType, status, reason: reason, onSuccess: onSuccess),
        onMasterApprove: (dId, name, onSuccess) => _handleMasterApprove(dId, name, onSuccess: onSuccess),
        onMasterReject: (dId, name, onSuccess) => _showMasterRejectDialog(dId, name, onSuccess: onSuccess),
        onImageZoom: (url, title) => _showImageZoomDialog(url, title),
        onCopy: (txt, lbl) => _copyToClipboard(txt, lbl),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDriverListItem(dynamic driver) {
    final driverId = (driver['_id'] ?? driver['id'] ?? '').toString();
    final shortId = driverId.length > 8 ? driverId.substring(driverId.length - 8) : driverId;
    final rawName = driver['name'] ?? 'Driver Applicant';
    final name = _toTitleCase(rawName.toString());
    final phone = (driver['phone'] ?? 'N/A').toString();
    final vehicleType = (driver['vehicleType'] ?? 'Bike').toString().toUpperCase();
    final vehicleNumber = (driver['vehicleNumber'] ?? 'N/A').toString().toUpperCase();
    final isOnline = driver['isOnline'] == true;

    final rawDocs = driver['documents'];
    final Map<String, dynamic> docs = (rawDocs is Map<String, dynamic>) ? rawDocs : <String, dynamic>{};
    final selfie = docs['selfie'];
    final selfiePath = selfie is Map ? selfie['front'] : null;
    final String host = VerificationService.baseUrl.split('/api').first;
    final String? cleanSelfie = (selfiePath != null && selfiePath.toString().isNotEmpty) ? selfiePath.toString().replaceAll('\\', '/') : null;
    final String? selfieUrl = cleanSelfie != null
        ? ((cleanSelfie.startsWith('http://') || cleanSelfie.startsWith('https://')) ? cleanSelfie : '$host${cleanSelfie.startsWith('/') ? '' : '/'}$cleanSelfie')
        : null;

    final bool isCompleted = _isKycFullyCompleted(driver);
    final bool hasRejected = _hasAnyDocRejected(driver);

    final createdAt = driver['createdAt'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(driver['createdAt'].toString()).toLocal())
        : 'Recently Registered';
    final updatedAt = driver['updatedAt'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(driver['updatedAt'].toString()).toLocal())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? const Color(0xFF86EFAC) : (hasRejected ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1)),
          width: 1.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => _showDriverKycAuditModal(driver),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Avatar
              InkWell(
                onTap: () {
                  if (selfieUrl != null) _showImageZoomDialog(selfieUrl, 'Profile Selfie - $name');
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF818CF8), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: selfieUrl != null
                      ? Image.network(selfieUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(name.substring(0, 1), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5), fontSize: 22))))
                      : Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : 'D', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5), fontSize: 22))),
                ),
              ),
              const SizedBox(width: 18),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text('ID: #$shortId', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: const Color(0xFF1E40AF))),
                        ),
                        const SizedBox(width: 10),
                        // ── KYC STATUS BADGE ──
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF166534)),
                                const SizedBox(width: 5),
                                Text('KYC COMPLETED', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFF166534), letterSpacing: 0.5)),
                              ],
                            ),
                          )
                        else if (hasRejected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cancel_rounded, size: 14, color: Color(0xFF991B1B)),
                                const SizedBox(width: 5),
                                Text('KYC REJECTED', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFF991B1B), letterSpacing: 0.5)),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFF92400E)),
                                const SizedBox(width: 5),
                                Text('KYC PENDING', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFF92400E), letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        const SizedBox(width: 10),
                        // ── REAL STATUS ──
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                                  shape: BoxShape.circle,
                                  boxShadow: isOnline ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.6), blurRadius: 4)] : [],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isOnline ? 'REAL: ONLINE' : 'REAL: OFFLINE',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  color: isOnline ? const Color(0xFF065F46) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 5),
                            Text(phone, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                            const SizedBox(width: 5),
                            InkWell(
                              onTap: () => _copyToClipboard(phone, 'Phone Number'),
                              child: const Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.two_wheeler_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 5),
                            Text('$vehicleType • $vehicleNumber', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF334155))),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.how_to_reg_rounded, size: 14, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 5),
                            Text('JOINED: $createdAt', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                          ],
                        ),
                        if (updatedAt != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.update_rounded, size: 14, color: Color(0xFF059669)),
                              const SizedBox(width: 5),
                              Text('UPDATED: $updatedAt', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Action Button
              ElevatedButton.icon(
                onPressed: () => _showDriverKycAuditModal(driver),
                icon: const Icon(Icons.fact_check_rounded, size: 16),
                label: Text('AUDIT KYC & DOCS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter drivers
    List<dynamic> sourceList;
    if (_selectedFilter == 'PENDING') {
      sourceList = _pendingDrivers;
    } else if (_selectedFilter == 'COMPLETED') {
      sourceList = _allDrivers.where((d) => _isKycFullyCompleted(d)).toList();
    } else {
      sourceList = _allDrivers;
    }

    final filteredDrivers = sourceList.where((d) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final name = (d['name'] ?? '').toString().toLowerCase();
      final phone = (d['phone'] ?? '').toString().toLowerCase();
      final vNum = (d['vehicleNumber'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || vNum.contains(q);
    }).toList();

    final int completedCount = _allDrivers.where((d) => _isKycFullyCompleted(d)).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── TOP HEADER ──
          Container(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF4F46E5), size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DOCUMENT VERIFICATION & KYC AUDIT HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 22, color: const Color(0xFF0F172A), letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('Real-time audit of delivery partner identity papers, Aadhaar, Driving License, joined date & activation',
                        style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                // Refresh Button
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text('REFRESH LIST', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // ── METRICS & FILTER ROW ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search applicant by name, mobile phone, or vehicle number...',
                              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12.5),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Filter Tabs
                Wrap(
                  spacing: 10,
                  children: [
                    _filterChip('PENDING', 'KYC PENDING (${_pendingDrivers.length})', Icons.hourglass_top_rounded, const Color(0xFFD97706)),
                    _filterChip('COMPLETED', 'KYC COMPLETED ($completedCount)', Icons.verified_rounded, const Color(0xFF10B981)),
                    _filterChip('ALL', 'ALL DRIVERS ROSTER (${_allDrivers.length})', Icons.people_alt_rounded, const Color(0xFF4F46E5)),
                  ],
                ),
              ],
            ),
          ),

          // ── MAIN CONTENT LIST ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3),
                        SizedBox(height: 16),
                        Text('Loading Partner Verification Records...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : filteredDrivers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: const Icon(Icons.mark_email_read_rounded, size: 48, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(height: 18),
                              Text('NO RECORDS FOUND', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No driver applicants matched your search criteria.'
                                    : 'There are no document verification records matching this filter.',
                                style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(32),
                        itemCount: filteredDrivers.length,
                        itemBuilder: (context, index) {
                          return _buildDriverListItem(filteredDrivers[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label, IconData icon, Color activeColor) {
    final bool isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFCBD5E1)),
          boxShadow: isSelected ? [BoxShadow(color: activeColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FULL-SCREEN DRIVER KYC AUDIT DIALOG CONSOLE
// ─────────────────────────────────────────────────────────────
class _FullScreenKycAuditDialog extends StatefulWidget {
  final dynamic initialDriver;
  final Function(String driverId, String docType, String status, String? reason, VoidCallback onSuccess) onDocAction;
  final Function(String driverId, String name, VoidCallback onSuccess) onMasterApprove;
  final Function(String driverId, String name, VoidCallback onSuccess) onMasterReject;
  final Function(String url, String title) onImageZoom;
  final Function(String text, String label) onCopy;

  const _FullScreenKycAuditDialog({
    required this.initialDriver,
    required this.onDocAction,
    required this.onMasterApprove,
    required this.onMasterReject,
    required this.onImageZoom,
    required this.onCopy,
  });

  @override
  State<_FullScreenKycAuditDialog> createState() => _FullScreenKycAuditDialogState();
}

class _FullScreenKycAuditDialogState extends State<_FullScreenKycAuditDialog> {
  late dynamic _driver;
  Timer? _liveAuditTimer;

  @override
  void initState() {
    super.initState();
    _driver = widget.initialDriver;
    // Real-time live KYC console polling every 3 seconds
    _liveAuditTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _silentRefreshDriver();
    });
  }

  @override
  void dispose() {
    _liveAuditTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefreshDriver() async {
    final driverId = _driver['_id'] ?? _driver['id'];
    if (driverId == null || !mounted) return;

    try {
      final res = await VerificationService.getDriverById(driverId.toString());
      if (res['success'] == true && mounted) {
        setState(() {
          final updatedDocs = res['data'] ?? _driver['documents'];
          final updatedStatus = res['status'] ?? _driver['driverApprovalStatus'];
          final updatedReason = res['rejectionReason'] ?? _driver['driverRejectionReason'];
          
          if (_driver is Map) {
            _driver = {
              ..._driver,
              'documents': updatedDocs,
              'driverApprovalStatus': updatedStatus,
              'driverRejectionReason': updatedReason,
              'isOnline': res['isOnline'] ?? _driver['isOnline'],
            };
          }
        });
      }
    } catch (e) {
      debugPrint('Silent KYC refresh error: $e');
    }
  }

  void _copyToClipboard(String text, String label) {
    widget.onCopy(text, label);
  }

  static String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text.trim();
    return text.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  Widget _buildDocPhotoBox(String label, String? rawUrl, String driverName, String docName) {
    final String host = VerificationService.baseUrl.split('/api').first;
    final String? cleanPath = (rawUrl != null && rawUrl.trim().isNotEmpty) ? rawUrl.trim().replaceAll('\\', '/') : null;
    final String? fullUrl = cleanPath != null
        ? ((cleanPath.startsWith('http://') || cleanPath.startsWith('https://'))
            ? cleanPath
            : '$host${cleanPath.startsWith('/') ? '' : '/'}$cleanPath')
        : null;

    final bool hasImage = fullUrl != null && fullUrl.isNotEmpty;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              if (hasImage) {
                widget.onImageZoom(fullUrl, '$docName ($label) - $driverName');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 165,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hasImage ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          fullUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            final String localPath = fullUrl.replaceAll('http://54.204.9.126:5000/', '').replaceAll('http://localhost:5000/', '');
                            final String localBackendPath = 'D:/New folder (2)/namba_backend/$localPath';
                            if (File(localBackendPath).existsSync()) {
                              return Image.file(File(localBackendPath), fit: BoxFit.cover);
                            }
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey.shade400),
                                  const SizedBox(height: 4),
                                  Text('Unavailable', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sd_storage_rounded, color: Color(0xFF34D399), size: 10),
                                const SizedBox(width: 4),
                                Text('~210 KB', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9.5)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.no_photography_rounded, size: 32, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text('Not Uploaded', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestReuploadDialog(String driverId, String docKey, String docTitle) {
    final controller = TextEditingController(text: 'Photo is blurry or not readable');
    String selectedQuickReason = 'Photo is blurry or not readable';
    final quickReasons = [
      'Photo is blurry or not readable',
      'Corners / details are cut off',
      'Document has expired',
      'Name / Details mismatch',
      'Incorrect document uploaded',
      'Custom Reason',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.replay_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REQUEST RE-UPLOAD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), fontSize: 15)),
                    Text('Rider will be notified to re-upload $docTitle', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Reason:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF334155))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickReasons.map((r) {
                    final isSel = selectedQuickReason == r;
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedQuickReason = r;
                          if (r != 'Custom Reason') {
                            controller.text = r;
                          } else {
                            controller.clear();
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          r,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? const Color(0xFFB91C1C) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('Custom Note for Rider:', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Please re-upload a clear photo showing full name and expiry date',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final reason = controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : (selectedQuickReason != 'Custom Reason' ? selectedQuickReason : 'Please re-upload a clear document photo.');
                Navigator.pop(ctx);

                widget.onDocAction(driverId, docKey, 'rejected', reason, () {
                  setState(() {
                    if (_driver['documents'] == null) _driver['documents'] = {};
                    if (_driver['documents'][docKey] == null) _driver['documents'][docKey] = {};
                    _driver['documents'][docKey]['status'] = 'rejected';
                    _driver['documents'][docKey]['rejectionReason'] = reason;
                  });
                });
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text('SEND REQUEST TO RIDER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCardItem(String driverId, String driverName, String docKey, String title, dynamic docData) {
    final Map<String, dynamic> data = (docData is Map<String, dynamic>) ? docData : <String, dynamic>{};
    final String status = (data['status'] ?? 'unloaded').toString().toLowerCase();
    final String? front = data['front'];
    final String? back = data['back'];
    final String? rejectionReason = data['rejectionReason'];
    final bool hasUploadedImage = (front != null && front.toString().trim().isNotEmpty);

    Color statusBg;
    Color statusFg;
    Color statusBorder;
    String statusText;
    IconData statusIcon;

    if (!hasUploadedImage && status == 'unloaded') {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF64748B);
      statusBorder = const Color(0xFFCBD5E1);
      statusText = 'NOT UPLOADED';
      statusIcon = Icons.remove_circle_outline_rounded;
    } else if (status == 'verified' || status == 'approved') {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF166534);
      statusBorder = const Color(0xFF86EFAC);
      statusText = 'VERIFIED & APPROVED';
      statusIcon = Icons.verified_rounded;
    } else if (status == 'rejected') {
      statusBg = const Color(0xFFFEF2F2);
      statusFg = const Color(0xFF991B1B);
      statusBorder = const Color(0xFFFCA5A5);
      statusText = 'RE-UPLOAD REQUESTED';
      statusIcon = Icons.replay_rounded;
    } else {
      statusBg = const Color(0xFFFFFBEB);
      statusFg = const Color(0xFFB45309);
      statusBorder = const Color(0xFFFDE68A);
      statusText = 'PENDING REVIEW';
      statusIcon = Icons.hourglass_top_rounded;
    }

    final bool isSingleImage = docKey == 'selfie';
    final bool isBank = (docKey == 'bankDetails' || docKey == 'bankStatement');

    final String accountHolder = data['accountHolderName']?.toString() ?? '';
    final String bankName = data['bankName']?.toString() ?? '';
    final String accNum = data['accountNumber']?.toString() ?? '';
    final String ifsc = data['ifscCode']?.toString() ?? '';
    final String upiId = data['upiId']?.toString() ?? '';
    final String upiNumber = data['upiNumber']?.toString() ?? '';
    final bool hasBankInfo = accNum.isNotEmpty || ifsc.isNotEmpty || upiId.isNotEmpty || upiNumber.isNotEmpty;
    final bool isOptionalDoc = (docKey == 'rc' || docKey == 'pan' || docKey == 'bankDetails' || docKey == 'bankStatement');
    final bool canApprove = hasUploadedImage || hasBankInfo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doc Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF1E293B), letterSpacing: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOptionalDoc ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isOptionalDoc ? const Color(0xFFCBD5E1) : const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      isOptionalDoc ? 'OPTIONAL' : 'MANDATORY',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isOptionalDoc ? const Color(0xFF64748B) : const Color(0xFFB45309),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusFg),
                    const SizedBox(width: 4),
                    Text(statusText, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: statusFg)),
                  ],
                ),
              ),
            ],
          ),
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text('Reason: $rejectionReason', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 12),

          // ── SPECIALIZED BANK & UPI DETAILS BOX ──
          if (isBank) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  if (accountHolder.isNotEmpty || bankName.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Holder / Bank:', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
                        Text('${accountHolder.isNotEmpty ? accountHolder : "N/A"} (${bankName.isNotEmpty ? bankName : "Bank"})', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('A/C Number:', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(accNum.isNotEmpty ? accNum : 'Not Provided', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 0.5)),
                          if (accNum.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(onTap: () => _copyToClipboard(accNum, 'Bank Account Number'), child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF4F46E5))),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('IFSC Code:', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(ifsc.isNotEmpty ? ifsc : 'Not Provided', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                          if (ifsc.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(onTap: () => _copyToClipboard(ifsc, 'Bank IFSC Code'), child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF4F46E5))),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (upiId.isNotEmpty || upiNumber.isNotEmpty) ...[
                    const Divider(height: 12, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('UPI ID / No:', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w800)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              upiId.isNotEmpty ? upiId : upiNumber,
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _copyToClipboard(upiId.isNotEmpty ? upiId : upiNumber, 'UPI ID'),
                              child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Photos Row
          Row(
            children: [
              _buildDocPhotoBox(isBank ? 'PASSBOOK / CHEQUE' : (isSingleImage ? 'PHOTO' : 'FRONT SIDE'), front, driverName, title),
              if (!isSingleImage && !isBank) ...[
                const SizedBox(width: 14),
                _buildDocPhotoBox('BACK SIDE', back, driverName, title),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Actions Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (!canApprove || status == 'verified')
                      ? null
                      : () => widget.onDocAction(driverId, docKey, 'verified', null, () {
                            setState(() {
                              if (_driver['documents'] == null) _driver['documents'] = {};
                              if (_driver['documents'][docKey] == null) _driver['documents'][docKey] = {};
                              _driver['documents'][docKey]['status'] = 'verified';
                            });
                          }),
                  icon: const Icon(Icons.check_circle_rounded, size: 15),
                  label: Text('APPROVE DOCUMENT', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRequestReuploadDialog(driverId, docKey, title),
                  icon: const Icon(Icons.replay_rounded, size: 15),
                  label: Text(status == 'rejected' ? 'UPDATE REQUEST' : 'REQUEST RE-UPLOAD', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocLayout(String driverId, String name, Map<String, dynamic> docs, bool isWide) {
    final aadhar = docs['aadhar'] ?? docs['aadhaar'];
    final license = docs['license'];
    final selfie = docs['selfie'];
    final rc = docs['rc'];
    final pan = docs['pan'];
    final dynamic bankData = docs['bankDetails'] ?? docs['bankStatement'];

    final cardList = [
      _buildDocCardItem(driverId, name, 'aadhar', 'Aadhaar Card', aadhar),
      _buildDocCardItem(driverId, name, 'license', 'Driving License', license),
      _buildDocCardItem(driverId, name, 'selfie', 'Face Profile Selfie', selfie),
      _buildDocCardItem(driverId, name, 'rc', 'Vehicle Registration Certificate (RC)', rc),
      if (pan != null) _buildDocCardItem(driverId, name, 'pan', 'PAN Card', pan),
      _buildDocCardItem(driverId, name, 'bankDetails', 'Bank & UPI Details', bankData),
    ];

    if (!isWide) {
      return Column(
        children: cardList
            .map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: card,
                ))
            .toList(),
      );
    }

    final List<Widget> rows = [];
    for (int i = 0; i < cardList.length; i += 2) {
      final leftCard = cardList[i];
      final bool hasRight = (i + 1) < cardList.length;
      final rightCard = hasRight ? cardList[i + 1] : null;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leftCard),
              const SizedBox(width: 18),
              Expanded(child: rightCard ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final driverId = (_driver['_id'] ?? _driver['id'] ?? '').toString();
    final shortId = driverId.length > 8 ? driverId.substring(driverId.length - 8) : driverId;
    final rawName = _driver['name'] ?? 'Driver Applicant';
    final name = _toTitleCase(rawName.toString());
    final phone = (_driver['phone'] ?? 'N/A').toString();
    final vehicleType = (_driver['vehicleType'] ?? 'Bike').toString().toUpperCase();
    final vehicleNumber = (_driver['vehicleNumber'] ?? 'N/A').toString().toUpperCase();

    final rawDocs = _driver['documents'];
    final Map<String, dynamic> docs = (rawDocs is Map<String, dynamic>) ? rawDocs : <String, dynamic>{};

    final aadhar = docs['aadhar'] ?? docs['aadhaar'];
    final license = docs['license'];
    final selfie = docs['selfie'];
    final rc = docs['rc'];
    final pan = docs['pan'];
    final bankStatement = docs['bankStatement'];

    final selfiePath = selfie is Map ? selfie['front'] : null;
    final String host = VerificationService.baseUrl.split('/api').first;
    final String? cleanSelfie = (selfiePath != null && selfiePath.toString().isNotEmpty) ? selfiePath.toString().replaceAll('\\', '/') : null;
    final String? selfieUrl = cleanSelfie != null
        ? ((cleanSelfie.startsWith('http://') || cleanSelfie.startsWith('https://')) ? cleanSelfie : '$host${cleanSelfie.startsWith('/') ? '' : '/'}$cleanSelfie')
        : null;

    final bool isCompleted = _DriverVerificationScreenState._isKycFullyCompleted(_driver);
    final bool hasRejected = _DriverVerificationScreenState._hasAnyDocRejected(_driver);

    final createdAt = _driver['createdAt'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_driver['createdAt'].toString()).toLocal())
        : 'Recently Registered';
    final updatedAt = _driver['updatedAt'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_driver['updatedAt'].toString()).toLocal())
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Column(
        children: [
          // ── TOP HEADER BAR ──
          Container(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 18),
                // Selfie Avatar
                InkWell(
                  onTap: () {
                    if (selfieUrl != null) widget.onImageZoom(selfieUrl, 'Profile Photo - $name');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCompleted ? const Color(0xFF10B981) : Colors.white38, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: selfieUrl != null
                        ? Image.network(selfieUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(name.substring(0, 1), style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22))))
                        : Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : 'D', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22))),
                  ),
                ),
                const SizedBox(width: 18),
                // Driver Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text('KYC AUDIT CONSOLE • ID: #$shortId', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => widget.onCopy(driverId, 'Driver ID'),
                            child: const Icon(Icons.copy_rounded, color: Colors.white54, size: 12),
                          ),
                          const SizedBox(width: 10),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                              child: Text('KYC COMPLETED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                            )
                          else if (hasRejected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(6)),
                              child: Text('KYC REJECTED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6)),
                              child: Text('KYC PENDING', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text('$vehicleType • $vehicleNumber', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Master Approve / Reject
                ElevatedButton.icon(
                  onPressed: () => widget.onMasterApprove(driverId, name, () {
                    setState(() => _driver['driverApprovalStatus'] = 'approved');
                  }),
                  icon: const Icon(Icons.verified_user_rounded, size: 16),
                  label: Text('APPROVE ALL & ACTIVATE', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => widget.onMasterReject(driverId, name, () {
                    setState(() => _driver['driverApprovalStatus'] = 'rejected');
                  }),
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: Text('REJECT APPLICATION', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 14),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ── AUDIT BODY ──
          Expanded(
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  // Info bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 10),
                        Text('Registered Mobile: ', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey.shade600, fontSize: 13)),
                        Text(phone, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), fontSize: 13)),
                        const SizedBox(width: 24),
                        Text('Joined: ', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey.shade600, fontSize: 13)),
                        Text(createdAt, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5), fontSize: 13)),
                        if (updatedAt != null) ...[
                          const SizedBox(width: 24),
                          Text('Last Updated: ', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey.shade600, fontSize: 13)),
                          Text(updatedAt, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF059669), fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Document Layout (Natural Responsive Height - Zero Overflows, Zero Empty Space)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 850;
                      return _buildDocLayout(driverId, name, docs, isWide);
                    },
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

