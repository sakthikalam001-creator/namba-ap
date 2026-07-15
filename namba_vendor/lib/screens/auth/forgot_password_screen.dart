import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';

enum ResetStep { phone, otp, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  ResetStep _currentStep = ResetStep.phone;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _simulatedOtp; // To help the user in the simulated environment

  static String get _baseUrl {
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5000/api/v1';
    } catch (_) {}
    return 'http://localhost:5000/api/v1';
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showError('Enter a valid 10-digit phone number');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _currentStep = ResetStep.otp;
          _simulatedOtp = data['otp_simulated'];
        });
        _showSuccess('OTP sent successfully');
      } else {
        _showError(data['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      _showError('Connection error. Is the backend running?');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('Enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text.trim(),
          'otp': otp,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _currentStep = ResetStep.password);
      } else {
        _showError(data['error'] ?? 'Invalid OTP');
      }
    } catch (e) {
      _showError('Connection error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text.trim(),
          'otp': _otpController.text.trim(),
          'newPassword': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _showSuccess('Password reset successfully. Please login again.');
        Navigator.pop(context);
      } else {
        _showError(data['error'] ?? 'Reset failed');
      }
    } catch (e) {
      _showError('Connection error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 48),
              if (_currentStep == ResetStep.phone) _buildPhoneStep(),
              if (_currentStep == ResetStep.otp) _buildOtpStep(),
              if (_currentStep == ResetStep.password) _buildPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'Forgot Password';
    String subtitle = 'Don\'t worry, it happens. We\'ll help you reset your access.';

    if (_currentStep == ResetStep.otp) {
      title = 'Verify OTP';
      subtitle = 'We have sent a 6-digit code to ${_phoneController.text}';
    } else if (_currentStep == ResetStep.password) {
      title = 'New Password';
      subtitle = 'Create a secure new password for your vendor account.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            _currentStep == ResetStep.phone ? Iconsax.key : 
            _currentStep == ResetStep.otp ? Iconsax.sms : Iconsax.lock, 
            color: AppTheme.primaryOrange, 
            size: 32
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkText,
            letterSpacing: -1,
          ),
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.mediumText,
            height: 1.4,
          ),
        ).animate().fadeIn(delay: 200.ms).slideX(),
      ],
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _phoneController,
          label: 'Registered Phone Number',
          hint: '99999 99999',
          icon: Iconsax.call,
          type: TextInputType.phone,
        ),
        const SizedBox(height: 40),
        _buildPrimaryButton('Send Verification Code', _requestOtp),
      ],
    ).animate().fadeIn();
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _otpController,
          label: 'Verification Code',
          hint: '000000',
          icon: Iconsax.password_check,
          type: TextInputType.number,
        ),
        if (_simulatedOtp != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SIMULATED OTP: $_simulatedOtp',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _requestOtp,
          child: Text('Didn\'t receive code? Resend', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 40),
        _buildPrimaryButton('Verify OTP', _verifyOtp),
      ],
    ).animate().fadeIn();
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _passwordController,
          label: 'New Password',
          hint: '••••••••',
          icon: Iconsax.lock,
          isPassword: true,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          hint: '••••••••',
          icon: Iconsax.lock,
          isPassword: true,
        ),
        const SizedBox(height: 40),
        _buildPrimaryButton('Reset Password & Login', _resetPassword),
      ],
    ).animate().fadeIn();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkText),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: type,
            obscureText: isPassword,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: AppTheme.lightText),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Icon(icon, color: AppTheme.primaryOrange, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkText,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(
                text,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
      ),
    );
  }
}
