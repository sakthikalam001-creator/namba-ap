import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/delivery_provider.dart';
import '../docs/document_upload_screen.dart';

class DocumentStatusScreen extends StatelessWidget {
  const DocumentStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('DOCUMENT STATUS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, child) {
          final isApproved = provider.approvalStatus == 'approved';
          
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    _buildStatusHero(isApproved, provider.approvalStatus, provider.rejectionReason),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('REQUIRED DOCUMENTS', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
                        const Icon(icons.Iconsax.info_circle_copy, color: AppTheme.lightText, size: 16),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),
                    _buildDocumentGrid(context, provider.documents, provider.rejectionReason),
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

  Widget _buildStatusHero(bool isApproved, String status, String rejectionReason) {
    Color bgColor = AppTheme.primaryOrange.withOpacity(0.05);
    Color textColor = AppTheme.primaryOrange;
    IconData icon = icons.Iconsax.info_circle_copy;
    String title = 'Action Required';
    String subtitle = 'Please upload all required documents for Admin verification.';

    final st = status.toLowerCase();

    if (st == 'approved') {
      bgColor = const Color(0xFFE8F6F1);
      textColor = const Color(0xFF10B981);
      icon = icons.Iconsax.tick_circle_copy;
      title = 'Verified Partner';
      subtitle = 'All your documents are approved by Admin! You are ready to deliver.';
    } else if (st == 'rejected') {
      bgColor = const Color(0xFFFEF2F2);
      textColor = Colors.red;
      icon = icons.Iconsax.close_circle_copy;
      title = 'Verification Rejected';
      subtitle = rejectionReason.isNotEmpty 
          ? 'Reason: $rejectionReason' 
          : 'One or more documents were rejected by Admin. Please re-upload.';
    } else if (st == 'pending') {
      bgColor = const Color(0xFFEFF6FF);
      textColor = Colors.blue.shade700;
      icon = icons.Iconsax.timer_1_copy;
      title = 'Verification Pending';
      subtitle = 'Admin is currently reviewing your uploaded documents.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: textColor.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 6),
          Text(
            subtitle, 
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: textColor.withOpacity(0.85), fontWeight: FontWeight.w600, height: 1.4)
          ),
        ],
      ),
    ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildDocumentGrid(BuildContext context, Map<String, dynamic> documents, String mainRejectionReason) {
    return Column(
      children: [
        _docItem(context, 'selfie', 'Profile Selfie', documents['selfie'], icons.Iconsax.user_square_copy, mainRejectionReason),
        _docItem(context, 'aadhar', 'Aadhar Card', documents['aadhar'], icons.Iconsax.personalcard_copy, mainRejectionReason),
        _docItem(context, 'license', 'Driving License', documents['license'], icons.Iconsax.driving_copy, mainRejectionReason),
        _docItem(context, 'rc', 'Vehicle RC', documents['rc'], icons.Iconsax.truck_copy, mainRejectionReason),
        _docItem(context, 'pan', 'PAN Card', documents['pan'], icons.Iconsax.card_pos_copy, mainRejectionReason),
        _docItem(context, 'bankStatement', 'Bank Statement', documents['bankStatement'], icons.Iconsax.bank_copy, mainRejectionReason),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _docItem(BuildContext context, String key, String title, dynamic docData, IconData icon, String mainRejectionReason) {
    final String status = (docData?['status'] ?? 'unloaded').toString().toLowerCase();
    final bool isVerified = status == 'verified';
    final bool isPending = status == 'pending';
    final bool isRejected = status == 'rejected';
    final String? itemReason = docData?['rejectionReason'] ?? (isRejected ? mainRejectionReason : null);

    String statusText = 'Action Required';
    Color statusColor = AppTheme.primaryOrange;
    if (isPending) { statusText = 'Pending Admin Review'; statusColor = Colors.blue.shade700; }
    if (isVerified) { statusText = 'Verified & Approved'; statusColor = AppTheme.accentGreen; }
    if (isRejected) { statusText = 'Rejected by Admin'; statusColor = Colors.red; }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentUploadScreen(docType: key, title: title))),
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
                  ? Border.all(color: AppTheme.accentGreen.withOpacity(0.3), width: 1)
                  : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isRejected ? Colors.red : isVerified ? AppTheme.accentGreen : AppTheme.primaryOrange).withOpacity(0.08), 
                borderRadius: BorderRadius.circular(16)
              ),
              child: Icon(icon, color: isRejected ? Colors.red : isVerified ? AppTheme.accentGreen : AppTheme.primaryOrange, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
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
}
