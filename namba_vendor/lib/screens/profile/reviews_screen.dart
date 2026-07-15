import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.lightSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('reviews'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildRatingSummary(lang),
            const SizedBox(height: 32),
            _buildReviewsList(lang),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSummary(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4.8',
                  style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w800, color: AppTheme.darkText),
                ),
                Text(
                    lang.translate('average_rating'),
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.mediumText),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                ),
              ],
            ),
          ),
          Container(height: 80, width: 1, color: AppTheme.lightSurface),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildRatingBar(5, 0.8),
                _buildRatingBar(4, 0.1),
                _buildRatingBar(3, 0.05),
                _buildRatingBar(2, 0.02),
                _buildRatingBar(1, 0.03),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int star, double percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$star', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppTheme.lightSurface,
              color: Colors.amber,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(LanguageProvider lang) {
    final mockReviews = [
      {'name': 'Arun Kumar', 'rating': 5, 'comment': 'Fresh products and fast delivery! Super happy.', 'date': '2 hours ago'},
      {'name': 'Priya S', 'rating': 4, 'comment': 'Good quality. But milk was slightly late today.', 'date': '1 day ago'},
      {'name': 'Vijay', 'rating': 5, 'comment': 'Best shop in this area. Highly recommended.', 'date': '3 days ago'},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockReviews.length,
      itemBuilder: (context, index) {
        final review = mockReviews[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(review['name'] as String, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(review['date'] as String, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.lightText)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, color: (i < (review['rating'] as int)) ? Colors.amber : AppTheme.lightSurface, size: 14)),
              ),
              const SizedBox(height: 12),
              Text(review['comment'] as String, style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.mediumText)),
            ],
          ),
        ).animate().fadeIn(delay: (200 * index).ms);
      },
    );
  }
}

