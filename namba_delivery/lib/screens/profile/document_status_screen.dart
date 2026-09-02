import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/delivery_provider.dart';
import '../../services/delivery_auth_service.dart';
import '../docs/document_upload_screen.dart';
import '../docs/bank_details_screen.dart';
import '../auth/delivery_pending_approval_screen.dart';

class DocumentStatusScreen extends StatefulWidget {
  const DocumentStatusScreen({super.key});

  @override
  State<DocumentStatusScreen> createState() => _DocumentStatusScreenState();
}

class _DocumentStatusScreenState extends State<DocumentStatusScreen> {
  Timer? _pollerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().fetchDocumentStatuses();
    });
    _pollerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        context.read<DeliveryProvider>().fetchDocumentStatuses();
      }
    });
  }

  @override
  void dispose() {
    _pollerTimer?.cancel();
    super.dispose();
  }

  bool _isKycFullyCompleted(String approvalStatus, Map<String, dynamic> documents) {
    final status = approvalStatus.toLowerCase();
    if (status == 'approved') return true;

    bool isDocOk(String key) {
      final d = documents[key];
      if (d is! Map) return false;
      final front = (d['front'] ?? '').toString().trim();
      final st = (d['status'] ?? '').toString().toLowerCase();
      return front.isNotEmpty && (st == 'verified' || st == 'approved');
    }

    bool isDocRejected(String key) {
      final d = documents[key];
      if (d is! Map) return false;
      final st = (d['status'] ?? '').toString().toLowerCase();
      return st == 'rejected';
    }

    bool isBankOk() {
      final d = documents['bankDetails'] ?? documents['bankStatement'];
      if (d is! Map) return true;
      final st = (d['status'] ?? '').toString().toLowerCase();
      final hasAcc = (d['accountNumber'] ?? '').toString().trim().isNotEmpty;
      final hasUpi = (d['upiId'] ?? d['upiNumber'] ?? '').toString().trim().isNotEmpty;
      final hasFront = (d['front'] ?? '').toString().trim().isNotEmpty;
      return (hasAcc || hasUpi || hasFront) && (st == 'verified' || st == 'approved');
    }

    final bool aadharOk = isDocOk('aadhar') || isDocOk('aadhaar');
    final bool licenseOk = isDocOk('license');
    final bool selfieOk = isDocOk('selfie');
    final bool bankOk = isBankOk();

    final bool hasRejection = isDocRejected('aadhar') ||
        isDocRejected('aadhaar') ||
        isDocRejected('license') ||
        isDocRejected('selfie') ||
        isDocRejected('rc') ||
        isDocRejected('pan') ||
        isDocRejected('bankStatement') ||
        isDocRejected('bankDetails') ||
        status == 'rejected';

    if (hasRejection) return false;
    return aadharOk && licenseOk && selfieOk && bankOk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('DOCUMENT STATUS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () async {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              final name = await DeliveryAuthService.getDriverName();
              final id = await DeliveryAuthService.getDriverId();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => DeliveryPendingApprovalScreen(driverName: name, driverId: id)),
                );
              }
            }
          },
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final isKycCompleted = _isKycFullyCompleted(provider.approvalStatus, provider.documents);
          final docs = provider.documents;

          // Find rejected documents
          final List<Map<String, dynamic>> rejectedDocs = [];
          final allDocKeys = [
            {'key': 'selfie', 'title': 'Profile Selfie', 'icon': icons.Iconsax.user_square_copy},
            {'key': 'aadhar', 'title': 'Aadhar Card', 'icon': icons.Iconsax.personalcard_copy},
            {'key': 'license', 'title': 'Driving License', 'icon': icons.Iconsax.driving_copy},
            {'key': 'rc', 'title': 'Vehicle RC', 'icon': icons.Iconsax.truck_copy},
            {'key': 'pan', 'title': 'PAN Card', 'icon': icons.Iconsax.card_pos_copy},
            {'key': 'bankDetails', 'title': 'Bank & UPI Details', 'icon': icons.Iconsax.bank_copy},
          ];

          for (final item in allDocKeys) {
            final key = item['key'] as String;
            final docData = docs[key] ?? (key == 'bankDetails' ? docs['bankStatement'] : null);
            final st = (docData is Map ? docData['status'] ?? '' : '').toString().toLowerCase();
            if (st == 'rejected') {
              rejectedDocs.add(item);
            }
          }

          final bool hasRejections = rejectedDocs.isNotEmpty || provider.approvalStatus.toLowerCase() == 'rejected';

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    if (isKycCompleted) ...[
                      // ── 1. VERIFIED PARTNER VIEW (NO REQUIRED DOCS) ──
                      _buildVerifiedPartnerHero(),
                      const SizedBox(height: 28),
                      _buildVerifiedBadgeCard(),
                    ] else if (hasRejections) ...[
                      // ── 2. ADMIN REJECTED / REQUESTED DOCUMENT CORRECTION VIEW ──
                      _buildRejectionHero(provider.rejectionReason),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('DOCUMENTS REQUIRING RE-UPLOAD', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.red.shade800, letterSpacing: 0.5)),
                          const Icon(icons.Iconsax.warning_2_copy, color: Colors.red, size: 16),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                      // Show ONLY rejected/requested docs
                      if (rejectedDocs.isNotEmpty)
                        Column(
                          children: rejectedDocs.map((item) {
                            final key = item['key'] as String;
                            final title = item['title'] as String;
                            final icon = item['icon'] as IconData;
                            return _docItem(context, key, title, docs[key], icon, provider.rejectionReason);
                          }).toList(),
                        ).animate().fadeIn(delay: 300.ms)
                      else
                        _buildDocumentGrid(context, provider.documents, provider.rejectionReason),
                    ] else ...[
                      // ── 3. KYC PENDING / INITIAL REGISTRATION VIEW ──
                      _buildPendingHero(provider.approvalStatus),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('REQUIRED DOCUMENTS FOR AUDIT', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
                          const Icon(icons.Iconsax.info_circle_copy, color: AppTheme.lightText, size: 16),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                      _buildDocumentGrid(context, provider.documents, provider.rejectionReason),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerifiedPartnerHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x4010B981), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: const Icon(icons.Iconsax.tick_circle_copy, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Verified Partner', style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF065F46))),
          const SizedBox(height: 8),
          Text(
            'All your identification and KYC documents are verified & approved by Super Admin!\nYour partner account is active and authorized for delivery.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF047857), fontWeight: FontWeight.w700, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildVerifiedBadgeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF166534), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KYC COMPLETED & AUDITED', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('Verified Identity Paperwork', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF86EFAC))),
                child: Text('ACTIVE', style: GoogleFonts.outfit(color: const Color(0xFF166534), fontWeight: FontWeight.w900, fontSize: 10.5)),
              ),
            ],
          ),
          const Divider(height: 28, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Text('Aadhaar Card & Identity verified', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Text('Driving License & Vehicle Registration verified', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 8),
              Text('Profile Selfie & Face Match verified', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildRejectionHero(String rejectionReason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.05), blurRadius: 16)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(icons.Iconsax.close_circle_copy, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text('Action Required', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red.shade900)),
          const SizedBox(height: 6),
          Text(
            rejectionReason.isNotEmpty
                ? 'Admin Request: $rejectionReason'
                : 'Admin has requested a correction or clearer re-upload for one or more documents below.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.red.shade800, fontWeight: FontWeight.w700, height: 1.4),
          ),
        ],
      ),
    ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildPendingHero(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle),
            child: const Icon(icons.Iconsax.timer_1_copy, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text('KYC Verification Pending', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
          const SizedBox(height: 6),
          Text(
            'Please ensure all required documents are uploaded.\nAdmin will audit and activate your account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.blue.shade800, fontWeight: FontWeight.w700, height: 1.4),
          ),
        ],
      ),
    ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildDocumentGrid(BuildContext context, Map<String, dynamic> documents, String mainRejectionReason) {
    return Column(
      children: [
        _docItem(context, 'selfie', 'Profile Selfie', documents['selfie'], icons.Iconsax.user_square_copy, mainRejectionReason, isMandatory: true),
        _docItem(context, 'aadhar', 'Aadhar Card', documents['aadhar'], icons.Iconsax.personalcard_copy, mainRejectionReason, isMandatory: true),
        _docItem(context, 'license', 'Driving License', documents['license'], icons.Iconsax.driving_copy, mainRejectionReason, isMandatory: true),
        _docItem(context, 'bankDetails', 'Bank & UPI Details', documents['bankDetails'] ?? documents['bankStatement'], icons.Iconsax.bank_copy, mainRejectionReason, isMandatory: true),
        _docItem(context, 'rc', 'Vehicle RC', documents['rc'], icons.Iconsax.truck_copy, mainRejectionReason, isMandatory: false),
        _docItem(context, 'pan', 'PAN Card', documents['pan'], icons.Iconsax.card_pos_copy, mainRejectionReason, isMandatory: false),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _docItem(BuildContext context, String key, String title, dynamic docData, IconData icon, String mainRejectionReason, {bool isMandatory = true, String? badgeText}) {
    final String status = (docData?['status'] ?? 'unloaded').toString().toLowerCase();
    final bool isVerified = status == 'verified' || status == 'approved';
    final bool isPending = status == 'pending';
    final bool isRejected = status == 'rejected';
    final String? itemReason = docData?['rejectionReason'] ?? (isRejected ? mainRejectionReason : null);

    final bool isBank = (key == 'bankDetails' || key == 'bankStatement');
    String statusText = isMandatory ? (isBank ? 'Required - Provide Bank or UPI' : 'Required - Not Uploaded') : 'Optional - Not Uploaded';
    Color statusColor = isMandatory ? AppTheme.primaryOrange : const Color(0xFF64748B);
    if (isPending) {
      statusText = 'Pending Review';
      statusColor = Colors.blue.shade700;
    }
    if (isVerified) {
      statusText = 'Verified & Approved';
      statusColor = AppTheme.accentGreen;
    }
    if (isRejected) {
      statusText = 'Rejected - Action Required';
      statusColor = Colors.red;
    }

    final bool isSubmitted = docData != null && (docData['front'] != null || docData['accountNumber'] != null || docData['upiId'] != null);
    final bool isLocked = isVerified || (isSubmitted && !isRejected);

    return GestureDetector(
      onTap: () {
        if (isVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $title is verified and approved. Editing is locked.'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (isLocked) {
          _showDocumentLockedDialog(context, title);
        } else if (isBank) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BankDetailsScreen()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentUploadScreen(docType: key, title: title)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.softShadow,
          border: isRejected
              ? Border.all(color: Colors.red.shade300, width: 1.5)
              : isVerified
                  ? Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3), width: 1)
                  : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isRejected ? Colors.red : isVerified ? AppTheme.accentGreen : AppTheme.primaryOrange).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isRejected ? Colors.red : isVerified ? AppTheme.accentGreen : AppTheme.primaryOrange, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMandatory ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isMandatory ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          isMandatory ? 'REQUIRED' : 'OPTIONAL',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: isMandatory ? const Color(0xFFB45309) : const Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(statusText, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                    ],
                  ),
                  if (isRejected && itemReason != null && itemReason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reason: $itemReason',
                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.red.shade800, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isVerified)
              const Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 22)
            else
              Icon(icons.Iconsax.arrow_right_3_copy, color: isRejected ? Colors.red : AppTheme.primaryOrange, size: 18),
          ],
        ),
      ),
    );
  }

  void _showDocumentLockedDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 10),
            Text('Document Under Audit', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(
          '$title has already been submitted and is locked for admin verification.\n\nYou can only modify or re-upload it if Admin explicitly requests a correction.',
          style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

