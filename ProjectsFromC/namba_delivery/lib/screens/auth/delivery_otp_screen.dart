import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import 'delivery_reset_password_screen.dart';

class DeliveryOtpScreen extends StatefulWidget {
  final String phone;
  final String? simulatedOtp; // dev only

  const DeliveryOtpScreen({
    super.key,
    required this.phone,
    this.simulatedOtp,
  });

  @override
  State<DeliveryOtpScreen> createState() => _DeliveryOtpScreenState();
}

class _DeliveryOtpScreenState extends State<DeliveryOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-fill OTP in development
    if (widget.simulatedOtp != null && widget.simulatedOtp!.length == 6) {
      Future.delayed(const Duration(milliseconds: 500), () {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = widget.simulatedOtp![i];
        }
        setState(() {});
      });
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
        }
      });
      return _resendCountdown > 0;
    });
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await DeliveryAuthService.verifyOtp(
      phone: widget.phone,
      otp: _enteredOtp,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryResetPasswordScreen(phone: widget.phone, otp: _enteredOtp),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['error'] ?? 'Invalid OTP'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    setState(() { _canResend = false; _resendCountdown = 60; });
    final result = await DeliveryAuthService.sendOtp(widget.phone);
    if (!mounted) return;
    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? 'OTP resent!' : (result['error'] ?? 'Failed to resend')),
      backgroundColor: result['success'] == true ? AppTheme.accentGreen : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
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
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 48),
              _buildOtpBoxes(),
              const SizedBox(height: 16),
              if (widget.simulatedOtp != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text('Dev OTP: ${widget.simulatedOtp}', style: GoogleFonts.outfit(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ).animate().fadeIn(),
              const SizedBox(height: 36),
              _buildVerifyButton(),
              const SizedBox(height: 28),
              _buildResendSection(),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.sms_rounded, color: AppTheme.primaryOrange, size: 28),
        ),
        const SizedBox(height: 20),
        Text('Enter OTP', style: GoogleFonts.outfit(
          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900,
        )),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 15, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: '+91 ${widget.phone}',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 48, height: 58,
          child: TextFormField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
              ),
            ),
            onChanged: (val) {
              if (val.isNotEmpty && i < 5) {
                _focusNodes[i + 1].requestFocus();
              } else if (val.isEmpty && i > 0) {
                _focusNodes[i - 1].requestFocus();
              }
              setState(() {});
              if (_enteredOtp.length == 6) {
                FocusScope.of(context).unfocus();
              }
            },
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 300 + i * 60)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
      }),
    );
  }

  Widget _buildVerifyButton() {
    final isComplete = _enteredOtp.length == 6;
    return SizedBox(
      width: double.infinity, height: 62,
      child: ElevatedButton(
        onPressed: (isComplete && !_isLoading) ? _verifyOtp : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.07),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text('Verify OTP', style: GoogleFonts.outfit(
                color: isComplete ? Colors.white : Colors.white30, fontSize: 17, fontWeight: FontWeight.w800,
              )),
      ),
    ).animate().fadeIn(delay: 700.ms);
  }

  Widget _buildResendSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Didn't receive OTP? ", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14)),
        GestureDetector(
          onTap: _canResend ? _resendOtp : null,
          child: Text(
            _canResend ? 'Resend' : 'Resend in ${_resendCountdown}s',
            style: GoogleFonts.outfit(
              color: _canResend ? AppTheme.primaryOrange : Colors.white30,
              fontSize: 14, fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }
}
