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
                    _buildStatusHero(isApproved, provider.approvalStatus),
                    const SizedBox(height: 48),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('REQUIRED DOCUMENTS', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.darkText)),
                        const Icon(icons.Iconsax.info_circle_copy, color: AppTheme.lightText, size: 16),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),
                    _buildDocumentGrid(context, provider.documents),
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

  Widget _buildStatusHero(bool isApproved, String status) {
    final Color bgColor = isApproved ? const Color(0xFFE8F6F1) : AppTheme.primaryOrange.withValues(alpha: 0.05);
    final Color textColor = isApproved ? const Color(0xFF1B4D3E) : AppTheme.primaryOrange;
    final IconData icon = isApproved ? icons.Iconsax.tick_circle_copy : icons.Iconsax.info_circle_copy;
    final String title = isApproved ? 'Verified Partner' : status == 'pending' ? 'Verification Pending' : 'Action Required';
    final String subtitle = isApproved ? 'All your documents are up-to-date.' : 'Please upload the missing documents.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          Text(title, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.outfit(fontSize: 14, color: textColor.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildDocumentGrid(BuildContext context, Map<String, dynamic> documents) {
    return Column(
      children: [
        _docItem(context, 'selfie', 'Profile Selfie', documents['selfie'], icons.Iconsax.user_square_copy),
        _docItem(context, 'aadhar', 'Aadhar Card', documents['aadhar'], icons.Iconsax.personalcard_copy),
        _docItem(context, 'license', 'Driving License', documents['license'], icons.Iconsax.driving_copy),
        _docItem(context, 'rc', 'Vehicle RC', documents['rc'], icons.Iconsax.truck_copy),
        _docItem(context, 'pan', 'PAN Card', documents['pan'], icons.Iconsax.card_pos_copy),
        _docItem(context, 'bankStatement', 'Bank Statement', documents['bankStatement'], icons.Iconsax.bank_copy),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _docItem(BuildContext context, String key, String title, dynamic docData, IconData icon) {
    final String status = (docData?['status'] ?? 'unloaded').toString().toLowerCase();
    final bool isVerified = status == 'verified';
    final bool isPending = status == 'pending';
    final bool isRejected = status == 'rejected';

    String statusText = 'Action Required';
    Color statusColor = AppTheme.primaryOrange;
    if (isPending) { statusText = 'Pending'; statusColor = Colors.blue; }
    if (isVerified) { statusText = 'Verified'; statusColor = AppTheme.accentGreen; }
    if (isRejected) { statusText = 'Rejected'; statusColor = Colors.red; }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentUploadScreen(docType: key, title: title))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.softShadow,
          border: isRejected ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primaryOrange.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: AppTheme.primaryOrange, size: 22),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkText)),
                  const SizedBox(height: 2),
                  Text(statusText, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                ],
              ),
            ),
            if (isVerified)
              const Icon(icons.Iconsax.tick_circle_copy, color: AppTheme.accentGreen, size: 20)
            else
              const Icon(icons.Iconsax.arrow_right_3_copy, color: AppTheme.primaryOrange, size: 18),
          ],
        ),
      ),
    );
  }
}
