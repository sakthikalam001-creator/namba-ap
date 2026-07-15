import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import 'delivery_login_screen.dart';

class DeliveryResetPasswordScreen extends StatefulWidget {
  final String phone;
  final String otp;

  const DeliveryResetPasswordScreen({
    super.key,
    required this.phone,
    required this.otp,
  });

  @override
  State<DeliveryResetPasswordScreen> createState() => _DeliveryResetPasswordScreenState();
}

class _DeliveryResetPasswordScreenState extends State<DeliveryResetPasswordScreen> {
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final newPass = _newPasswordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password must be at least 6 characters'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Passwords do not match'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    setState(() => _isLoading = true);
    final result = await DeliveryAuthService.resetPassword(
      phone: widget.phone,
      otp: widget.otp,
      newPassword: newPass,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['error'] ?? 'Reset failed'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 56),
            ),
            const SizedBox(height: 20),
            Text('Password Reset!', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Your password has been updated successfully. Please login with your new password.', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const DeliveryLoginScreen()),
                    (_) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Login Now', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 48),
              _buildHeader(),
              const SizedBox(height: 48),
              _buildPasswordFields(),
              const SizedBox(height: 36),
              _buildResetButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.lock_open_rounded, color: AppTheme.accentGreen, size: 32),
        ),
        const SizedBox(height: 24),
        Text('New Password', style: GoogleFonts.outfit(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Create a strong password for your delivery account.', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 15, height: 1.6)),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildPasswordFields() {
    return Column(
      children: [
        _buildField('New Password', _newPasswordCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
        const SizedBox(height: 16),
        _buildField('Confirm Password', _confirmPasswordCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildField(String hint, TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          icon: const Icon(Icons.lock_rounded, color: AppTheme.primaryOrange, size: 20),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w500),
          suffixIcon: GestureDetector(
            onTap: toggle,
            child: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white30, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity, height: 62,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _resetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text('Reset Password', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}
