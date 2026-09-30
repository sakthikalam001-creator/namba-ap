import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'registration_screen.dart';
import 'map_location_picker_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  bool _otpSent = false;
  bool _loading = false;
  String _simulatedOtp = '';
  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(() => setState(() {}));
    _otpCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);

    if (phone.length < 10) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.isTamil
                      ? 'தயவுசெய்து 10 இலக்க மொபைல் எண்ணை உள்ளிடவும்'
                      : (lang.isTanglish
                          ? '10 digit phone number-ai enter seiyavum'
                          : 'Please enter a valid 10-digit phone number'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _loading = true);

    final apiService = CustomerApiService();
    final res = await apiService.sendSecurityPin(phone);

    if (!mounted) return;
    setState(() => _loading = false);

    if (res != null && res['success'] == true) {
      final String? returnedOtp = res['otp']?.toString();

      setState(() {
        _otpSent = true;
        _otpCtrl.clear();
        if (returnedOtp != null && returnedOtp.isNotEmpty) {
          _simulatedOtp = returnedOtp;
          _otpCtrl.text = returnedOtp;
        } else {
          _simulatedOtp = '';
        }
      });

      _startResendTimer();
      _otpFocusNode.requestFocus();

      final String successMsg = returnedOtp != null
          ? '✅ Security PIN sent! Auto-filled: $returnedOtp'
          : '✅ Security PIN sent to WhatsApp +91 $phone';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successMsg,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res?['error'] ?? 'Failed to send security PIN. Please try again.',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _verifyOtp() async {
    final pin = _otpCtrl.text.trim();
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);

    if (pin.length < 6) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.text(
                    en: 'Please enter the full 6-digit Security PIN',
                    ta: 'தயவுசெய்து 6 இலக்க பாதுகாப்புக் குறியீட்டு எண்ணை உள்ளிடவும்',
                    tanglish: '6 digit PIN enter seiyavum',
                  ),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _loading = true);

    final phone = _phoneCtrl.text.trim();
    final apiService = CustomerApiService();
    final res = await apiService.verifySecurityPin(phone, pin);

    if (!mounted) return;
    setState(() => _loading = false);

    if (res == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Server connection failed. Try again.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (res['success'] == true) {
      HapticFeedback.mediumImpact();
      if (res['isNewUser'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => RegistrationScreen(phone: phone, uid: phone)),
          (_) => false,
        );
      } else {
        final userData = res['user'];
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.login(
          phone,
          name: userData['name'],
          email: userData['email'],
          uid: userData['_id'],
          token: res['token'],
          savedAddresses: userData['savedAddresses'],
        );
        if (!mounted) return;
        final hasSavedLocation = auth.hasSetLocation && auth.addresses.any((a) => a.id != 'current_gps');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => hasSavedLocation
                ? const HomeScreen()
                : const MapLocationPickerScreen(isInitialSetup: true),
          ),
          (_) => false,
        );
      }
    } else {
      HapticFeedback.heavyImpact();
      final msg = res['error'] ?? 'Verification failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);
    final isDark = theme.isDarkMode;

    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;
    final isKeyboardOpen = media.viewInsets.bottom > 0;
    final isCompact = screenHeight < 720;
    final double logoSize = isCompact ? 64.0 : 80.0;

    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── 1. Immersive Luxury Midnight Gradient ────────────────────────
            Container(
              height: screenHeight * 0.46,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0A0E1A),
                    Color(0xFF1E1B4B),
                    Color(0xFF312E81),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // ── 2. Ambient Floating Light Orbs ───────────────────────────────
            Positioned(
              top: -30,
              left: -30,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: 0.28),
                      const Color(0xFF4F46E5).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 60,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF6D00).withValues(alpha: 0.20),
                      const Color(0xFFFF6D00).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // ── 3. Main Content Container ────────────────────────────────────
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      // Top Action Bar: Brand Badge & Frosted Language Switcher
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isCompact ? 6 : 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Namba Express Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF10B981),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'NAMBA EXPRESS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFE2E8F0),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Frosted Language Switcher Chip
                            InkWell(
                              onTap: () => CustomerLanguageProvider.showLanguageModal(context),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.translate_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang.languageName,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Hero Emblem & Brand Typography (Collapses smoothly on keyboard)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: isKeyboardOpen ? 4 : (isCompact ? 6 : 12),
                        ),
                        child: isKeyboardOpen
                            // Compact brand pill during keyboard focus
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/app_logo.png',
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.delivery_dining_rounded,
                                          size: 22,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Namba',
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              )
                            // Full Luxury 3D Emblem when keyboard is dismissed
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: logoSize,
                                    height: logoSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                                          blurRadius: isCompact ? 18 : 26,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                                          blurRadius: isCompact ? 16 : 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/app_logo.png',
                                        width: logoSize,
                                        height: logoSize,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: const Color(0xFF1E1B4B),
                                          child: Icon(
                                            Icons.delivery_dining_rounded,
                                            size: logoSize * 0.55,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 6 : 10),
                                  Text(
                                    'Namba',
                                    style: GoogleFonts.outfit(
                                      fontSize: isCompact ? 26 : 30,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lang.translate('sign_in_to_continue'),
                                    style: GoogleFonts.outfit(
                                      fontSize: isCompact ? 13 : 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      SizedBox(height: isKeyboardOpen ? 4 : (isCompact ? 6 : 12)),

                      // ── Bottom Elevated Form Card ───────────────────────────
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF111827) : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
                                blurRadius: 30,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                            child: SingleChildScrollView(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                (screenWidth * 0.06).clamp(18.0, 24.0),
                                isCompact ? 12 : 16,
                                (screenWidth * 0.06).clamp(18.0, 24.0),
                                16 + media.padding.bottom,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Card handle pill
                                  Center(
                                    child: Container(
                                      width: 42,
                                      height: 4.5,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 14 : 18),

                                  // Heading
                                  Text(
                                    lang.translate(_otpSent ? 'enter_security_pin' : 'enter_phone_number'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Executive WhatsApp Security Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                                          : const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _otpSent
                                                ? lang.text(
                                                    en: 'Enter the 6-digit PIN sent to your WhatsApp',
                                                    ta: 'வாட்ஸ்அப்பில் அனுப்பப்பட்ட 6 இலக்க பாதுகாப்புக் குறியீட்டை உள்ளிடவும்',
                                                    tanglish: 'WhatsApp-la anupuna 6-digit PIN enter pannunga',
                                                  )
                                                : lang.translate('enter_phone_desc'),
                                            style: GoogleFonts.outfit(
                                              color: isDark
                                                  ? const Color(0xFF6EE7B7)
                                                  : const Color(0xFF065F46),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.lock_outline_rounded,
                                          color: Color(0xFF10B981),
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  // STEP 1: Phone Input Field
                                  if (!_otpSent) ...[
                                    _buildPhoneInputSection(theme, isDark),
                                  ] else ...[
                                    // STEP 2: Phone Pill + 6-Digit OTP Cells
                                    _buildVerifiedPhonePill(theme, isDark, lang),
                                    const SizedBox(height: 20),
                                    _buildSixDigitOtpSection(theme, isDark),
                                    const SizedBox(height: 14),
                                    _buildWhatsAppConfirmationBanner(isDark),
                                    if (_simulatedOtp.isNotEmpty) _buildTestPinBanner(lang),
                                    const SizedBox(height: 16),
                                    _buildResendSection(theme, lang),
                                  ],

                                  const SizedBox(height: 26),

                                  // Primary Action CTA Button
                                  _buildCtaButton(theme, lang),

                                  const SizedBox(height: 18),

                                  // Terms & Privacy Note
                                  Center(
                                    child: Text(
                                      lang.translate('terms_privacy'),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Trust Footer
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock_rounded,
                                          size: 12,
                                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '256-Bit SSL Encrypted • Namba Ecosystem',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Unified Phone Input Section ────────────────────────────────────────────
  Widget _buildPhoneInputSection(ThemeProvider theme, bool isDark) {
    final isComplete = _phoneCtrl.text.trim().length == 10;
    final isFocused = _phoneFocusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFF4F46E5)
                  : (isComplete ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              width: isFocused || isComplete ? 2.0 : 1.2,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Row(
            children: [
              // Indian Flag + Prefix
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    '+91',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Vertical divider
              Container(
                width: 1.5,
                height: 28,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 14),

              // 10-Digit Mobile Number Field
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: 2.0,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintText: '98765 43210',
                    hintStyle: GoogleFonts.outfit(
                      color: (isDark ? Colors.white : const Color(0xFF0F172A)).withValues(alpha: 0.35),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                    counterText: '',
                  ),
                ),
              ),

              // Clear or Complete Badge
              if (isComplete)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                )
              else if (_phoneCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _phoneCtrl.clear();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Phone Chip with Edit Button (During OTP step) ───────────────────────────
  Widget _buildVerifiedPhonePill(ThemeProvider theme, bool isDark, CustomerLanguageProvider lang) {
    final phone = _phoneCtrl.text.trim();
    final formattedPhone = phone.length == 10
        ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}'
        : '+91 $phone';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedPhone,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  lang.isTamil ? 'வாட்ஸ்அப் சரிபார்க்கப்பட்டது' : 'WhatsApp Verified Number',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _resendTimer?.cancel();
                setState(() {
                  _otpSent = false;
                  _otpCtrl.clear();
                });
                _phoneFocusNode.requestFocus();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_rounded, color: Color(0xFF4F46E5), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      lang.translate('change_number'),
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6-Digit PIN Boxes Widget (Fintech / Executive Style) ────────────────────
  Widget _buildSixDigitOtpSection(ThemeProvider theme, bool isDark) {
    final text = _otpCtrl.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final spacing = (totalWidth * 0.02).clamp(4.0, 8.0);
        final cellWidth = ((totalWidth - (5 * spacing)) / 6).clamp(32.0, 48.0);
        final cellHeight = (cellWidth * 1.2).clamp(44.0, 58.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Hidden transparent textfield that intercepts input, keyboard & paste
            Opacity(
              opacity: 0.0,
              child: TextField(
                controller: _otpCtrl,
                focusNode: _otpFocusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (val) {
                  setState(() {});
                  if (val.length == 6) {
                    _verifyOtp();
                  }
                },
              ),
            ),

            // 6-cell interactive PIN visual
            GestureDetector(
              onTap: () => _otpFocusNode.requestFocus(),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final isFilled = index < text.length;
                  final isCurrent = index == text.length;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: cellWidth,
                    height: cellHeight,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                          : (isFilled
                              ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                              : (isDark
                                  ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                                  : const Color(0xFFF8FAFC))),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFF4F46E5)
                            : (isFilled
                                ? const Color(0xFF4F46E5).withValues(alpha: 0.6)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        width: isCurrent ? 2.2 : 1.2,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: isFilled
                          ? Text(
                              text[index],
                              style: GoogleFonts.outfit(
                                fontSize: (cellWidth * 0.48).clamp(18.0, 23.0),
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            )
                          : (isCurrent
                              ? Container(
                                  width: 2.2,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                )
                              : Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                )),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── WhatsApp Confirmation Alert ────────────────────────────────────────────
  Widget _buildWhatsAppConfirmationBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF25D366),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Security PIN sent to WhatsApp. Please check and enter it above.',
              style: GoogleFonts.outfit(
                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Instant Auto-Fill PIN Banner (Testing helper) ──────────────────────────
  Widget _buildTestPinBanner(CustomerLanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFF4F46E5), size: 16),
          const SizedBox(width: 8),
          Text(
            '${lang.translate('instant_autofill_pin')}: $_simulatedOtp',
            style: GoogleFonts.outfit(
              color: const Color(0xFF4F46E5),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Auto-filled ✓',
              style: GoogleFonts.outfit(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Resend PIN Section with Timer ──────────────────────────────────────────
  Widget _buildResendSection(ThemeProvider theme, CustomerLanguageProvider lang) {
    final isDark = theme.isDarkMode;

    if (_resendCountdown > 0) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 15,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                '${lang.translate('resend_in')} 0:${_resendCountdown.toString().padLeft(2, '0')}s',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: TextButton.icon(
        onPressed: _loading ? null : _sendOtp,
        icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF4F46E5)),
        label: Text(
          lang.translate('resend_pin'),
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4F46E5),
          ),
        ),
      ),
    );
  }

  // ── Primary Action Button (Auto-Adjusts to every Mobile Screen) ────────────
  Widget _buildCtaButton(ThemeProvider theme, CustomerLanguageProvider lang) {
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;
    final isReady = _otpSent ? _otpCtrl.text.length == 6 : _phoneCtrl.text.length == 10;
    final buttonHeight = (screenHeight * 0.066).clamp(48.0, 56.0);
    final fontSize = (screenWidth * 0.042).clamp(14.5, 16.5);

    return Container(
      width: double.infinity,
      height: buttonHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReady
              ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
              : [
                  const Color(0xFF4F46E5).withValues(alpha: 0.5),
                  const Color(0xFF6366F1).withValues(alpha: 0.5),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _otpSent ? lang.translate('verify_pin') : lang.translate('send_pin'),
                    style: GoogleFonts.outfit(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _otpSent ? Icons.verified_user_rounded : Icons.arrow_forward_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }
}
