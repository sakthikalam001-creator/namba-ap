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
    if (phone.length < 10) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid 10-digit phone number (10 இலக்க எண் தேவை)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.redAccent,
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
      final bool isFallback = res['isDevFallback'] == true || res['otp'] != null;
      final String? returnedOtp = res['otp']?.toString();

      setState(() {
        _otpSent = true;
        _otpCtrl.clear();
        if (isFallback && returnedOtp != null) {
          _simulatedOtp = returnedOtp;
          _otpCtrl.text = returnedOtp;
        } else {
          _simulatedOtp = '';
        }
      });

      _startResendTimer();
      _otpFocusNode.requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isFallback ? Icons.info_outline_rounded : Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFallback
                      ? '⚠️ WhatsApp offline. Auto-filled Test PIN: $returnedOtp'
                      : '✅ Security PIN sent to WhatsApp +91 $phone',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: isFallback ? Colors.amber.shade900 : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: Duration(seconds: isFallback ? 6 : 4),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res?['error'] ?? 'Failed to send security PIN. Please try again.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _verifyOtp() async {
    final pin = _otpCtrl.text.trim();
    if (pin.length < 6) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the full 6-digit Security PIN (6 இலக்க PIN உள்ளிடவும்)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.redAccent,
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
          content: Text('Server connection failed. Try again.', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
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
        );
        if (!mounted) return;
        final hasSavedLocation = auth.hasSetLocation && auth.addresses.any((a) => a.id != 'current_gps');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => hasSavedLocation ? const HomeScreen() : const MapLocationPickerScreen(isInitialSetup: true),
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
          backgroundColor: Colors.redAccent,
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

    return Scaffold(
      backgroundColor: const Color(0xFF1E1B4B),
      body: Stack(
        children: [
          // Background ambient gradient with decorative orbs
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative glowing circles
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            top: 70,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF818CF8).withValues(alpha: 0.15),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Action Bar: Brand Chip + Language Selector Pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF34D399),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NAMBA EXPRESS',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFE0E7FF),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Language Switcher Button
                      InkWell(
                        onTap: () => CustomerLanguageProvider.showLanguageModal(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.translate_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                lang.languageName,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Hero Brand Area (Logo + Title + Tagline)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      // Modern 3D Logo Badge
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4338CA).withValues(alpha: 0.5),
                              blurRadius: 26,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.delivery_dining_rounded,
                                size: 44,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Namba',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang.translate('sign_in_to_continue'),
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Content Card (Never clips on keyboard)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border(top: BorderSide(color: theme.borderCol)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.1),
                          blurRadius: 25,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Heading
                            Text(
                              lang.translate(_otpSent ? 'enter_security_pin' : 'enter_phone_number'),
                              style: GoogleFonts.outfit(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // WhatsApp Verification Badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_rounded,
                                    color: Color(0xFF25D366),
                                    size: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lang.translate('enter_phone_desc'),
                                    style: GoogleFonts.outfit(
                                      color: theme.textSecondary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

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
                              if (_simulatedOtp.isNotEmpty) _buildTestPinBanner(),
                              const SizedBox(height: 16),
                              _buildResendSection(theme, lang),
                            ],

                            const SizedBox(height: 26),

                            // Primary CTA Button
                            _buildCtaButton(theme, lang),

                            const SizedBox(height: 18),

                            // Terms & Privacy Note
                            Center(
                              child: Text(
                                lang.translate('terms_privacy'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: theme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
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
        ],
      ),
    );
  }

  // ── Phone Input Section ────────────────────────────────────────────────────
  Widget _buildPhoneInputSection(ThemeProvider theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Country flag & code badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.borderCol),
              ),
              child: Row(
                children: [
                  const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '+91',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: theme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // 10-Digit Mobile Number Field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _phoneFocusNode.hasFocus ? const Color(0xFF4F46E5) : theme.borderCol,
                    width: _phoneFocusNode.hasFocus ? 1.8 : 1,
                  ),
                ),
                child: TextField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  autofocus: false,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '98765 43210',
                    hintStyle: GoogleFonts.outfit(
                      color: theme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    counterText: '',
                    suffixIcon: _phoneCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.cancel_rounded, size: 18, color: theme.textSecondary),
                            onPressed: () {
                              _phoneCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Phone Chip with Edit Button (During OTP step) ───────────────────────────
  Widget _buildVerifiedPhonePill(ThemeProvider theme, bool isDark, CustomerLanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF4F46E5), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            '+91 ${_phoneCtrl.text}',
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: theme.textPrimary,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _resendTimer?.cancel();
              setState(() {
                _otpSent = false;
                _otpCtrl.clear();
              });
              _phoneFocusNode.requestFocus();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFF4F46E5), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    lang.translate('change_number'),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6-Digit PIN Boxes Widget (Ultra Modern) ─────────────────────────────────
  Widget _buildSixDigitOtpSection(ThemeProvider theme, bool isDark) {
    final text = _otpCtrl.text;

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
          ),
        ),

        // Beautiful 6-cell interactive PIN visual
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final isFilled = index < text.length;
              final isCurrent = index == text.length;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF4F46E5)
                        : (isFilled ? const Color(0xFF4F46E5).withValues(alpha: 0.45) : theme.borderCol),
                    width: isCurrent ? 2.2 : 1.2,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: isFilled
                      ? Text(
                          text[index],
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: theme.textPrimary,
                          ),
                        )
                      : (isCurrent
                          ? Container(
                              width: 2,
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
                                color: theme.borderCol,
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
  }

  // ── WhatsApp Confirmation Alert ────────────────────────────────────────────
  Widget _buildWhatsAppConfirmationBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF25D366), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Security PIN sent to your WhatsApp. Please check and enter it above.',
              style: GoogleFonts.outfit(
                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dev Test PIN Banner ────────────────────────────────────────────────────
  Widget _buildTestPinBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: Colors.amber.shade800, size: 16),
          const SizedBox(width: 8),
          Text(
            'Dev Mock PIN: $_simulatedOtp',
            style: GoogleFonts.outfit(color: Colors.amber.shade800, fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const Spacer(),
          Text('Auto-filled ✓', style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Resend PIN Section with Timer ──────────────────────────────────────────
  Widget _buildResendSection(ThemeProvider theme, CustomerLanguageProvider lang) {
    if (_resendCountdown > 0) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 15, color: theme.textSecondary),
            const SizedBox(width: 6),
            Text(
              '${lang.translate('resend_in')} 0:${_resendCountdown.toString().padLeft(2, '0')}s',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: theme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

  // ── Primary CTA Button ─────────────────────────────────────────────────────
  Widget _buildCtaButton(ThemeProvider theme, CustomerLanguageProvider lang) {
    final isReady = _otpSent ? _otpCtrl.text.length == 6 : _phoneCtrl.text.length == 10;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReady
              ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
              : [const Color(0xFF4F46E5).withValues(alpha: 0.6), const Color(0xFF6366F1).withValues(alpha: 0.6)],
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
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                ],
              ),
      ),
    );
  }
}
