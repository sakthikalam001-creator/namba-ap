import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'store_detail_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final CustomerApiService _apiService = CustomerApiService();
  List<Offer> _offers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    setState(() => _isLoading = true);
    final rawOffers = await _apiService.getOffers();
    setState(() {
      _offers = rawOffers.map((o) => Offer.fromMap(o)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildEliteHeader(),
          _isLoading 
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))))
            : _offers.isEmpty
              ? _buildEmptyState()
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildProfessionalOfferCard(_offers[index]),
                      childCount: _offers.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEliteHeader() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        title: Text('Curated Deals', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20)),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)]),
              child: Icon(Iconsax.search_status, size: 40, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 24),
            Text('No active curation', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400)),
            const SizedBox(height: 8),
            Text('Check back soon for exclusive deals', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade300)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalOfferCard(Offer offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Professional Banner
          Container(
            height: 160,
            width: double.infinity,
            color: const Color(0xFFF1F5F9),
            child: offer.imageUrl != null 
              ? Image.network(offer.imageUrl!, fit: BoxFit.cover)
              : Center(child: Icon(Iconsax.shop, size: 48, color: Colors.grey.shade300)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: Text(offer.discountType == 'Percentage' ? '${offer.discountValue.toInt()}% OFF' : '₹${offer.discountValue.toInt()} OFF', 
                        style: GoogleFonts.outfit(color: const Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                    ),
                    const Spacer(),
                    Text(offer.vendorName.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.5)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(offer.title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), height: 1.1)),
                const SizedBox(height: 8),
                Text(offer.description, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to store
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('View Collections', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
