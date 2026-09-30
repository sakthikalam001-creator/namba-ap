import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
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
    _pollerTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        final prov = context.read<DeliveryProvider>();
        if (prov.isVerifiedPartner) {
          _pollerTimer?.cancel();
          return;
        }
        prov.fetchDocumentStatuses();
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

  bool _isDocUploaded(dynamic docData, {bool isBank = false}) {
    if (docData is! Map) return false;
    final st = (docData['status'] ?? '').toString().toLowerCase();
    if (st == 'verified' || st == 'approved' || st == 'pending' || st == 'under_review') return true;
    if ((docData['front'] ?? '').toString().trim().isNotEmpty) return true;
    if ((docData['url'] ?? '').toString().trim().isNotEmpty) return true;
    if ((docData['fileUrl'] ?? '').toString().trim().isNotEmpty) return true;
    if (isBank) {
      final acc = (docData['accountNumber'] ?? '').toString().trim();
      final upi = (docData['upiId'] ?? docData['upiNumber'] ?? '').toString().trim();
      if (acc.isNotEmpty || upi.isNotEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'DOCUMENT VERIFICATION',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: const Color(0xFF0F172A)),
        ),
        leading: Center(
          child: GestureDetector(
            onTap: () async {
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
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF0F172A)),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final isKycCompleted = _isKycFullyCompleted(provider.approvalStatus, provider.documents);
          final docs = provider.documents;

          final bool selfieDone = _isDocUploaded(docs['selfie']);
          final bool aadharDone = _isDocUploaded(docs['aadhar'] ?? docs['aadhaar']);
          final bool licenseDone = _isDocUploaded(docs['license']);
          final bool bankDone = _isDocUploaded(docs['bankDetails'] ?? docs['bankStatement'], isBank: true);
          final int uploadedCount = (selfieDone ? 1 : 0) + (aadharDone ? 1 : 0) + (licenseDone ? 1 : 0) + (bankDone ? 1 : 0);

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
                          Text('DOCUMENTS REQUIRING RE-UPLOAD', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626), letterSpacing: 0.5)),
                          const Icon(icons.Iconsax.warning_2_copy, color: Color(0xFFDC2626), size: 16),
                        ],
                      ),
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
                        )
                      else
                        _buildDocumentGrid(context, provider.documents, provider.rejectionReason),
                    ] else ...[
                      // ── 3. KYC PENDING / INITIAL REGISTRATION VIEW ──
                      _buildPendingHero(provider.approvalStatus, uploadedCount, 4),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('REQUIRED DOCUMENTS FOR AUDIT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.6)),
                          Text('4 Mandatory', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8))),
                        ],
                      ),
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
    );
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
    );
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
    );
  }

  Widget _buildPendingHero(String status, int uploadedCount, int totalRequired) {
    final bool allDone = uploadedCount >= totalRequired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: allDone ? const Color(0xFFBFDBFE) : const Color(0xFFFFEDD5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: allDone ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: allDone ? const Color(0xFFDBEAFE) : const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: allDone ? const Color(0xFF2563EB) : AppTheme.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      allDone ? 'STEP 2 OF 2 : KYC AUDIT IN PROGRESS' : 'STEP 2 OF 2 : UPLOAD DOCUMENTS',
                      style: GoogleFonts.outfit(
                        color: allDone ? const Color(0xFF2563EB) : AppTheme.primaryOrange,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$uploadedCount / $totalRequired Done',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: allDone ? const Color(0xFF059669) : AppTheme.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            allDone ? 'All Required Documents Uploaded' : 'Upload Required KYC Documents',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            allDone
                ? 'Your paperwork has been submitted to Super Admin. Once verified, your partner delivery account will be activated.'
                : 'Upload Profile Selfie, Aadhaar, License Photo, and Bank/UPI details. You can upload each document in any order.',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: totalRequired > 0 ? (uploadedCount / totalRequired).clamp(0.0, 1.0) : 0,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                allDone ? const Color(0xFF10B981) : AppTheme.primaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
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
    );
  }

  Widget _docItem(BuildContext context, String key, String title, dynamic docData, IconData icon, String mainRejectionReason, {bool isMandatory = true}) {
    final String status = (docData?['status'] ?? 'unloaded').toString().toLowerCase();
    final bool isVerified = status == 'verified' || status == 'approved';
    final bool isPending = status == 'pending' || status == 'under_review';
    final bool isRejected = status == 'rejected';
    final String? itemReason = docData?['rejectionReason'] ?? (isRejected ? mainRejectionReason : null);

    final bool isBank = (key == 'bankDetails' || key == 'bankStatement');
    final bool isSubmitted = docData != null && (docData['front'] != null || docData['accountNumber'] != null || docData['upiId'] != null || docData['upiNumber'] != null || isPending || isVerified);
    final bool isLocked = isVerified || (isSubmitted && !isRejected);

    Color cardBorderColor = const Color(0xFFE2E8F0);
    Color iconBgColor = const Color(0xFFFFF7ED);
    Color iconColor = AppTheme.primaryOrange;
    String statusLabel = isMandatory ? 'Required • Not Uploaded' : 'Optional • Not Uploaded';
    Color statusColor = const Color(0xFF94A3B8);
    Widget actionWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('UPLOAD', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryOrange, size: 10),
        ],
      ),
    );

    if (isVerified) {
      cardBorderColor = const Color(0xFFA7F3D0);
      iconBgColor = const Color(0xFFECFDF5);
      iconColor = const Color(0xFF059669);
      statusLabel = 'Verified & Approved';
      statusColor = const Color(0xFF059669);
      actionWidget = Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Color(0xFFECFDF5),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 16),
      );
    } else if (isRejected) {
      cardBorderColor = const Color(0xFFFECACA);
      iconBgColor = const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFDC2626);
      statusLabel = 'Action Required • Rejected';
      statusColor = const Color(0xFFDC2626);
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RE-UPLOAD', style: GoogleFonts.outfit(color: const Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 12),
          ],
        ),
      );
    } else if (isSubmitted || isPending) {
      cardBorderColor = const Color(0xFFBFDBFE);
      iconBgColor = const Color(0xFFEFF6FF);
      iconColor = const Color(0xFF2563EB);
      statusLabel = 'Submitted • Under Review';
      statusColor = const Color(0xFF2563EB);
      actionWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 12),
            const SizedBox(width: 4),
            Text('IN AUDIT', style: GoogleFonts.outfit(color: const Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }

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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor)),
                    ],
                  ),
                  if (isRejected && itemReason != null && itemReason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reason: $itemReason',
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF991B1B), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            actionWidget,
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFF0F172A), size: 20),
            ),
            const SizedBox(width: 10),
            Text('Document Under Audit', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFF0F172A))),
          ],
        ),
        content: Text(
          '$title has already been submitted and is locked for admin verification.\n\nYou can only modify or re-upload it if Admin explicitly requests a correction.',
          style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('UNDERSTOOD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

