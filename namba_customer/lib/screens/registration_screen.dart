import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'map_location_picker_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String phone;
  final String uid;

  const RegistrationScreen({super.key, required this.phone, required this.uid});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  void _register() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _loading = true);
    
    final apiService = CustomerApiService();
    final res = await apiService.registerCustomer(
      name: _nameCtrl.text.trim(),
      phone: widget.phone.trim(),
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res != null && res['success'] == true) {
      final userData = res['user'];
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.login(
        widget.phone,
        name: userData['name'],
        email: _emailCtrl.text.trim(),
        uid: userData['_id'],
        token: res['token'],
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MapLocationPickerScreen(isInitialSetup: true)),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res?['error'] ?? 'Registration failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;

    final phone = widget.phone.trim();
    final formattedPhone = phone.length == 10
        ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}'
        : '+91 $phone';

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Complete Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: theme.textPrimary),
        ),
        backgroundColor: theme.scaffoldBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'Welcome to Namba!',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: theme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Just a few quick details to set up your account.',
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                color: theme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Verified Phone Number Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.borderCol),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedPhone,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: theme.textPrimary,
                        ),
                      ),
                      Text(
                        'WhatsApp Verified',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF10B981)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Input Fields
            _buildInputField('FULL NAME', _nameCtrl, Icons.person_rounded, theme, hint: 'Enter Full Name'),
            const SizedBox(height: 18),
            _buildInputField('EMAIL ADDRESS', _emailCtrl, Icons.email_rounded, theme, keyboardType: TextInputType.emailAddress, hint: 'Enter Email Address'),
            const SizedBox(height: 36),

            // Submit CTA Button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Start Exploring Namba',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, IconData icon, ThemeProvider theme, {TextInputType? keyboardType, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: theme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.borderCol),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboardType,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: theme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: GoogleFonts.outfit(
                      color: theme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
