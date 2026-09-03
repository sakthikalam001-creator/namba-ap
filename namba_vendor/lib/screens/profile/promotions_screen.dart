import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: isDark ? Colors.white : AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('promotions'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.darkText,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Iconsax.add_circle, color: AppTheme.primaryOrange),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildCreateCouponButton(lang),
            const SizedBox(height: 32),
            _buildActiveCouponsList(lang, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCouponButton(LanguageProvider lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primaryOrange, Color(0xFF1D4ED8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Iconsax.ticket_discount, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            lang.translate('create_coupon'),
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Boost your sales with custom discounts',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCouponsList(LanguageProvider lang, bool isDark) {
    final mockCoupons = [
      {'code': 'WELCOME50', 'discount': '₹50 OFF', 'status': 'active', 'expiry': '30 Apr 2026'},
      {'code': 'SUMMER20', 'discount': '20% OFF', 'status': 'active', 'expiry': '15 May 2026'},
      {'code': 'OLDCOUPON', 'discount': '₹100 OFF', 'status': 'expired', 'expiry': '10 Mar 2026'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.translate('coupons'),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.darkText),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mockCoupons.length,
          itemBuilder: (context, index) {
            final coupon = mockCoupons[index];
            final isExpired = coupon['status'] == 'expired';
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : Border.all(color: isExpired ? Colors.transparent : AppTheme.accentGreen.withValues(alpha: 0.1)),
                boxShadow: isDark ? null : AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isExpired ? (isDark ? const Color(0xFF475569) : AppTheme.lightText) : AppTheme.accentGreen).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Iconsax.ticket, color: isExpired ? (isDark ? const Color(0xFF94A3B8) : AppTheme.lightText) : AppTheme.accentGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon['code'] as String,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.darkText),
                        ),
                        Text(
                          'Expiry: ${coupon['expiry']}',
                          style: GoogleFonts.outfit(fontSize: 12, color: isDark ? const Color(0xFF64748B) : AppTheme.lightText),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        coupon['discount'] as String,
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: isExpired ? (isDark ? const Color(0xFF64748B) : AppTheme.lightText) : AppTheme.primaryOrange),
                      ),
                      Text(
                        isExpired ? lang.translate('expired') : lang.translate('active'),
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: isExpired ? AppTheme.primaryRed : AppTheme.accentGreen),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().slideX(begin: 0.1, end: 0, delay: (100 * index).ms);
          },
        ),
      ],
    );
  }
}

