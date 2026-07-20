import 'dart:convert';
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
        const SnackBar(content: Text('Enter a valid phone number (10 digits) and password (min 6 chars)')),
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
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        if (user['role'] != 'vendor') {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only vendor accounts can log in here.')),
          );
          return;
        }

        Map<String, dynamic>? vendor = data['vendor'];
        
        if (vendor == null) {
          final statusResponse = await http.get(
            Uri.parse('$_baseUrl/admin/vendors/status-by-phone/$phone'),
          ).timeout(const Duration(seconds: 4));
          final statusData = jsonDecode(statusResponse.body);
          if (statusResponse.statusCode == 200 && statusData['success'] == true) {
            vendor = statusData['data'];
          }
        }
        
        if (vendor != null) {
          _proceedWithVendorProfile(vendor, phone, data['token']);
          return;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Login failed.')),
        );
        return;
      }
    } catch (e) {
      debugPrint('Login API unreachable, using demo vendor login: $e');
      
      // Fallback: Enable Demo Mode so user can enter dashboard even if backend server is offline
      final phoneSuffix = phone.length >= 4 ? phone.substring(phone.length - 4) : '0000';
      final demoVendor = {
        '_id': 'vendor_demo_$phoneSuffix',
        'storeName': 'Namba Vendor Store',
        'ownerName': 'Vendor Partner',
        'phone': phone,
        'email': 'vendor@namba.com',
        'address': 'Main Road, Anna Nagar',
        'city': 'Chennai',
        'pincode': '600040',
        'category': 'Restaurant',
        'approvalStatus': 'approved',
        'isOpen': true,
        'subscriptionPlan': 'Pro Plan',
        'isSubscribed': true,
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logging in... (Demo Mode)'),
            backgroundColor: Color(0xFF4F46E5),
            duration: Duration(seconds: 2),
          ),
        );
      }

      _proceedWithVendorProfile(demoVendor, phone, 'demo_token_$phoneSuffix');
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proceedWithVendorProfile(Map<String, dynamic> vendor, String phone, String? token) async {
    final status = vendor['approvalStatus'];

    if (!mounted) return;

    if (status == 'pending') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => WaitingApprovalScreen(
          storeName: vendor['storeName'] ?? 'Store',
          vendorId: vendor['_id'] ?? '',
        )),
      );
    } else if (status == 'approved') {
      final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
      orderProvider.setProfile(VendorProfileModel.fromJson(vendor));
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isVendorLoggedIn', true);
        await prefs.setString('vendorPhone', phone);
        if (token != null) {
          await prefs.setString('vendorToken', token);
        }
      } catch (_) {}
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your account was rejected: ${vendor['rejectionReason'] ?? "Contact Support"}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppTheme.primaryOrange.withValues(alpha: 0.12), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF4F46E5).withValues(alpha: 0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 10)),
                        BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 15, spreadRadius: 5, offset: const Offset(0, -5)),
                      ],
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBrandIcon(),
                        const SizedBox(height: 16),
                        Text(
                          'Namba Delivery\nVendor Portal',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkText,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideX(),
                        const SizedBox(height: 6),
                        Text(
                          'Empower your business with Namba logistics and analytics.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.mediumText,
                            height: 1.35,
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideX(),
                        const SizedBox(height: 20),
                        _buildPhoneField(),
                        const SizedBox(height: 14),
                        _buildPasswordField(),
                        const SizedBox(height: 18),
                        _buildLoginButton(),
                        const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryOrange, AppTheme.primaryDeepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: const Icon(Iconsax.shop, color: Colors.white, size: 30),
    ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registered Phone Number',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.darkText),
            decoration: InputDecoration(
              hintText: '98765 43210',
              hintStyle: GoogleFonts.outfit(color: AppTheme.lightText),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Iconsax.call, color: AppTheme.primaryOrange, size: 20),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Password',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: true,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.darkText),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, letterSpacing: 2),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Iconsax.lock, color: AppTheme.primaryOrange, size: 20),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              );
            },
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryOrange,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.darkText,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                'Enter Dashboard',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    ).animate().fadeIn(delay: 600.ms).scale();
  }

  Widget _buildRegisterSection() {
    return Column(
      children: [
        const Divider(color: Colors.black12, height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have a store? ",
              style: GoogleFonts.outfit(color: AppTheme.mediumText, fontWeight: FontWeight.w600, fontSize: 13.5),
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
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 700.ms);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
