import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'waiting_approval_screen.dart';

class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() => _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _businessEmailController = TextEditingController();
  String _selectedCategory = 'Grocery';

  static String get _baseUrl {
    try {
      if (Platform.isAndroid) return 'http://100.53.131.76:5000/api/v1';
    } catch (_) {}
    return 'http://100.53.131.76:5000/api/v1';
  }

  final List<String> _categories = ['Grocery', 'Bakery', 'Medicine', 'Food', 'Fruits & Vegetables'];

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _businessEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Register as Partner',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: _isLoading ? null : _handleContinue,
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep -= 1);
          },
          steps: [
            Step(
              title: const Text('Store'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildStoreDetailsForm(),
            ),
            Step(
              title: const Text('Business'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildBusinessDetailsForm(),
            ),
            Step(
              title: const Text('Account'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _buildAccountForm(),
            ),
            Step(
              title: const Text('Submit'),
              isActive: _currentStep >= 3,
              content: _buildReviewForm(),
            ),
          ],
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                      ]),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_currentStep == 3 ? 'Submit Application' : 'Continue',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Back', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleContinue() {
    setState(() => _errorMessage = null);
    if (_currentStep == 0) {
      if (_storeNameController.text.isEmpty || _ownerNameController.text.isEmpty) {
        setState(() => _errorMessage = 'Store name and owner name are required.');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_gstController.text.isNotEmpty && _gstController.text.length != 15) {
        setState(() => _errorMessage = 'GST Number must be 15 characters.');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_phoneController.text.length < 10 || _passwordController.text.length < 6) {
        setState(() => _errorMessage = 'Enter a valid 10-digit phone and a 6+ character password.');
        return;
      }
      setState(() => _currentStep = 3);
    } else {
      _submitRegistration();
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register-vendor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ownerName': _ownerNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'storeName': _storeNameController.text.trim(),
          'storeAddress': _addressController.text.trim(),
          'category': _selectedCategory,
          'gstNumber': _gstController.text.trim(),
          'panNumber': _panController.text.trim(),
          'businessEmail': _businessEmailController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WaitingApprovalScreen(
              storeName: _storeNameController.text.trim(),
              vendorId: data['vendor']['_id'] ?? '',
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = data['error'] ?? 'Registration failed. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Cannot connect to server. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStoreDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_storeNameController, 'Store Name *', Iconsax.shop),
        const SizedBox(height: 16),
        _buildTextField(_ownerNameController, 'Owner Name *', Iconsax.user),
        const SizedBox(height: 16),
        _buildTextField(_addressController, 'Store Address', Iconsax.location, maxLines: 2),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.outfit()))).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
          decoration: InputDecoration(
            labelText: 'Category *',
            prefixIcon: const Icon(Iconsax.category, color: AppTheme.primaryOrange, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildBusinessDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_gstController, 'GST Number (optional)', Iconsax.receipt_2, hintText: 'Example: 22AAAAA0000A1Z5'),
        const SizedBox(height: 16),
        _buildTextField(_panController, 'PAN Number (optional)', Iconsax.card, hintText: 'Example: ABCDE1234F'),
        const SizedBox(height: 16),
        _buildTextField(_businessEmailController, 'Business Email', Iconsax.sms, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 8),
        Text('Business details help us verify your shop faster.',
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mediumText)),
      ],
    ).animate().fadeIn();
  }

  Widget _buildAccountForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_phoneController, 'Phone Number *', Iconsax.call, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildTextField(_emailController, 'Email (optional)', Iconsax.sms, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField(_passwordController, 'Password *', Iconsax.lock, obscureText: true),
        const SizedBox(height: 8),
        Text('Password must be at least 6 characters',
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mediumText)),
      ],
    ).animate().fadeIn();
  }

  Widget _buildReviewForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Review Your Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E1B4B))),
                  TextButton.icon(
                    onPressed: () => setState(() => _currentStep = 0),
                    icon: const Icon(Iconsax.edit, size: 14, color: AppTheme.primaryOrange),
                    label: Text('Edit All', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _reviewRow('Store Name', _storeNameController.text, stepIndex: 0),
              _reviewRow('Owner', _ownerNameController.text, stepIndex: 0),
              _reviewRow('Category', _selectedCategory, stepIndex: 0),
              if (_gstController.text.isNotEmpty) _reviewRow('GST No', _gstController.text, stepIndex: 1),
              if (_panController.text.isNotEmpty) _reviewRow('PAN No', _panController.text, stepIndex: 1),
              _reviewRow('Phone', _phoneController.text, stepIndex: 2),
              if (_emailController.text.isNotEmpty) _reviewRow('Email', _emailController.text, stepIndex: 2),
              if (_addressController.text.isNotEmpty) _reviewRow('Address', _addressController.text, stepIndex: 0),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(
              'After submission, your store will be reviewed by our Super Admin within 24–48 hours.',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.orange.shade800),
            )),
          ]),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _reviewRow(String label, String value, {int? stepIndex}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF111827)))),
          if (stepIndex != null)
            GestureDetector(
              onTap: () => setState(() => _currentStep = stepIndex),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Iconsax.edit_2, size: 14, color: AppTheme.primaryOrange),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.outfit(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: AppTheme.primaryOrange, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
        ),
      ),
    );
  }
}

