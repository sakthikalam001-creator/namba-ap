import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../providers/delivery_provider.dart';

class RiderRatingsScreen extends StatefulWidget {
  const RiderRatingsScreen({super.key});

  @override
  State<RiderRatingsScreen> createState() => _RiderRatingsScreenState();
}

class _RiderRatingsScreenState extends State<RiderRatingsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshRatings();
  }

  Future<void> _refreshRatings() async {
    setState(() => _isLoading = true);
    await Provider.of<DeliveryProvider>(context, listen: false).fetchRealDriverRatings();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Customer Ratings & Reviews',
          style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
            onPressed: _refreshRatings,
          ),
        ],
      ),
      body: Consumer<DeliveryProvider>(
        builder: (context, provider, _) {
          final double ratingVal = provider.realDriverRating ?? 5.0;
          final int ratingCount = provider.realRatingCount;
          final Map<String, dynamic> counts = provider.ratingCounts;
          final Map<String, dynamic> tags = provider.ratingTags;
          final List<dynamic> reviews = provider.driverReviewsList;
          final double totalTips = provider.totalTipsEarned;

          return RefreshIndicator(
            onRefresh: _refreshRatings,
            color: const Color(0xFF6366F1),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── 1. MAIN RATING HERO CARD ──
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF312E81).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    ratingVal.toStringAsFixed(1),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 36),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ' REAL CUSTOMER REVIEWS',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  ratingVal >= 4.5 ? 'TOP RIDER' : 'ACTIVE',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (totalTips > 0) ...[
                        const SizedBox(height: 18),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFF472B6), size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Total Customer Tips Earned: ',
                              style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '₹',
                              style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: 0.05),

                const SizedBox(height: 20),

                // ── 2. STAR BREAKDOWN CARD ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RATING BREAKDOWN',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(5, (index) {
                        final starNum = 5 - index;
                        final count = (counts[''] ?? 0) as int;
                        final double percentage = ratingCount > 0 ? (count / ratingCount) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  ' ★',
                                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade100,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      starNum >= 4 ? const Color(0xFF10B981) : (starNum == 3 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '',
                                  textAlign: TextAlign.end,
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                const SizedBox(height: 20),

                // ── 3. CUSTOMER COMPLIMENTS & BADGES ──
                if (tags.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.military_tech_rounded, color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'CUSTOMER COMPLIMENTS & BADGES',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: tags.entries.map((entry) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.key,
                                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF4338CA)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '',
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                  const SizedBox(height: 20),
                ],

                // ── 4. RECENT CUSTOMER FEEDBACK LIST ──
                Text(
                  'RECENT CUSTOMER REVIEWS',
                  style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),

                if (reviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.rate_review_outlined, color: Colors.grey, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'No customer reviews yet',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF475569), fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete deliveries to receive customer ratings and tips!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: Colors.grey.shade500, fontSize: 12.5),
                        ),
                      ],
                    ),
                  )
                else
                  ...reviews.map((r) {
                    final double revRating = (r['rating'] as num?)?.toDouble() ?? 5.0;
                    final String comment = r['comment']?.toString() ?? '';
                    final String customerName = r['customerName']?.toString() ?? 'Verified Customer';
                    final List<dynamic> revTags = r['tags'] ?? [];
                    final String dateStr = r['createdAt'] != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(r['createdAt']).toLocal())
                        : 'Recently';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.12),
                                    child: Text(
                                      customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                                      style: GoogleFonts.outfit(color: const Color(0xFF6366F1), fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customerName,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFF1E293B)),
                                      ),
                                      Text(
                                        dateStr,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 11, color: Colors.grey.shade400),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      revRating.toStringAsFixed(1),
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5, color: const Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (revTags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: revTags.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag.toString(),
                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              '""',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
