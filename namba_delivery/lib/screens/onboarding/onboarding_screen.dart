import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth/delivery_login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Deliver with Ease',
      'subtitle': 'Pick up and drop off orders with our ultra-precise navigation.',
      'image': '🚚',
    },
    {
      'title': 'Earn Transparently',
      'subtitle': 'Track every rupee you earn with real-time payout statistics.',
      'image': '💰',
    },
    {
      'title': 'Safety First',
      'subtitle': 'Your safety is our priority. 24/7 dedicated rider support.',
      'image': '🛡️',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemCount: _onboardingData.length,
            itemBuilder: (ctx, i) => _buildPage(_onboardingData[i]),
          ),
          Positioned(
            bottom: 60,
            left: 32,
            right: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIndicator(),
                _buildActionButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, String> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                data['image']!,
                style: const TextStyle(fontSize: 80),
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 64),
          Text(
            data['title']!,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.darkText, letterSpacing: -0.5),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            data['subtitle']!,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.lightText, fontWeight: FontWeight.w600, height: 1.5),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      children: List.generate(
        _onboardingData.length,
        (idx) => AnimatedContainer(
          duration: 300.ms,
          width: _currentPage == idx ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: _currentPage == idx ? AppTheme.primaryOrange : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    bool isLast = _currentPage == _onboardingData.length - 1;
    return GestureDetector(
      onTap: () {
        if (isLast) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (ctx) => const DeliveryLoginScreen()));
        } else {
          _pageController.nextPage(duration: 400.ms, curve: Curves.easeInOut);
        }
      },
      child: AnimatedContainer(
        duration: 300.ms,
        padding: EdgeInsets.symmetric(horizontal: isLast ? 24 : 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            if (isLast) ...[
              Text(
                'Get Started',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
