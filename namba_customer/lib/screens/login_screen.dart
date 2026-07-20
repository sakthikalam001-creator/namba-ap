import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'registration_screen.dart';
import 'map_location_picker_screen.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String _verificationId = '';
  int? _resendToken;
  String _simulatedOtp = '';

  void _sendOtp() async {
    if (_phoneCtrl.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')));
      return;
    }
    setState(() => _loading = true);

    // Generate random 6-digit OTP
    final random = Random();
    final otpVal = 100000 + random.nextInt(900000);
    _simulatedOtp = otpVal.toString();

    // Mock OTP Send
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _loading = false;
      _otpSent = true;
      _verificationId = "mock_ver_id";
      _otpCtrl.text = _simulatedOtp; // Prefill for convenience
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mock OTP Sent: $_simulatedOtp'),
        backgroundColor: const Color(0xFF4F46E5),
      ),
    );
  }

  void _verifyOtp() async {
    if (_otpCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter 6-digit OTP')),
      );
      return;
    }
    if (_otpCtrl.text != _simulatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid OTP. Please enter the correct code.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _loading = true);

    await Future.delayed(const Duration(seconds: 1));
    _handleAuthSuccess();
  }

  void _handleAuthSuccess() async {
    if (!mounted) return;
    
    setState(() => _loading = true);
    final phone = _phoneCtrl.text;
    final apiService = CustomerApiService();
    
    // Check if user already exists in database
    final res = await apiService.customerOtpLogin(phone);

    if (!mounted) return;
    setState(() => _loading = false);

    if (res == null) {
      // API call failed (network error etc.) - show error, don't redirect
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server connection failed. Please check your internet and try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _otpSent = false);
      return;
    }

    if (res['success'] == true) {
      // ✅ Existing User -> Login directly, skip registration
      final userData = res['user'];

      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.login(
        phone,
        name: userData['name'],
        email: userData['email'],
        uid: userData['_id'],
        token: res['token'],
      );
      if (!mounted) return;
      if (!auth.hasSetLocation) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MapLocationPickerScreen(isInitialSetup: true)),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } else if (res['userNotFound'] == true || res['isNewUser'] == true) {
      // 🆕 Brand new user -> Registration page
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => RegistrationScreen(phone: phone, uid: phone)),
        (_) => false,
      );
    } else {
      // Backend returned error message - show it, stay on login
      final msg = res['message'] ?? 'Login failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.delivery_dining_rounded, size: 64, color: Colors.white),
              const SizedBox(height: 12),
              const Text('Namba', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Sign in to continue', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
              const SizedBox(height: 40),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Enter your phone number', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text("We'll send you a verification code", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                        const SizedBox(height: 32),
                        _buildPhoneField(),
                        if (_otpSent) ...[
                          const SizedBox(height: 20),
                          _buildOtpField(),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.vpn_key_rounded, color: Color(0xFF7C3AED), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.4),
                                      children: [
                                        const TextSpan(text: 'Mock OTP Sent: '),
                                        TextSpan(
                                          text: _simulatedOtp,
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF7C3AED), fontSize: 15),
                                        ),
                                        const TextSpan(text: '\n(Auto-filled for testing convenience)'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(_otpSent ? 'Verify OTP' : 'Send OTP',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () => setState(() { _otpSent = false; _otpCtrl.clear(); }),
                              child: const Text('Change Number', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('+91 ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              enabled: !_otpSent,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '9876543210',
                hintStyle: TextStyle(color: Colors.black26),
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '• • • • • •',
          hintStyle: TextStyle(color: Colors.black26, fontSize: 18),
          counterText: '',
          labelText: 'Enter OTP',
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }
}
