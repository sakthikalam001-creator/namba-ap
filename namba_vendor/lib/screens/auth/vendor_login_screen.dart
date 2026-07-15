import 'dart:convert';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import '../../models/vendor_profile_model.dart';
import '../../services/vendor_order_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:http/http.dart' as http;
import 'vendor_registration_screen.dart';
import 'waiting_approval_screen.dart';
import 'forgot_password_screen.dart';

class VendorLoginScreen extends StatefulWidget {
  const VendorLoginScreen({super.key});

  @override
  State<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends State<VendorLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1';

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.length < 10 || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number and password (min 6 chars)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        if (user['role'] != 'vendor') {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only vendor accounts can log in here.')),
          );
          return;
        }

        // Use vendor profile from login response if available, otherwise fallback to check
        Map<String, dynamic>? vendor = data['vendor'];
        
        if (vendor == null) {
          // Fetch vendor profile status if not in login response (fallback)
          final statusResponse = await http.get(
            Uri.parse('$_baseUrl/admin/vendors/status-by-phone/$phone'),
          );
          final statusData = jsonDecode(statusResponse.body);
          if (statusResponse.statusCode == 200 && statusData['success'] == true) {
            vendor = statusData['data'];
          }
        }
        
        if (vendor != null) {
          final status = vendor['approvalStatus'];

          if (!mounted) return;

          if (status == 'pending') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => WaitingApprovalScreen(
                storeName: vendor!['storeName'],
                vendorId: vendor['_id'],
              )),
            );
          } else if (status == 'approved') {
            final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
            orderProvider.setProfile(VendorProfileModel.fromJson(vendor));
            
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isVendorLoggedIn', true);
              await prefs.setString('vendorPhone', phone);
              if (data['token'] != null) {
                await prefs.setString('vendorToken', data['token']);
              }
            } catch (_) {}
            
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainNavigationShell()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Your account was rejected: ${vendor['rejectionReason']}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find vendor profile.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Login failed.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error. Is the backend running?')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Decorative deep background elements
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppTheme.primaryOrange.withValues(alpha: 0.15), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF4F46E5).withValues(alpha: 0.1), Colors.transparent],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 20)),
                        BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 10, offset: const Offset(0, -10)),
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBrandIcon(),
                        const SizedBox(height: 32),
                        Text(
                          'Namba Delivery\nVendor Portal',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkText,
                            height: 1.1,
                            letterSpacing: -1,
                          ),
                        ).animate().fadeIn(delay: 400.ms).slideX(),
                        const SizedBox(height: 12),
                        Text(
                          'Empower your business with Namba logistics and analytics.',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mediumText,
                            height: 1.4,
                          ),
                        ).animate().fadeIn(delay: 600.ms).slideX(),
                        const SizedBox(height: 48),
                        _buildPhoneField(),
                        const SizedBox(height: 24),
                        _buildPasswordField(),
                        const SizedBox(height: 40),
                        _buildLoginButton(),
                        const SizedBox(height: 40),
                        _buildRegisterSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandIcon() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryOrange, AppTheme.primaryDeepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: const Icon(Iconsax.shop, color: Colors.white, size: 40),
    ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack);
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registered Phone Number',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 2),
          ),
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.darkText),
            decoration: InputDecoration(
              hintText: '99999 99999',
              hintStyle: GoogleFonts.outfit(color: AppTheme.lightText),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Iconsax.call, color: AppTheme.primaryOrange, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Password',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 2),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: true,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.darkText),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, letterSpacing: 2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Iconsax.lock, color: AppTheme.primaryOrange, size: 22),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              );
            },
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryOrange,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkText,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(vertical: 22),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : Text(
                'Enter Dashboard',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    ).animate().fadeIn(delay: 1000.ms).scale();
  }

  Widget _buildRegisterSection() {
    return Column(
      children: [
        const Divider(color: Colors.black12),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have a store? ",
              style: GoogleFonts.outfit(color: AppTheme.mediumText, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const VendorRegistrationScreen()),
                );
              },
              child: Text(
                'Register Now',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 1100.ms);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

