import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
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
      secondaryIcon: Icons.shopping_bag_rounded,
      topTag: 'EVERYTHING IN ONE APP',
      gradient: [Color(0xFF4F46E5), Color(0xFF6366F1)],
      bgCircleColor: Color(0xFFEEF2FF),
      title: 'All Local Stores, One Super App',
      subtitle: 'Order groceries, delicious meals, fresh meat, bakery treats, and medicines from your favorite local shops.',
      bulletTags: [
        '🛒 Local Supermarkets',
        '🍔 Top Restaurants',
        '🍗 Fresh Meat & Fish',
        '💊 24/7 Medicines',
      ],
    ),
    _OnboardData(
      icon: Icons.pin_drop_rounded,
      secondaryIcon: Icons.map_rounded,
      topTag: 'EXCLUSIVE PIN & ORDER',
      gradient: [Color(0xFFFF6D00), Color(0xFFF59E0B)],
      bgCircleColor: Color(0xFFFFF7ED),
      title: 'Pin Shop on Map & Order Anything',
      subtitle: 'Can\'t find a store? Drop a pin on any shop or location across town, type what you need, and our rider will buy and deliver it directly!',
      bulletTags: [
        '📍 Pin Any Local Shop on Map',
        '📝 Type or Upload Any List',
        '🛵 Dedicated Rider Pickup',
        '💵 Cash on Delivery & UPI',
      ],
    ),
    _OnboardData(
      icon: Icons.electric_moped_rounded,
      secondaryIcon: Icons.bolt_rounded,
      topTag: 'HYPERLOCAL SPEED',
      gradient: [Color(0xFF059669), Color(0xFF10B981)],
      bgCircleColor: Color(0xFFECFDF5),
      title: 'Fast & Doorstep Delivery',
      subtitle: 'Trained local riders ensure prompt doorstep delivery with maximum safety, fresh packing, and transparent pricing.',
      bulletTags: [
        '⚡ Express 20-35 Min Delivery',
        '🛡️ Sealed & Sanitized Packages',
        '🤝 Verified Local Riders',
      ],
    ),
    _OnboardData(
      icon: Icons.navigation_rounded,
      secondaryIcon: Icons.fmd_good_rounded,
      topTag: 'REAL-TIME TRACKING',
      gradient: [Color(0xFF2563EB), Color(0xFF38BDF8)],
      bgCircleColor: Color(0xFFEFF6FF),
      title: 'Live Turn-by-Turn GPS Tracking',
      subtitle: 'Follow your order\'s real-time journey on the interactive map from the shop counter right to your doorstep.',
      bulletTags: [
        '🗺️ Live Rider Movement',
        '⏱️ Accurate Minute-by-Minute ETA',
        '📞 1-Tap Rider Call & Chat',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<CustomerLanguageProvider>(context);
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final isSmall = screenH < 720;
    final activeData = _pages[_current];

    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Logo & Skip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6D00).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'NAMBA',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _goToLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      child: Text(
                        lang.text(en: 'Skip', ta: 'தவிர்', tanglish: 'Skip'),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Middle Carousel PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) => _buildPage(_pages[i], i, media),
                ),
              ),

              // Bottom Section: Indicators & CTA Button
              Padding(
                padding: EdgeInsets.fromLTRB(24, 6, 24, isSmall ? 16 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page Indicator Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pages.length, (i) {
                            final isActive = _current == i;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 28 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? activeData.gradient[0]
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: isSmall ? 14 : 20),

                        // Next / Get Started Button
                        SizedBox(
                          width: double.infinity,
                          height: (screenH * 0.065).clamp(48.0, 56.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: activeData.gradient,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: activeData.gradient[0].withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
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
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _current == _pages.length - 1
                                        ? lang.text(en: 'Get Started 🚀', ta: 'தொடங்கலாம் 🚀', tanglish: 'Start Pannunga 🚀')
                                        : lang.text(en: 'Next', ta: 'அடுத்தது', tanglish: 'Next'),
                                    style: GoogleFonts.outfit(
                                      fontSize: (media.size.width * 0.042).clamp(14.0, 16.0),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _current == _pages.length - 1
                                        ? Icons.rocket_launch_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ],
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
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildPage(_OnboardData data, int index, MediaQueryData media) {
    final screenH = media.size.height;
    final isSmall = screenH < 720;
    final outerHaloSize = (screenH * 0.22).clamp(130.0, 200.0);
    final midHaloSize = outerHaloSize * 0.76;
    final innerCircleSize = outerHaloSize * 0.56;
    final iconSize = innerCircleSize * 0.49;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 20 : 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: isSmall ? 4 : 8),

          // Top Tag Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 14, vertical: isSmall ? 5 : 6),
            decoration: BoxDecoration(
              color: data.gradient[0].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: data.gradient[0].withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.secondaryIcon, size: isSmall ? 13 : 14, color: data.gradient[0]),
                const SizedBox(width: 6),
                Text(
                  data.topTag,
                  style: GoogleFonts.outfit(
                    fontSize: isSmall ? 10.5 : 11,
                    fontWeight: FontWeight.w800,
                    color: data.gradient[0],
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmall ? 16 : 24),

          // Hero Icon Card with Layered Halo & Concentric Rings
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Soft Halo
              Container(
                width: outerHaloSize,
                height: outerHaloSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.bgCircleColor,
                  boxShadow: [
                    BoxShadow(
                      color: data.gradient[0].withValues(alpha: 0.15),
                      blurRadius: isSmall ? 24 : 36,
                      spreadRadius: isSmall ? 4 : 8,
                    ),
                  ],
                ),
              ),

              // Middle Decorative Ring
              Container(
                width: midHaloSize,
                height: midHaloSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: data.gradient[0].withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
              ),

              // Center Icon with Gradient
              Container(
                width: innerCircleSize,
                height: innerCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: data.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.gradient[0].withValues(alpha: 0.4),
                      blurRadius: isSmall ? 12 : 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    data.icon,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 18 : 28),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isSmall ? 20 : 23,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
          SizedBox(height: isSmall ? 8 : 12),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isSmall ? 12.5 : 13.5,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: isSmall ? 14 : 20),

          // Feature Highlights Pills Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: data.bulletTags.map((tag) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 12, vertical: isSmall ? 6 : 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.outfit(
                    fontSize: isSmall ? 11.5 : 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final IconData secondaryIcon;
  final String topTag;
  final List<Color> gradient;
  final Color bgCircleColor;
  final String title;
  final String subtitle;
  final List<String> bulletTags;

  const _OnboardData({
    required this.icon,
    required this.secondaryIcon,
    required this.topTag,
    required this.gradient,
    required this.bgCircleColor,
    required this.title,
    required this.subtitle,
    required this.bulletTags,
  });
}
