import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/vendor_inventory_provider.dart';
import '../../services/language_provider.dart';
import '../../models/vendor_product_model.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../widgets/shimmer_loading.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Ultra-clean light cool gray
      body: Stack(
        children: [
          // Background decorative gradient glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.primaryOrange.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Consumer<VendorInventoryProvider>(
              builder: (context, inventory, child) {
                final categories = [
                  'All',
                  ...inventory.products.map((p) => p.category)
                ].map((cat) {
                  return AppCategories.defaultCategories.firstWhere(
                    (c) => c.toLowerCase() == cat.toLowerCase(),
                    orElse: () => cat,
                  );
                }).toSet().toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, lang),
                    _buildSearchBar(lang),
                    _buildCategoryFilter(categories),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (inventory.isLoading) {
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              itemCount: 5,
                              itemBuilder: (context, index) => const ProductCardShimmer(),
                            );
                          }

                          final query = _searchController.text.toLowerCase();
                          final filteredProducts = inventory.products.where((p) {
                            final matchesCategory = _selectedCategory == 'All' ||
                                p.category.toLowerCase() == _selectedCategory.toLowerCase();
                            final matchesSearch = p.name.toLowerCase().contains(query);
                            return matchesCategory && matchesSearch;
                          }).toList();

                          if (filteredProducts.isEmpty) {
                            return _buildEmptyState(inventory, lang);
                          }

                          return RefreshIndicator(
                            onRefresh: () => inventory.fetchProducts(),
                            color: AppTheme.primaryOrange,
                            backgroundColor: Colors.white,
                            child: AnimationLimiter(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return AnimationConfiguration.staggeredList(
                                    position: index,
                                    duration: const Duration(milliseconds: 600),
                                    child: SlideAnimation(
                                      verticalOffset: 50.0,
                                      child: FadeInAnimation(
                                        child: _buildProductCard(context, product, index, lang),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Store Management',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryOrange,
                  letterSpacing: 1.2,
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
              const SizedBox(height: 4),
              Text(
                lang.translate('inventory'),
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkText,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: -0.2),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.primaryDeepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddProductScreen()),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Iconsax.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }

  Widget _buildSearchBar(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 24,
              offset: const Offset(0, 10),
            )
          ],
          border: Border.all(color: Colors.grey.shade100, width: 2),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() {}),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.darkText, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search your products...',
            hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.w500, fontSize: 16),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Iconsax.search_normal_1, color: AppTheme.primaryOrange, size: 22),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
    );
  }

  Widget _buildCategoryFilter(List<String> categories) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          final isDefault = category == 'All' || category.toLowerCase() == 'other';

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.darkText : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppTheme.darkText.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6))]
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
                  border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
                ),
                child: Text(
                  category,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : AppTheme.mediumText,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: (300 + (index * 50)).ms).slideX(begin: 0.2);
        },
      ),
    );
  }

  Widget _buildEmptyState(VendorInventoryProvider inventory, LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.box_add, size: 80, color: AppTheme.accentTeal),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          Text(
            'Your shelf is empty',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkText,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Add some products to start selling.',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: AppTheme.lightText,
              fontWeight: FontWeight.w500,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => inventory.fetchProducts(),
            icon: const Icon(Iconsax.refresh, size: 20, color: AppTheme.primaryOrange),
            label: Text('Sync Inventory', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, VendorProductModel product, int index, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryOrange.withValues(alpha: 0.15), AppTheme.primaryOrange.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    product.icon ?? Iconsax.box,
                    color: AppTheme.primaryOrange,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkText,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₹${product.price.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStockBadge(product.stock, lang),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    CupertinoSwitch(
                      value: product.isAvailable,
                      activeColor: AppTheme.accentGreen,
                      onChanged: (value) {
                        context.read<VendorInventoryProvider>().toggleAvailability(product.id);
                      },
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditProductScreen(product: product)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Edit',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.mediumText),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (200 + (index * 100)).ms, duration: 500.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuart);
  }

  Widget _buildStockBadge(int stock, LanguageProvider lang) {
    Color color;
    String label;
    if (stock <= 0) {
      color = AppTheme.primaryRed;
      label = lang.translate('out_of_stock');
    } else if (stock < 10) {
      color = AppTheme.primaryOrange;
      label = '${lang.isTamil ? 'குறைவான இருப்பு' : 'Low Stock'} ($stock)';
    } else {
      color = AppTheme.accentGreen;
      label = '${lang.translate('in_stock')} ($stock)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

