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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
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
                  colors: [AppTheme.primaryOrange.withValues(alpha: isDark ? 0.08 : 0.15), Colors.transparent],
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
                    _buildHeader(context, lang, isDark),
                    _buildSearchBar(lang, isDark),
                    _buildCategoryFilter(categories, isDark),
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
                            return _buildEmptyState(inventory, lang, isDark);
                          }

                          return RefreshIndicator(
                            onRefresh: () => inventory.fetchProducts(),
                            color: AppTheme.primaryOrange,
                            backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return _buildProductCard(context, product, index, lang, isDark);
                              },
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

  Widget _buildHeader(BuildContext context, LanguageProvider lang, bool isDark) {
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
                  color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
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

  Widget _buildSearchBar(LanguageProvider lang, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 24,
              offset: const Offset(0, 10),
            )
          ],
          border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() {}),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.darkText, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search your products...',
            hintStyle: GoogleFonts.outfit(color: isDark ? const Color(0xFF64748B) : AppTheme.lightText, fontWeight: FontWeight.w500, fontSize: 16),
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

  Widget _buildCategoryFilter(List<String> categories, bool isDark) {
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
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryOrange
                        : (isDark ? const Color(0xFF131B2E) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : (isDark ? const Color(0xFF273552) : Colors.grey.shade100),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(VendorInventoryProvider inventory, LanguageProvider lang, bool isDark) {
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
              color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            'Add some products to start selling.',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: isDark ? const Color(0xFF94A3B8) : AppTheme.lightText,
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

  Widget _buildProductCard(BuildContext context, VendorProductModel product, int index, LanguageProvider lang, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Product Image / Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryOrange.withValues(alpha: 0.15),
                  AppTheme.primaryOrange.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.2)),
            ),
            child: Icon(
              product.icon ?? Iconsax.box,
              color: AppTheme.primaryOrange,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),

          // 2. Center Info (Name + Price + Stock Badge)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    _buildStockBadge(product.stock, lang),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. Right Action Column (Availability Switch + Edit Button)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.85,
                child: CupertinoSwitch(
                  value: product.isAvailable,
                  activeColor: AppTheme.accentGreen,
                  onChanged: (value) {
                    context.read<VendorInventoryProvider>().toggleAvailability(product.id);
                  },
                ),
              ),
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProductScreen(product: product)),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.edit_2, size: 13, color: AppTheme.primaryOrange),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (100 + (index * 50)).ms, duration: 400.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _buildStockBadge(int stock, LanguageProvider lang) {
    Color color;
    String label;
    if (stock <= 0) {
      color = AppTheme.primaryRed;
      label = lang.translate('out_of_stock');
    } else if (stock < 10) {
      color = AppTheme.primaryOrange;
      label = '${lang.isTamil ? 'குறைவான இருப்பு' : 'Low'} ($stock)';
    } else {
      color = AppTheme.accentGreen;
      label = '${lang.translate('in_stock')} ($stock)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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

