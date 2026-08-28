import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import '../../providers/delivery_provider.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _upiNumberController = TextEditingController();

  File? _passbookImage;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final provider = context.read<DeliveryProvider>();
    final docs = provider.documents;
    final bankData = (docs['bankDetails'] ?? docs['bankStatement']) as Map<String, dynamic>? ?? {};

    final fallbackName = await DeliveryAuthService.getDriverName();

    if (!mounted) return;
    setState(() {
      _nameController.text = bankData['accountHolderName']?.toString() ?? fallbackName;
      _bankNameController.text = bankData['bankName']?.toString() ?? '';
      _accountNumberController.text = bankData['accountNumber']?.toString() ?? '';
      _ifscController.text = bankData['ifscCode']?.toString() ?? '';
      _upiIdController.text = bankData['upiId']?.toString() ?? '';
      _upiNumberController.text = bankData['upiNumber']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiIdController.dispose();
    _upiNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickPassbookPhoto(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => _passbookImage = File(picked.path));
    }
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final hasUpi = _upiIdController.text.trim().isNotEmpty || _upiNumberController.text.trim().isNotEmpty;
    final hasBank = _accountNumberController.text.trim().isNotEmpty;

    if (!hasUpi && !hasBank) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please provide either UPI ID / Number OR Bank Account details for payouts.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      if (_passbookImage != null) {
        final uploadRes = await DeliveryAuthService.uploadFile(_passbookImage!.path);
        if (uploadRes['success'] == true && uploadRes['url'] != null) {
          photoUrl = uploadRes['url'];
        }
      }

      final driverId = await DeliveryAuthService.getDriverId();
      final res = await DeliveryAuthService.saveBankDetails(
        driverId: driverId,
        accountHolderName: _nameController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        ifscCode: _ifscController.text.trim().toUpperCase(),
        upiId: _upiIdController.text.trim(),
        upiNumber: _upiNumberController.text.trim(),
        fileUrl: photoUrl,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text('Bank & UPI Details Saved Successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        await context.read<DeliveryProvider>().fetchDocumentStatuses();
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to save bank details'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final docs = provider.documents;
    final bankData = (docs['bankDetails'] ?? docs['bankStatement']) as Map<String, dynamic>? ?? {};
    final status = (bankData['status'] ?? 'unloaded').toString().toLowerCase();
    final existingPhoto = bankData['front']?.toString();

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('BANK & UPI DETAILS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  _buildStatusHeader(status, bankData['rejectionReason']),
                  const SizedBox(height: 24),

                  // Flexible Instructions Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You can provide either UPI ID (GPay / PhonePe / Paytm) OR Bank Account details for receiving daily/weekly earnings payouts.',
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF3730A3), fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // UPI Section First (Most popular & easiest)
                  Text('UPI DETAILS (RECOMMENDED FOR INSTANT PAYOUTS)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5), letterSpacing: 0.5)),
                  const SizedBox(height: 14),

                  // UPI ID
                  _buildInputField(
                    controller: _upiIdController,
                    label: 'UPI ID / VPA (Optional if Bank given)',
                    hint: 'e.g. 9876543210@paytm, name@okaxis, name@okhdfcbank',
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 16),

                  // UPI Number / GPay Phone
                  _buildInputField(
                    controller: _upiNumberController,
                    label: 'UPI Mobile Number (Optional)',
                    hint: 'e.g. 9876543210 (GPay / PhonePe / Paytm number)',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 28),

                  // Section Title
                  Text('BANK ACCOUNT DETAILS (OPTIONAL IF UPI GIVEN)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.darkText, letterSpacing: 0.5)),
                  const SizedBox(height: 14),

                  // Account Holder Name
                  _buildInputField(
                    controller: _nameController,
                    label: 'Account Holder Name',
                    hint: 'Full name as per bank records',
                    icon: Icons.person_rounded,
                    validator: (v) {
                      final hasBankAcc = _accountNumberController.text.trim().isNotEmpty;
                      if (hasBankAcc && (v == null || v.trim().isEmpty)) {
                        return 'Please enter account holder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Bank Name
                  _buildInputField(
                    controller: _bankNameController,
                    label: 'Bank Name',
                    hint: 'e.g. State Bank of India, HDFC Bank, ICICI',
                    icon: Icons.account_balance_rounded,
                    validator: (v) {
                      final hasBankAcc = _accountNumberController.text.trim().isNotEmpty;
                      if (hasBankAcc && (v == null || v.trim().isEmpty)) {
                        return 'Please enter bank name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Account Number
                  _buildInputField(
                    controller: _accountNumberController,
                    label: 'Bank Account Number',
                    hint: 'Enter your bank account number',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty && v.trim().length < 8) {
                        return 'Account number too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // IFSC Code
                  _buildInputField(
                    controller: _ifscController,
                    label: 'Bank IFSC Code',
                    hint: 'e.g. SBIN0001234, HDFC0000240',
                    icon: Icons.qr_code_rounded,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      final hasBankAcc = _accountNumberController.text.trim().isNotEmpty;
                      if (hasBankAcc) {
                        if (v == null || v.trim().isEmpty) return 'Please enter IFSC code';
                        if (v.trim().length < 9) return 'Invalid IFSC code format';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Passbook / Cancelled Cheque Photo (Optional)
                  Text('PASSBOOK / CHEQUE PHOTO (OPTIONAL)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.darkText, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('Upload photo of passbook front page or cancelled cheque for faster admin verification.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 14),
                  _buildPassbookPhotoPicker(existingPhoto),
                  const SizedBox(height: 36),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text('SAVE & SUBMIT BANK DETAILS', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status, dynamic rejectionReason) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (status == 'verified' || status == 'approved') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      label = 'Bank Details Verified & Approved';
      icon = Icons.verified_rounded;
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFF991B1B);
      label = 'Bank Details Rejected - Action Required';
      icon = Icons.cancel_rounded;
    } else if (status == 'pending') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1E40AF);
      label = 'Bank Details Submitted (Pending Admin Audit)';
      icon = Icons.hourglass_top_rounded;
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = 'Please Enter Your Bank & UPI Details';
      icon = Icons.info_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: fg, fontSize: 13)),
              ),
            ],
          ),
          if (status == 'rejected' && rejectionReason != null && rejectionReason.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Reason: $rejectionReason', style: GoogleFonts.outfit(fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        validator: validator,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.darkText),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700),
          hintText: hint,
          hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
          icon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPassbookPhotoPicker(String? existingPhoto) {
    final bool hasImage = _passbookImage != null || (existingPhoto != null && existingPhoto.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          if (hasImage) ...[
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _passbookImage != null
                  ? Image.file(_passbookImage!, fit: BoxFit.cover)
                  : Image.network(
                      existingPhoto!.startsWith('http') ? existingPhoto : 'http://54.204.9.126:5000/$existingPhoto',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                    ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPassbookPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text('Take Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF818CF8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickPassbookPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text('Choose Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFF818CF8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
