import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
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
      if (context.mounted) {
        final provider = Provider.of<DeliveryProvider>(context, listen: false);
        provider.setAuthenticated(true);
        provider.fetchDocumentStatuses();
      }
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
    } else if (result['isDeviceLocked'] == true) {
      _showDeviceLockedDialog(result['error'] ?? 'This account is currently active on another device.');
    } else {
      _showSnack(result['error'] ?? 'Login failed', isError: true);
    }
  }

  void _showDeviceLockedDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.signalRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.phonelink_lock_rounded, color: AppTheme.signalRed, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Device Locked',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security Rule: Only 1 active mobile phone allowed per rider account.',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('UNDERSTOOD', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
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
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.3), width: 3, strokeAlign: BorderSide.strokeAlignOutside),
                  ),
                ),
              ),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/rider_logo.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.two_wheeler_rounded, color: AppTheme.primaryOrange, size: 40),
                  ),
                ),
              ),
            ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
          ],
        ),
        const SizedBox(height: 20),
        Text('NAMBA DELIVERY', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
