import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import '../profile/document_status_screen.dart';

class DeliveryRegisterScreen extends StatefulWidget {
  const DeliveryRegisterScreen({super.key});

  @override
  State<DeliveryRegisterScreen> createState() => _DeliveryRegisterScreenState();
}

class _DeliveryRegisterScreenState extends State<DeliveryRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  String _selectedVehicle = 'bike';
  bool _obscurePassword = true;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _vehicleTypes = [
    {'value': 'bike', 'label': 'MOTORBIKE', 'icon': icons.Iconsax.direct_right_copy},
    {'value': 'scooter', 'label': 'SCOOTER', 'icon': icons.Iconsax.direct_right_copy},
    {'value': 'bicycle', 'label': 'BICYCLE', 'icon': icons.Iconsax.direct_right_copy},
    {'value': 'car', 'label': 'FOUR WHEELER', 'icon': icons.Iconsax.car_copy},
    {'value': 'auto', 'label': 'AUTO RICKSHAW', 'icon': icons.Iconsax.car_copy},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await DeliveryAuthService.registerDriver(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
      vehicleType: _selectedVehicle,
      vehicleNumber: _vehicleNumberCtrl.text.trim().toUpperCase(),
      licenseNumber: _licenseCtrl.text.trim().toUpperCase(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (context.mounted) {
        final provider = Provider.of<DeliveryProvider>(context, listen: false);
        provider.setAuthenticated(true);
        provider.fetchDocumentStatuses();
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DocumentStatusScreen()),
      );
    } else {
      _showSnack(result['error'] ?? 'Registration failed', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: isError ? AppTheme.signalRed : AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPrimeBackButton(),
                const SizedBox(height: 32),
                _buildPrimeHeader(),
                const SizedBox(height: 40),
                _buildPersonalSection(),
                const SizedBox(height: 32),
                _buildVehicleSection(),
                const SizedBox(height: 48),
                _buildRegisterButton(),
                const SizedBox(height: 32),
                _buildLoginLink(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimeBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 18),
      ),
    ).animate().fadeIn();
  }

  Widget _buildPrimeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(icons.Iconsax.user_add_copy, color: AppTheme.primaryOrange, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PARTNER ENROLLMENT', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  Text('Registration Form', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Complete your profile submission. Account verification typically takes 24 hours.',
          style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, fontWeight: FontWeight.w600, height: 1.5),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildPersonalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('PERSONAL DETAILS', icons.Iconsax.personalcard_copy),
        const SizedBox(height: 16),
        _primeField(
          controller: _nameCtrl,
          hint: 'Full Name',
          icon: icons.Iconsax.user_copy,
          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
        ),
        const SizedBox(height: 12),
        _primeField(
          controller: _phoneCtrl,
          hint: 'Phone Number (10 digits)',
          icon: icons.Iconsax.mobile_copy,
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Phone number required';
            if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Invalid phone number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        _primeField(
          controller: _passwordCtrl,
          hint: 'Secure Password',
          icon: icons.Iconsax.lock_copy,
          obscureText: _obscurePassword,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(_obscurePassword ? icons.Iconsax.eye_slash_copy : icons.Iconsax.eye_copy, color: AppTheme.lightText, size: 20),
          ),
          validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildVehicleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('VEHICLE & LICENSE', icons.Iconsax.truck_copy),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.softShadow),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVehicle,
              dropdownColor: Colors.white,
              style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w700),
              icon: const Icon(icons.Iconsax.arrow_down_copy, color: AppTheme.lightText, size: 18),
              isExpanded: true,
              items: _vehicleTypes.map((v) {
                return DropdownMenuItem<String>(
                  value: v['value'] as String,
                  child: Row(
                    children: [
                      Icon(v['icon'] as IconData, color: AppTheme.accentGreen, size: 18),
                      const SizedBox(width: 12),
                      Text(v['label'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedVehicle = val!),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _primeField(
          controller: _vehicleNumberCtrl,
          hint: 'Vehicle Number (e.g. TN01AB1234)',
          icon: icons.Iconsax.direct_right_copy,
          textCapitalization: TextCapitalization.characters,
          validator: (v) => v == null || v.trim().isEmpty ? 'Vehicle number required' : null,
        ),
        const SizedBox(height: 12),
        _primeField(
          controller: _licenseCtrl,
          hint: 'Driving License Number',
          icon: icons.Iconsax.card_copy,
          textCapitalization: TextCapitalization.characters,
          validator: (v) => v == null || v.trim().isEmpty ? 'License number required' : null,
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Text(title, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppTheme.darkText.withValues(alpha: 0.05))),
      ],
    );
  }

  Widget _primeField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.softShadow),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        validator: validator,
        style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 15, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          icon: Icon(icon, color: AppTheme.primaryOrange.withValues(alpha: 0.6), size: 18),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, fontWeight: FontWeight.w600),
          suffixIcon: suffixIcon,
          errorStyle: GoogleFonts.outfit(color: AppTheme.signalRed, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _register,
      child: Container(
        height: 60, width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: _isLoading
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
            : Center(
                child: Text('SUBMIT APPLICATION', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already a partner? ', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Login here', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}
