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
      if (uploadRes['success'] == true) {
        final driverId = await DeliveryAuthService.getDriverId();
        final saveRes = await DeliveryAuthService.uploadDocumentSide(
          driverId: driverId,
          docType: widget.docType,
          side: isFront ? 'front' : 'back',
          fileUrl: uploadRes['url'],
        );

        if (mounted && saveRes['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isFront ? "Front" : "Back"} side uploaded!')),
          );
          context.read<DeliveryProvider>().fetchDocumentStatuses();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => isFront ? _isUploadingFront = false : _isUploadingBack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final docData = provider.documents[widget.docType] ?? {};
    final status = docData['status'] ?? 'unloaded';

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
                _buildStatusHeader(status),
                const SizedBox(height: 12),
                Text(
                  'Upload clear photos of your ${widget.title} for verification.',
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.mediumText, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 40),
                _buildUploadCard('FRONT SIDE', _frontImage, docData['front'], _isUploadingFront, true),
                if (widget.docType != 'selfie') ...[
                  const SizedBox(height: 32),
                  _buildUploadCard('BACK SIDE', _backImage, docData['back'], _isUploadingBack, false),
                ],
                const SizedBox(height: 48),
                if (docData['rejectionReason'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(icons.Iconsax.info_circle_copy, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Text('REJECTION REASON', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(docData['rejectionReason'], style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w600, fontSize: 14, height: 1.5)),
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

  Widget _buildStatusHeader(String status) {
    Color color = AppTheme.primaryOrange;
    String label = 'ACTION REQUIRED';
    IconData icon = icons.Iconsax.info_circle_copy;
    
    if (status == 'pending') { 
      color = Colors.blue; 
      label = 'VERIFICATION PENDING'; 
      icon = icons.Iconsax.timer_1_copy;
    }
    if (status == 'verified') { 
      color = AppTheme.accentGreen; 
      label = 'DOCUMENT VERIFIED'; 
      icon = icons.Iconsax.tick_circle_copy;
    }
    if (status == 'rejected') { 
      color = Colors.red; 
      label = 'REJECTED - RE-UPLOAD'; 
      icon = icons.Iconsax.info_circle_copy;
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

  Widget _buildUploadCard(String label, File? locFile, String? svrUrl, bool isUploading, bool isFront) {
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
                'TAP TO CHANGE', 
                style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w800, fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showPickerOptions(isFront),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: hasImage ? AppTheme.accentGreen.withOpacity(0.2) : AppTheme.lightText.withOpacity(0.2),
                width: 2,
                style: hasImage ? BorderStyle.solid : BorderStyle.solid, // Future: Use DottedBorder if package available
              ),
              image: hasImage ? DecorationImage(
                image: locFile != null ? FileImage(locFile) : NetworkImage('http://localhost:5000$svrUrl') as ImageProvider,
                fit: BoxFit.cover,
              ) : null,
              boxShadow: AppTheme.softShadow,
            ),
            child: !hasImage ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
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
              child: const Icon(icons.Iconsax.tick_circle_copy, color: Colors.white, size: 28),
            ),
          ),
        ),
        if (locFile != null && !isUploading) ...[
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
}
