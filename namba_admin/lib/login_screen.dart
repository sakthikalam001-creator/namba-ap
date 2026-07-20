import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/admin_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic> user) onLogin;
  const AdminLoginScreen({super.key, required this.onLogin});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  String _role = 'superadmin';
  final _emailCtrl = TextEditingController(text: '');
  final _passCtrl = TextEditingController(text: '');
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentialsAndAutoLogin();
  }

  Future<void> _loadSavedCredentialsAndAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isManualLogout = prefs.getBool('admin_manual_logout') ?? false;
      final savedEmail = prefs.getString('saved_admin_email') ?? 'sakthikalam001@gmail.com';
      final savedPass = prefs.getString('saved_admin_password') ?? '';

      if (mounted) {
        setState(() {
          _emailCtrl.text = savedEmail;
          if (savedPass.isNotEmpty) _passCtrl.text = savedPass;
        });
      }

      if (!isManualLogout && savedEmail.isNotEmpty && savedPass.isNotEmpty) {
        _login(isAuto: true);
      }
    } catch (e) {
      debugPrint('Auto login load error: $e');
    }
  }

  void _login({bool isAuto = false}) async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) return;

    setState(() => _loading = true);

    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1';
      
      final res = await http.post(
        Uri.parse('$baseUrl/auth/admin-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final userData = Map<String, dynamic>.from(data['user']);
        userData['token'] = data['token']; // Store token for API authorization

        // Save credentials & reset manual logout flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_admin_email', email);
        await prefs.setString('saved_admin_password', password);
        await prefs.setBool('admin_manual_logout', false);

        widget.onLogin(userData);
      } else {
        if (!isAuto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data['error'] ?? 'Invalid credentials!'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      if (!isAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Server connection failed'),
          backgroundColor: Colors.red.shade800,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = _role == 'superadmin';
    return Scaffold(
      backgroundColor: AdminColors.sidebarBg,
      body: Stack(
        children: [
          // Elegant Background Background
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 500, height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AdminColors.primaryIndigo.withOpacity(0.15),
                    AdminColors.primaryIndigo.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150, left: -150,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AdminColors.primaryIndigo.withOpacity(0.1),
                    AdminColors.primaryIndigo.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with glass effect
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                      child: Icon(
                        isSuperAdmin ? Icons.admin_panel_settings_rounded : Icons.dashboard_rounded,
                        color: Colors.white, size: 54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('NAMBA', style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    Text(
                      isSuperAdmin ? 'SUPER ADMIN CONSOLE' : 'OPERATIONS PANEL',
                      style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3),
                    ),
                    const SizedBox(height: 48),

                    // Role Toggle
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        _roleBtn('admin', 'Admin', Icons.manage_accounts_rounded),
                        _roleBtn('superadmin', 'Super Admin', Icons.admin_panel_settings_rounded),
                      ]),
                    ),
                    const SizedBox(height: 32),

                    // Login Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 20))
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Enterprise Access', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
                        const SizedBox(height: 8),
                        Text(
                          'Please sign in to continue to your dashboard',
                          style: GoogleFonts.outfit(fontSize: 13, color: AdminColors.textSub, height: 1.5),
                        ),
                        const SizedBox(height: 32),
                        _field(_emailCtrl, 'Email Address', Icons.alternate_email_rounded),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          onSubmitted: (_) => _login(),
                          decoration: _dec('Account Password', Icons.lock_outline_rounded, suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: AdminColors.primaryIndigo.withOpacity(0.6)),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity, height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.primaryIndigo,
                              foregroundColor: Colors.white, elevation: 8,
                              shadowColor: AdminColors.primaryIndigo.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Text('Sign In to Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 48),
                    Text('Namba Enterprise Systems v1.0', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBtn(String role, String label, IconData icon) {
    final active = _role == role;
    return Expanded(child: GestureDetector(
      onTap: () {
        setState(() {
          _role = role;
          _emailCtrl.clear();
          _passCtrl.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? AdminColors.primaryIndigo : Colors.white.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13,
              color: active ? AdminColors.primaryIndigo : Colors.white.withOpacity(0.5))),
        ]),
      ),
    ));
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(controller: ctrl, decoration: _dec(hint, icon));
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint, prefixIcon: Icon(icon, size: 20, color: AdminColors.primaryIndigo.withOpacity(0.5)),
      suffixIcon: suffix,
      filled: true, fillColor: AdminColors.background,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminColors.primaryIndigo, width: 1.5)),
    );
  }
}
