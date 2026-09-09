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

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        title: Text('Complete Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: theme.textPrimary)),
        backgroundColor: theme.scaffoldBg,
        elevation: 0,
        foregroundColor: theme.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Namba!',
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: theme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Just a few more details to get you started.',
              style: GoogleFonts.outfit(fontSize: 15, color: theme.textSecondary),
            ),
            const SizedBox(height: 40),
            _buildInputField('Full Name', _nameCtrl, Icons.person_outline_rounded, theme),
            const SizedBox(height: 20),
            _buildInputField('Email Address', _emailCtrl, Icons.email_outlined, theme, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Start Ordering', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, IconData icon, ThemeProvider theme, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: theme.textSecondary, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.borderCol),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: theme.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
        ),
      ],
    );
  }
}
