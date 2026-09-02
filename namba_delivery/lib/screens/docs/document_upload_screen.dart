import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import '../../providers/delivery_provider.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String docType;
  final String title;

  const DocumentUploadScreen({super.key, required this.docType, required this.title});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  File? _frontImage;
  File? _backImage;
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source, bool isFront) async {
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        if (isFront) _frontImage = File(pickedFile.path);
        else _backImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadSide(bool isFront) async {
    final imageFile = isFront ? _frontImage : _backImage;
    if (imageFile == null) return;

    setState(() => isFront ? _isUploadingFront = true : _isUploadingBack = true);

    try {
      final uploadRes = await DeliveryAuthService.uploadFile(imageFile.path);
      if (uploadRes['success'] == true && uploadRes['url'] != null) {
        final driverId = await DeliveryAuthService.getDriverId();
        final saveRes = await DeliveryAuthService.uploadDocumentSide(
          driverId: driverId,
          docType: widget.docType,
          side: isFront ? 'front' : 'back',
          fileUrl: uploadRes['url'],
        );

        if (mounted && saveRes['success'] == true) {
          context.read<DeliveryProvider>().fetchDocumentStatuses();
          _showUploadSuccessDialog(widget.title, isFront, widget.docType == 'selfie');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Upload Error: ${saveRes['error'] ?? "Failed to save document record"}')),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Upload Error: ${uploadRes['error'] ?? "Failed to upload image file"}')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Upload Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isFront ? _isUploadingFront = false : _isUploadingBack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final docData = provider.documents[widget.docType] ?? {};
    final status = (docData['status'] ?? 'unloaded').toString().toLowerCase();

    final bool isVerified = status == 'verified' || status == 'approved';
    final bool isRejected = status == 'rejected' || status == 'reupload_requested';
    final bool hasFrontSvr = docData['front'] != null && docData['front'].toString().isNotEmpty;
    final bool hasBackSvr = docData['back'] != null && docData['back'].toString().isNotEmpty;
    final bool hasSubmitted = widget.docType == 'selfie' ? hasFrontSvr : (hasFrontSvr && hasBackSvr);

    // Document is strictly locked if it is verified OR already submitted and NOT rejected by Admin
    final bool isDocLocked = isVerified || (hasSubmitted && !isRejected);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text(widget.title.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(status, isDocLocked),
                const SizedBox(height: 12),
                if (isDocLocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Icon(isVerified ? Icons.verified_rounded : Icons.lock_outline_rounded, color: isVerified ? const Color(0xFF166534) : const Color(0xFF1E40AF), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isVerified
                                ? 'This document is approved & verified. Securely locked.'
                                : 'Document submitted & locked under Admin verification. Re-upload is only enabled if Admin explicitly requests a correction.',
                            style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: isVerified ? const Color(0xFF166534) : const Color(0xFF1E40AF), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  Text(
                    'Upload clear photos of your ${widget.title} for verification.',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.mediumText, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                ],
                _buildUploadCard('FRONT SIDE', _frontImage, docData['front'], _isUploadingFront, true, isDocLocked),
                if (widget.docType != 'selfie') ...[
                  const SizedBox(height: 32),
                  _buildUploadCard('BACK SIDE', _backImage, docData['back'], _isUploadingBack, false, isDocLocked),
                ],
                const SizedBox(height: 48),
                if (docData['rejectionReason'] != null && isRejected) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(icons.Iconsax.info_circle_copy, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Text('ADMIN RE-UPLOAD REQUEST', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(docData['rejectionReason'], style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w700, fontSize: 14, height: 1.5)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status, bool isLocked) {
    Color color = AppTheme.primaryOrange;
    String label = 'ACTION REQUIRED';
    IconData icon = icons.Iconsax.info_circle_copy;
    
    if (status == 'verified' || status == 'approved') { 
      color = AppTheme.accentGreen; 
      label = 'DOCUMENT VERIFIED 🔒'; 
      icon = icons.Iconsax.tick_circle_copy;
    } else if (status == 'rejected' || status == 'reupload_requested') { 
      color = Colors.red; 
      label = 'ADMIN REQUESTED RE-UPLOAD'; 
      icon = icons.Iconsax.info_circle_copy;
    } else if (isLocked || status == 'pending' || status == 'under_review') { 
      color = Colors.blue; 
      label = 'LOCKED UNDER AUDIT 🔒'; 
      icon = icons.Iconsax.timer_1_copy;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildUploadCard(String label, File? locFile, String? svrUrl, bool isUploading, bool isFront, bool isDocLocked) {
    final hasImage = locFile != null || svrUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            if (hasImage && !isUploading) 
              Text(
                isDocLocked ? '🔒 LOCKED' : 'TAP TO CHANGE', 
                style: GoogleFonts.outfit(color: isDocLocked ? const Color(0xFF64748B) : AppTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Builder(builder: (context) {
          final String host = DeliveryAuthService.baseUrl.split('/api').first;
          final String? fullSvrUrl = svrUrl != null
              ? (svrUrl.startsWith('http') ? svrUrl : '$host${svrUrl.startsWith('/') ? '' : '/'}$svrUrl')
              : null;

          return GestureDetector(
            onTap: () {
              if (isDocLocked) {
                _showLockedDocDialog();
              } else {
                _showPickerOptions(isFront);
              }
            },
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: hasImage ? AppTheme.accentGreen.withOpacity(0.2) : AppTheme.lightText.withOpacity(0.2),
                  width: 2,
                ),
                image: hasImage ? DecorationImage(
                  image: (locFile != null
                      ? FileImage(locFile)
                      : NetworkImage(fullSvrUrl ?? '')) as ImageProvider,
                  fit: BoxFit.cover,
                ) : null,
                boxShadow: AppTheme.softShadow,
              ),
              child: !hasImage ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppTheme.lightBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(icons.Iconsax.camera_copy, color: AppTheme.primaryOrange, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('TAP TO CAPTURE OR UPLOAD', style: GoogleFonts.outfit(color: AppTheme.mediumText, fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Support JPG, PNG up to 5MB', style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.w500, fontSize: 10)),
                ],
              ) : isUploading ? Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
              ) : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.all(16),
                child: Icon(isDocLocked ? Icons.lock_outline_rounded : icons.Iconsax.tick_circle_copy, color: Colors.white, size: 28),
              ),
            ),
          );
        }),
        if (locFile != null && !isUploading && !isDocLocked) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _uploadSide(isFront),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(icons.Iconsax.export_copy, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('UPLOAD THIS SIDE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
        ]
      ],
    );
  }

  void _showLockedDocDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 10),
            Text('Document Locked', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Text(
          'This document has been submitted and is currently locked under verification.\n\nYou can only re-upload if Admin explicitly requests a correction or re-upload.',
          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK, Got it'),
          ),
        ],
      ),
    );
  }

  void _showPickerOptions(bool isFront) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 32),
            Text('SELECT IMAGE SOURCE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerOption(icons.Iconsax.camera_copy, 'USE CAMERA', () { Navigator.pop(context); _pickImage(ImageSource.camera, isFront); }),
                _pickerOption(icons.Iconsax.image_copy, 'BROWSE GALLERY', () { Navigator.pop(context); _pickImage(ImageSource.gallery, isFront); }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24), 
            decoration: BoxDecoration(
              color: AppTheme.lightBg, 
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.lightText.withOpacity(0.1)),
            ), 
            child: Icon(icon, color: AppTheme.primaryOrange, size: 32),
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: AppTheme.darkText, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  void _showUploadSuccessDialog(String docTitle, bool isFront, bool isSingle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                'Upload Completed!',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                '$docTitle ${isSingle ? "" : (isFront ? "(Front Side)" : "(Back Side)")} has been submitted successfully.\n\nOur admin team will audit your document for verification.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B), height: 1.4, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    if (isSingle || !isFront) {
                      Navigator.pop(context); // Return to document status list
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    isSingle || !isFront ? 'Continue to Document Hub' : 'Proceed to Back Side',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
