import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/theme_provider.dart';
import '../../services/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/vendor_product_model.dart';
import '../../services/vendor_inventory_provider.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockController = TextEditingController();

  String _selectedCategory = AppCategories.defaultCategories.first;
  String _selectedOfferBadge = '🔥 Combo Offer';
  String _selectedUnit = '1 pc';
  String _selectedFoodType = 'veg'; // 'veg', 'non_veg', 'egg', 'general'
  String _selectedPrepTime = '15 mins';

  bool _isAvailable = true;
  bool _isSaving = false;
  bool _showSuccess = false;

  final List<String> _offerPresets = [
    '🔥 Combo Offer',
    '🎁 1+1 Free Combo',
    '⚡ Hot Deal',
    '🔥 Bestseller',
    '🏷️ 20% OFF',
    '🏷️ 50% OFF',
    '⭐ Chef Special',
    '✨ Newly Arrived',
    '🚫 No Offer',
  ];

  final List<String> _unitsList = [
    '1 pc',
    '1 Plate',
    '1 kg',
    '500 g',
    '250 g',
    '1 Litre',
    '500 ml',
    'Full',
    'Half',
    'Combo Pack',
  ];

  final List<String> _prepTimes = [
    '10 mins',
    '15 mins',
    '20 mins',
    '30 mins',
    '45 mins',
    'Instant',
  ];

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_calculateDiscount);
    _mrpController.addListener(_calculateDiscount);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  int _calculatedDiscount = 0;
  double _calculatedSavings = 0;

  void _calculateDiscount() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final mrp = double.tryParse(_mrpController.text.trim()) ?? 0;
    if (mrp > price && price > 0) {
      final savings = mrp - price;
      final disc = ((savings / mrp) * 100).round();
      if (_calculatedDiscount != disc || _calculatedSavings != savings) {
        setState(() {
          _calculatedDiscount = disc;
          _calculatedSavings = savings;
        });
      }
    } else {
      if (_calculatedDiscount != 0 || _calculatedSavings != 0) {
        setState(() {
          _calculatedDiscount = 0;
          _calculatedSavings = 0;
        });
      }
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final price = double.parse(_priceController.text.trim());
        final mrp = double.tryParse(_mrpController.text.trim()) ?? price;
        final stock = int.tryParse(_stockController.text.trim()) ?? 50;

        final newProduct = VendorProductModel(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          mrp: mrp > price ? mrp : price,
          discount: _calculatedDiscount,
          offerBadge: _selectedOfferBadge == '🚫 No Offer' ? '' : _selectedOfferBadge,
          unit: _selectedUnit,
          foodType: _selectedFoodType,
          prepTime: _selectedPrepTime,
          stock: stock,
          category: _selectedCategory,
          isAvailable: _isAvailable,
          icon: _getCategoryIcon(_selectedCategory),
        );

        await context.read<VendorInventoryProvider>().addProduct(newProduct);
        if (mounted) {
          setState(() {
            _isSaving = false;
            _showSuccess = true;
          });
          await Future.delayed(const Duration(milliseconds: 1400));
          if (mounted) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving product: $e'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fruits': return Iconsax.apple;
      case 'vegetables': return Iconsax.box;
      case 'dairy': return Iconsax.milk;
      case 'bakery': return Iconsax.box;
      case 'meat': return Iconsax.box;
      case 'beverages': return Iconsax.box;
      case 'snacks': return Iconsax.box;
      case 'household': return Iconsax.house;
      default: return Iconsax.box;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          padding: const EdgeInsets.only(top: 36, left: 16, right: 16, bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 16),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text(
                lang.isTamil ? 'புதிய தயாரிப்பு சேர்க்க' : (lang.isTanglish ? 'Pudhu Item Add Pannu' : 'Add New Product'),
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. PRODUCT BASIC DETAILS CARD
                  _buildSectionHeader(
                    icon: Iconsax.box_1,
                    title: lang.isTamil ? 'பொருள் விவரங்கள்' : 'Product Details',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          controller: _nameController,
                          label: lang.isTamil ? 'பொருளின் பெயர்' : 'Product Name',
                          hint: 'e.g. Chicken Biryani / Red Apple',
                          isDark: isDark,
                          validator: (v) => v!.isEmpty ? (lang.isTamil ? 'பெயர் எழுதவும்' : 'Please enter name') : null,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _descriptionController,
                          label: lang.isTamil ? 'விளக்கம்' : 'Description',
                          hint: 'e.g. Freshly cooked aromatic biryani with egg & raita',
                          maxLines: 2,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),

                        // Food / Diet Type Selector
                        Text(
                          lang.isTamil ? 'உணவு வகை (Diet Type)' : 'Diet / Item Type',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: subTextColor),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildDietChip('veg', '🟢 Veg', const Color(0xFF10B981), isDark),
                            const SizedBox(width: 8),
                            _buildDietChip('non_veg', '🔴 Non-Veg', const Color(0xFFEF4444), isDark),
                            const SizedBox(width: 8),
                            _buildDietChip('egg', '🟡 Egg', const Color(0xFFF59E0B), isDark),
                            const SizedBox(width: 8),
                            _buildDietChip('general', '📦 General', const Color(0xFF6366F1), isDark),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. SPECIAL OFFERS & DEAL BADGES
                  _buildSectionHeader(
                    icon: Iconsax.discount_shape,
                    title: lang.isTamil ? 'சிறப்பு சலுகைகள் & ஆஃபர்' : 'Special Offers & Deals',
                    isDark: isDark,
                    badge: 'BOOST SALES 🔥',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.isTamil ? 'ஆஃபர் பேட்ஜ் தேர்வு செய்க:' : 'Select an Offer Tag for this item:',
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _offerPresets.map((badge) {
                            final isSel = _selectedOfferBadge == badge;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedOfferBadge = badge),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? (isDark ? const Color(0xFF4338CA) : const Color(0xFFEEF2FF))
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF6366F1) : borderColor,
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  badge,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                    color: isSel
                                        ? (isDark ? Colors.white : const Color(0xFF4338CA))
                                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. PRICING, MRP & INVENTORY CARD
                  _buildSectionHeader(
                    icon: Iconsax.dollar_circle,
                    title: lang.isTamil ? 'விலை & இருப்பு' : 'Pricing & Inventory',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Selling Price
                            Expanded(
                              child: _buildInputField(
                                controller: _priceController,
                                label: lang.isTamil ? 'விற்பனை விலை (₹)' : 'Selling Price (₹)',
                                hint: '0',
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Original MRP
                            Expanded(
                              child: _buildInputField(
                                controller: _mrpController,
                                label: lang.isTamil ? 'அசல் MRP (₹)' : 'Original MRP (₹)',
                                hint: 'Optional',
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        if (_calculatedDiscount > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_offer_rounded, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⚡ Customer Saves ₹${_calculatedSavings.toStringAsFixed(0)} ($_calculatedDiscount% OFF)',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // Stock Count
                            Expanded(
                              child: _buildInputField(
                                controller: _stockController,
                                label: lang.isTamil ? 'மொத்த இருப்பு' : 'Stock Quantity',
                                hint: 'e.g. 50',
                                keyboardType: TextInputType.number,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Unit Portion Selector
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.isTamil ? 'அளவு (Unit)' : 'Unit / Size',
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: subTextColor),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedUnit,
                                        isExpanded: true,
                                        dropdownColor: cardBg,
                                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: subTextColor),
                                        items: _unitsList.map((u) {
                                          return DropdownMenuItem(
                                            value: u,
                                            child: Text(u, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) setState(() => _selectedUnit = v);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. CATEGORY & TIME
                  _buildSectionHeader(
                    icon: Iconsax.category,
                    title: lang.isTamil ? 'பிரிவு & கிடைக்கும் நிலை' : 'Category & Availability',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _showCategoryBottomSheet(context, isDark, textColor, cardBg, borderColor),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.isTamil ? 'பொருளின் வகை' : 'Category',
                                      style: GoogleFonts.outfit(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedCategory.toUpperCase(),
                                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryOrange, size: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang.isTamil ? 'ஆர்டர்களுக்கு தயார் (In Stock)' : 'Available for Order',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: textColor),
                            ),
                            Switch(
                              value: _isAvailable,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (v) => setState(() => _isAvailable = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // SAVE BUTTON
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving || _showSuccess ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: _isSaving
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  lang.isTamil ? 'தயாரிப்பை சேமிக்க 🚀' : (lang.isTanglish ? 'Product-ai Save Pannu 🚀' : 'Save Product 🚀'),
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_showSuccess)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
                      const SizedBox(height: 16),
                      Text(
                        lang.isTamil ? 'வெற்றிகரமாகச் சேர்க்கப்பட்டது!' : 'Product Added Successfully!',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDietChip(String type, String label, Color color, bool isDark) {
    final isSel = _selectedFoodType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFoodType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? color.withValues(alpha: isDark ? 0.25 : 0.12) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSel ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: isSel ? 1.5 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
              color: isSel ? color : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required bool isDark,
    String? badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        if (badge != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFFEF4444)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 13, color: isDark ? const Color(0xFF475569) : Colors.grey.shade400),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
          ),
        ),
      ],
    );
  }

  void _showCategoryBottomSheet(BuildContext context, bool isDark, Color textColor, Color cardBg, Color borderColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer<VendorInventoryProvider>(
          builder: (context, provider, child) {
            final categories = AppCategories.defaultCategories;
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Category',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textColor),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSel = _selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                        selected: isSel,
                        selectedColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155))),
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedCategory = cat);
                            Navigator.pop(ctx);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
