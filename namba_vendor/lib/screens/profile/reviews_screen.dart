import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/vendor_order_provider.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _isLoading = true;
  double _averageRating = 5.0;
  int _totalCount = 0;
  Map<String, dynamic> _counts = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
  List<dynamic> _reviewsList = [];

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadVendorReviews();
  }

  Future<void> _loadVendorReviews() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
      String vendorId = orderProvider.vendorId;

      if (vendorId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        vendorId = prefs.getString('bg_vendor_id') ?? prefs.getString('vendor_id') ?? '';
      }

      if (vendorId.isNotEmpty) {
        final data = await _apiService.getVendorReviews(vendorId);
        if (data != null && mounted) {
          setState(() {
            _averageRating = (data['averageRating'] as num?)?.toDouble() ?? 5.0;
            _totalCount = (data['totalCount'] as num?)?.toInt() ?? 0;
            _counts = Map<String, dynamic>.from(data['counts'] ?? {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0});
            _reviewsList = data['reviews'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading vendor reviews: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _getStarPercent(int star) {
    if (_totalCount == 0) return 0.0;
    final count = (_counts['$star'] as num?)?.toDouble() ?? 0.0;
    return (count / _totalCount).clamp(0.0, 1.0);
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes <= 0 ? 1 : diff.inMinutes} mins ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} hours ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

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
          lang.translate('reviews'),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.darkText,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryOrange),
            onPressed: _loadVendorReviews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildRatingSummary(lang, isDark),
                  const SizedBox(height: 32),
                  _buildReviewsList(lang, isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildRatingSummary(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: GoogleFonts.outfit(fontSize: 44, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.darkText),
                ),
                Text(
                  lang.translate('average_rating'),
                  style: GoogleFonts.outfit(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_totalCount Ratings',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryOrange),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < _averageRating.floor()
                          ? Icons.star_rounded
                          : (index < _averageRating ? Icons.star_half_rounded : Icons.star_outline_rounded),
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
          ),
          Container(height: 80, width: 1, color: isDark ? const Color(0xFF1E293B) : AppTheme.lightSurface),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildRatingBar(5, _getStarPercent(5), isDark),
                _buildRatingBar(4, _getStarPercent(4), isDark),
                _buildRatingBar(3, _getStarPercent(3), isDark),
                _buildRatingBar(2, _getStarPercent(2), isDark),
                _buildRatingBar(1, _getStarPercent(1), isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int star, double percent, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$star', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : AppTheme.darkText)),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              color: Colors.amber,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(LanguageProvider lang, bool isDark) {
    if (_reviewsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
          boxShadow: isDark ? null : AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            const Icon(Iconsax.star, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              'No Reviews Yet',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.darkText),
            ),
            const SizedBox(height: 4),
            Text(
              'Real customer reviews will appear here once customers rate your store after order delivery.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviewsList.length,
      itemBuilder: (context, index) {
        final review = _reviewsList[index];
        final name = review['customerName']?.toString() ?? 'Verified Customer';
        final rating = (review['rating'] as num?)?.toInt() ?? 5;
        final comment = review['comment']?.toString() ?? 'Great product!';
        final dateStr = _formatDate(review['createdAt']?.toString());

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: const Color(0xFF273552), width: 1.2) : null,
            boxShadow: isDark ? null : AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : AppTheme.darkText)),
                  Text(dateStr, style: GoogleFonts.outfit(fontSize: 12, color: isDark ? const Color(0xFF64748B) : AppTheme.lightText)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star_rounded, color: (i < rating) ? Colors.amber : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200), size: 16)),
              ),
              const SizedBox(height: 12),
              Text(comment, style: GoogleFonts.outfit(fontSize: 14, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.mediumText)),
            ],
          ),
        ).animate().fadeIn(delay: (100 * index).ms);
      },
    );
  }
}

