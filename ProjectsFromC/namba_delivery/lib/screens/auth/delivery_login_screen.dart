import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import '../dashboard/delivery_dashboard_screen.dart';
import 'delivery_register_screen.dart';
import 'delivery_forgot_password_screen.dart';
import 'delivery_pending_approval_screen.dart';

class DeliveryLoginScreen extends StatefulWidget {
  const DeliveryLoginScreen({super.key});

  @override
  State<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}

class _DeliveryLoginScreenState extends State<DeliveryLoginScreen> with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (phone.isEmpty || !RegExp(r'^\d{10}$').hasMatch(phone)) {
      _showSnack('Enter a valid 10-digit phone number', isError: true);
      return;
    }
    if (password.isEmpty) {
      _showSnack('Please enter your password', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _scanController.repeat();

    await Future.delayed(const Duration(milliseconds: 1200));

    final result = await DeliveryAuthService.login(phone: phone, password: password);
    if (!mounted) return;
    
    _scanController.stop();
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final approvalStatus = result['user']?['driverApprovalStatus'] ?? 'pending';
      if (approvalStatus == 'approved') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryDashboardScreen()));
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryPendingApprovalScreen(
              driverName: result['user']?['name'] ?? 'Partner',
              driverId: result['user']?['_id'] ?? '',
            ),
          ),
        );
      }
    } else {
      _showSnack(result['error'] ?? 'Login failed', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? AppTheme.signalRed : AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPrimeLogo(),
              const SizedBox(height: 50),
              _buildPrimeForm(),
              const SizedBox(height: 24),
              _buildAuthActions(),
              const SizedBox(height: 48),
              _buildOnboardingLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimeLogo() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (_isLoading)
              RotationTransition(
                turns: _scanController,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2), width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(icons.Iconsax.security_safe_copy, color: AppTheme.primaryOrange, size: 40),
            ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
          ],
        ),
        const SizedBox(height: 24),
        Text('NAMBA PRIME', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        Text('DELIVERY PARTNER PORTAL', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildPrimeForm() {
    return Column(
      children: [
        _buildInputField('PHONE NUMBER', _phoneCtrl, icons.Iconsax.mobile_copy, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        _buildInputField('SECURE PASSWORD', _passwordCtrl, icons.Iconsax.lock_copy, isObscure: _obscurePassword, 
          suffix: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(_obscurePassword ? icons.Iconsax.eye_slash_copy : icons.Iconsax.eye_copy, color: AppTheme.lightText, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, IconData icon, {bool isObscure = false, Widget? suffix, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(label, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
          ),
          child: TextField(
            controller: ctrl,
            obscureText: isObscure,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              icon: Icon(icon, color: AppTheme.primaryOrange.withValues(alpha: 0.6), size: 20),
              border: InputBorder.none,
              hintText: '---',
              hintStyle: const TextStyle(color: Colors.black12),
              suffixIcon: suffix,
            ),
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildAuthActions() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryForgotPasswordScreen())),
            child: Text('FORGOT PASSWORD?', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isLoading ? null : _login,
          child: Container(
            width: double.infinity, height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _isLoading ? [Colors.black12, Colors.black26] : [AppTheme.primaryOrange, AppTheme.primaryDeepOrange]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: _isLoading ? [] : [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Center(
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) 
              : Text('SECURE LOGIN', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildOnboardingLink() {
    return Column(
      children: [
        Text('NOT A PARTNER YET?', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryRegisterScreen())),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.darkText,
            elevation: 0,
            side: const BorderSide(color: AppTheme.lightBg),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text('JOIN THE FLEET', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }
}
