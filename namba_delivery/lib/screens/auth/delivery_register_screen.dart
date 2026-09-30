import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/delivery_auth_service.dart';
import '../profile/document_status_screen.dart';

class CapitalizeWordsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final StringBuffer buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < newValue.text.length; i++) {
      final String char = newValue.text[i];
      if (char == ' ' || char == '\t' || char == '\n' || char == '-' || char == '.') {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    return newValue.copyWith(
      text: buffer.toString(),
      selection: newValue.selection,
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

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

  String _selectedVehicle = 'Motorcycle';
  bool _isLoading = false;
  bool _obscurePassword = true;

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

  String _capitalizeWords(String input) {
    if (input.trim().isEmpty) return input.trim();
    return input.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final formattedName = _capitalizeWords(_nameCtrl.text);
    final result = await DeliveryAuthService.registerDriver(
      name: formattedName,
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
        MaterialPageRoute(
          builder: (_) => const DocumentStatusScreen(),
        ),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildPrimeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'STEP 1 OF 2 : PARTNER REGISTRATION',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryOrange,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Join Delivery Fleet',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your vehicle & license information below to proceed to instant document upload.',
          style: GoogleFonts.outfit(
            color: const Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
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
          textCapitalization: TextCapitalization.words,
          inputFormatters: [CapitalizeWordsInputFormatter()],
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
            child: Icon(_obscurePassword ? icons.Iconsax.eye_slash_copy : icons.Iconsax.eye_copy, color: const Color(0xFF94A3B8), size: 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVehicle,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 14.5, fontWeight: FontWeight.w700),
              icon: const Icon(icons.Iconsax.arrow_down_copy, color: Color(0xFF64748B), size: 18),
              isExpanded: true,
              items: _vehicleTypes.map((v) {
                return DropdownMenuItem<String>(
                  value: v['value'] as String,
                  child: Row(
                    children: [
                      Icon(v['icon'] as IconData, color: AppTheme.primaryOrange, size: 18),
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
          inputFormatters: [UpperCaseTextFormatter()],
          validator: (v) => v == null || v.trim().isEmpty ? 'Vehicle number required' : null,
        ),
        const SizedBox(height: 12),
        _primeField(
          controller: _licenseCtrl,
          hint: 'Driving License Number',
          icon: icons.Iconsax.card_copy,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter()],
          validator: (v) => v == null || v.trim().isEmpty ? 'License number required' : null,
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryOrange, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            color: const Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
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
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        validator: validator,
        style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 14.5, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: Icon(icon, color: AppTheme.primaryOrange, size: 20),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w500),
          suffixIcon: suffixIcon,
          errorStyle: GoogleFonts.outfit(color: AppTheme.signalRed, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _register,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _isLoading
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CONTINUE TO DOCUMENT UPLOAD',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already a partner? ', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Login here', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}
