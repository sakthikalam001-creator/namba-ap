import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'vendor_login_screen.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String storeName;
  final String vendorId;

  const WaitingApprovalScreen({
    super.key,
    required this.storeName,
    required this.vendorId,
  });

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animated pulsing icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.05),
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Iconsax.timer_1,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 48),

              Text(
                'Waiting for Approval',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E1B4B),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),

              const SizedBox(height: 12),

              Text(
                '"${widget.storeName}"',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7C3AED),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 20),

              Text(
                'நம்ம Super Admin உங்கள் கடையை verify பண்ணி approve செய்வார். 24-48 மணி நேரத்தில் உங்களுக்கு தெரியும்!',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 48),

              // Status steps
              _buildStatusStep(
                icon: Iconsax.document_text,
                title: 'Application Submitted',
                subtitle: 'Your store details are received',
                isCompleted: true,
              ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.2),
              const SizedBox(height: 12),
              _buildStatusStep(
                icon: Iconsax.shield_search,
                title: 'Under Review',
                subtitle: 'Admin is verifying your details',
                isCompleted: false,
                isActive: true,
              ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2),
              const SizedBox(height: 12),
              _buildStatusStep(
                icon: Iconsax.verify,
                title: 'Store Activated',
                subtitle: 'Start accepting orders!',
                isCompleted: false,
              ).animate().fadeIn(delay: 900.ms).slideX(begin: -0.2),

              const SizedBox(height: 48),

              // Logout button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const VendorLoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(
                    'Back to Login',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isActive = false,
  }) {
    Color iconColor;
    Color bgColor;
    Color borderColor;

    if (isCompleted) {
      iconColor = Colors.white;
      bgColor = const Color(0xFF059669);
      borderColor = const Color(0xFF059669);
    } else if (isActive) {
      iconColor = const Color(0xFF7C3AED);
      bgColor = const Color(0xFF7C3AED).withOpacity(0.1);
      borderColor = const Color(0xFF7C3AED);
    } else {
      iconColor = Colors.grey.shade400;
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(isCompleted ? Icons.check_rounded : icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF111827))),
                Text(subtitle,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'IN PROGRESS',
                style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF7C3AED),
                    letterSpacing: 1),
              ),
            ),
        ],
      ),
    );
  }
}

