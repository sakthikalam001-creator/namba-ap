import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import 'delivery_reset_password_screen.dart';

class DeliveryOtpScreen extends StatefulWidget {
  final String phone;

  const DeliveryOtpScreen({
    super.key,
    required this.phone,
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
  }

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;
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
        SnackBar(
          content: Text('Please enter the complete 6-digit Security PIN', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: AppTheme.signalRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
        content: Text(result['error'] ?? 'Invalid or expired Security PIN', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.signalRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    setState(() => _isLoading = true);
    final result = await DeliveryAuthService.sendOtp(widget.phone);
    if (!mounted) return;
    setState(() => _isLoading = false);

    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        result['success'] == true ? 'Security PIN resent to WhatsApp!' : (result['error'] ?? 'Failed to resend PIN'),
        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
      ),
      backgroundColor: result['success'] == true ? const Color(0xFF10B981) : AppTheme.signalRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 36),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildOtpBoxes(),
              const SizedBox(height: 40),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.mark_chat_read_rounded, color: Color(0xFF25D366), size: 24),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'SENT VIA WHATSAPP',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF25D366),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Enter Security PIN', style: GoogleFonts.outfit(
          color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5,
        )),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14.5, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a 6-digit Delivery Rider Security PIN to your WhatsApp on '),
              TextSpan(
                text: '+91 ${widget.phone}',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 48, height: 60,
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
              fillColor: Colors.white.withValues(alpha: 0.06),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
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
        ).animate().fadeIn(delay: Duration(milliseconds: 250 + i * 50)).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
      }),
    );
  }

  Widget _buildVerifyButton() {
    final isComplete = _enteredOtp.length == 6;
    return Container(
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        gradient: isComplete
            ? const LinearGradient(
                colors: [Color(0xFFFF7A00), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isComplete ? null : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isComplete
            ? [BoxShadow(color: const Color(0xFFEA580C).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))]
            : null,
      ),
      child: ElevatedButton(
        onPressed: (isComplete && !_isLoading) ? _verifyOtp : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text('VERIFY SECURITY PIN', style: GoogleFonts.outfit(
                color: isComplete ? Colors.white : Colors.white30, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8,
              )),
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildResendSection() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Didn't receive PIN on WhatsApp? ", style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: _canResend ? _resendOtp : null,
            child: Text(
              _canResend ? 'Resend PIN' : 'Resend in ${_resendCountdown}s',
              style: GoogleFonts.outfit(
                color: _canResend ? AppTheme.primaryOrange : Colors.white38,
                fontSize: 13, fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 700.ms);
  }
}

