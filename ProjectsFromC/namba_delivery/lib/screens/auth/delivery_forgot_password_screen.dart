import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import 'delivery_otp_screen.dart';

class DeliveryForgotPasswordScreen extends StatefulWidget {
  const DeliveryForgotPasswordScreen({super.key});

  @override
  State<DeliveryForgotPasswordScreen> createState() => _DeliveryForgotPasswordScreenState();
}

class _DeliveryForgotPasswordScreenState extends State<DeliveryForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty || !RegExp(r'^\d{10}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid 10-digit phone number', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.signalRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _isLoading = true);
    final result = await DeliveryAuthService.sendOtp(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final simulatedOtp = result['otp_simulated']?.toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryOtpScreen(phone: phone, simulatedOtp: simulatedOtp),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['error'] ?? 'Failed to send OTP'),
        backgroundColor: AppTheme.signalRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrimeBackButton(),
              const SizedBox(height: 48),
              _buildPrimeHeader(),
              const SizedBox(height: 48),
              _buildPhoneInput(),
              const SizedBox(height: 32),
              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimeBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 18),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPrimeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(icons.Iconsax.key_copy, color: AppTheme.primaryOrange, size: 32),
        ),
        const SizedBox(height: 32),
        Text('ACCOUNT RECOVERY', style: GoogleFonts.outfit(
          color: AppTheme.darkText, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1,
        )),
        const SizedBox(height: 12),
        Text(
          'WE WILL SEND A VERIFICATION CODE TO YOUR REGISTERED PHONE NUMBER TO RESET YOUR PASSWORD.',
          style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, height: 1.6),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildPhoneInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Text('+91', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: 'Phone Number',
                hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _sendOtp,
      child: Container(
        height: 60, width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: _isLoading
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
            : Center(
                child: Text('SEND VERIFICATION CODE', style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1,
                )),
              ),
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0);
  }
}
