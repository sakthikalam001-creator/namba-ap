import 'package:flutter/material.dart';
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
      icon: Icons.store_rounded,
      color: Color(0xFF4F46E5),
      title: 'All Stores, One App',
      subtitle: 'Order groceries, food, medicines and bakery items from nearby stores — all in one place.',
    ),
    _OnboardData(
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFFDB2777),
      title: 'Fast Delivery',
      subtitle: 'Get your orders delivered to your doorstep quickly by our trusted delivery partners.',
    ),
    _OnboardData(
      icon: Icons.track_changes_rounded,
      color: Color(0xFF059669),
      title: 'Live Order Tracking',
      subtitle: 'Track your order in real-time from the moment it is placed until it reaches your door.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _goToLogin,
                child: const Text('Skip', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _current == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _current == i ? _pages[i].color : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_current < _pages.length - 1) {
                          _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                        } else {
                          _goToLogin();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pages[_current].color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _current == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Widget _buildPage(_OnboardData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 80, color: data.color),
          ),
          const SizedBox(height: 48),
          Text(data.title, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2)),
          const SizedBox(height: 16),
          Text(data.subtitle, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w400, height: 1.5)),
        ],
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _OnboardData({required this.icon, required this.color, required this.title, required this.subtitle});
}
