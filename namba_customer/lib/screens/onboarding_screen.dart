import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _current = 0;

  final List<_OnboardData> _pages = const [
    _OnboardData(
      icon: Icons.storefront_rounded,
      color: Color(0xFF5B4DFF),
      bgCircleColor: Color(0xFFEEF2FF),
      title: 'All Stores, One App',
      subtitle: 'Order groceries, food, medicines and bakery items from nearby stores — all in one place.',
    ),
    _OnboardData(
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFF5B4DFF),
      bgCircleColor: Color(0xFFEEF2FF),
      title: 'Fast & Reliable Delivery',
      subtitle: 'Get your orders delivered to your doorstep quickly by our trusted delivery partners.',
    ),
    _OnboardData(
      icon: Icons.location_on_rounded,
      color: Color(0xFF5B4DFF),
      bgCircleColor: Color(0xFFEEF2FF),
      title: 'Live Order Tracking',
      subtitle: 'Track your order in real-time on the map from the shop to your exact location.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 16),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _goToLogin,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Middle Carousel PageView
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _buildPage(_pages[i], i),
              ),
            ),

            // Bottom Section: Indicators & CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Page Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = _current == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF5B4DFF) : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Next / Get Started Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_current < _pages.length - 1) {
                          _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _goToLogin();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4DFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _current == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildPage(_OnboardData data, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular Soft Badge with Icon
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: data.bgCircleColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: 84,
                color: data.color,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1F2937),
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final Color color;
  final Color bgCircleColor;
  final String title;
  final String subtitle;

  const _OnboardData({
    required this.icon,
    required this.color,
    required this.bgCircleColor,
    required this.title,
    required this.subtitle,
  });
}
