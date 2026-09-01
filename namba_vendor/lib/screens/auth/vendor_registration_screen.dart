import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'vendor_map_location_picker_screen.dart';
import 'waiting_approval_screen.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class VendorRegistrationScreen extends StatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  State<VendorRegistrationScreen> createState() => _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<VendorRegistrationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  // Controllers - Identity
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  
  // Controllers - Structured Separate Manual Address
  final _doorNoController = TextEditingController(); // Shop / Door No / Complex Name
  final _streetController = TextEditingController(); // Street Name / Landmark
  final _areaController = TextEditingController();   // Area / Locality (e.g. Thindal, Perundurai Road)
  final _cityController = TextEditingController(text: 'Erode');
  final _pincodeController = TextEditingController(text: '638012'); // 6-digit Pincode

  // Controllers - Contact & Legal
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  final _businessEmailController = TextEditingController();

  // Category
  String _selectedCategory = 'Grocery';
  String _selectedCategoryIcon = '🛒';

  // Map Location Pin State
  double? _pinnedLat;
  double? _pinnedLng;
  String _pinnedCity = 'Erode';
  String _pinnedPincode = '638012';
  String _pinnedAddress = '';
  bool _hasPinnedLocation = false;

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://54.204.9.126:5000/api/v1';

  final List<Map<String, String>> _categories = [
    {'name': 'Grocery', 'icon': '🛒', 'desc': 'Provisions, Rice, Oil, Spices (மளிகை)'},
    {'name': 'Bakery & Snacks', 'icon': '🥖', 'desc': 'Cakes, Biscuits, Puffs, Sweets (பேக்கரி)'},
    {'name': 'Medicine & Pharmacy', 'icon': '💊', 'desc': 'Tablets, Health & Medicals (மருந்தகம்)'},
    {'name': 'Food & Restaurant', 'icon': '🍲', 'desc': 'Meals, Biryani, Fast Food (உணவகம்)'},
    {'name': 'Fruits & Vegetables', 'icon': '🍎', 'desc': 'Fresh Farm Veg & Fruits (காய்கறி)'},
    {'name': 'Meat & Fish', 'icon': '🥩', 'desc': 'Chicken, Mutton, Fish (இறைச்சி & மீன்)'},
    {'name': 'Dairy & Sweets', 'icon': '🥛', 'desc': 'Milk, Curd, Ghee, Sweets (பால் பொருட்கள்)'},
    {'name': 'Fancy & Stationery', 'icon': '🎁', 'desc': 'Books, Gifts, Toys, Cosmetics (ஃபேன்சி)'},
    {'name': 'Flower Stall', 'icon': '🌸', 'desc': 'Garlands, Pooja Flowers (பூக்கடை)'},
    {'name': 'Electronics & Mobile', 'icon': '📱', 'desc': 'Mobiles, Chargers, Accessories (மொபைல்)'},
    {'name': 'Clothing & Textiles', 'icon': '👔', 'desc': 'Ready-mades, Sarees, Garments (ஆடைகள்)'},
    {'name': 'Hardware & Electricals', 'icon': '🛠️', 'desc': 'Paints, Tools, Lights (ஹார்டுவேர்)'},
  ];

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _doorNoController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _businessEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Register as Partner',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkText,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Modern Step Indicator Header
            _buildCustomStepHeader(),

            // Step Content ScrollView
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.outfit(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_currentStep == 0) _buildStoreDetailsForm(),
                    if (_currentStep == 1) _buildBusinessDetailsForm(),
                    if (_currentStep == 2) _buildAccountForm(),
                    if (_currentStep == 3) _buildReviewForm(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Actions
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomStepHeader() {
    final steps = [
      {'title': 'Store', 'icon': Iconsax.shop},
      {'title': 'Business', 'icon': Iconsax.briefcase},
      {'title': 'Account', 'icon': Iconsax.user},
      {'title': 'Review', 'icon': Iconsax.tick_circle},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCompleted = _currentStep > index;
          final isCurrent = _currentStep == index;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : isCurrent
                                  ? AppTheme.primaryOrange
                                  : Colors.grey.shade100,
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : Text(
                                  '${index + 1}',
                                  style: GoogleFonts.outfit(
                                    color: isCurrent ? Colors.white : Colors.grey.shade500,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[index]['title'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: isCurrent
                              ? AppTheme.darkText
                              : isCompleted
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 24,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: isCompleted ? const Color(0xFF10B981) : Colors.grey.shade200,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep -= 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.darkText),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 3 ? const Color(0xFF10B981) : AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_currentStep == 3) ...[
                            const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _currentStep == 3 ? 'Submit Application' : 'Continue to Next Step',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMapLocationPicker() async {
    final combinedManual = [
      _doorNoController.text.trim(),
      _streetController.text.trim(),
      _areaController.text.trim(),
      _cityController.text.trim(),
    ].where((e) => e.isNotEmpty).join(', ');

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => VendorMapLocationPickerScreen(
          initialLocation: (_pinnedLat != null && _pinnedLng != null)
              ? LatLng(_pinnedLat!, _pinnedLng!)
              : null,
          initialAddress: _pinnedAddress.isNotEmpty ? _pinnedAddress : combinedManual,
          initialStoreName: _storeNameController.text.trim(),
          initialOwnerName: _ownerNameController.text.trim(),
          initialPhone: _phoneController.text.trim(),
          initialCategory: _selectedCategory,
          initialCity: _pinnedCity.isNotEmpty ? _pinnedCity : _cityController.text.trim(),
          initialPincode: _pinnedPincode.isNotEmpty ? _pinnedPincode : _pincodeController.text.trim(),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _pinnedLat = result['lat'] ?? result['latitude'];
        _pinnedLng = result['lng'] ?? result['longitude'];
        _pinnedCity = result['city'] ?? result['district'] ?? _cityController.text.trim();
        _pinnedPincode = result['pincode'] ?? _pincodeController.text.trim();
        _pinnedAddress = result['address'] ?? result['formattedAddress'] ?? '';
        final pinnedArea = (result['area'] ?? result['locality'] ?? '').toString().trim();
        _hasPinnedLocation = true;

        // Auto-fill and update Area/Locality, City/District, and PIN Code immediately
        if (pinnedArea.isNotEmpty) {
          _areaController.text = pinnedArea;
        }
        if (_pinnedCity.isNotEmpty) {
          _cityController.text = _pinnedCity;
        }
        if (_pinnedPincode.isNotEmpty) {
          _pincodeController.text = _pinnedPincode;
        }
      });
    }
  }

  // Modern Executive Bottom Sheet for Category Selection with Live Search
  void _openCategoryBottomSheet() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filteredCategories = _categories.where((cat) {
            if (searchQuery.isEmpty) return true;
            final name = (cat['name'] ?? '').toLowerCase();
            final desc = (cat['desc'] ?? '').toLowerCase();
            return name.contains(searchQuery) || desc.contains(searchQuery);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF0F172A), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Business Category',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              'கடையின் வகையைத் தேர்வு செய்யவும்',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live Category Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setSheetState(() => searchQuery = val.trim().toLowerCase());
                            },
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search category (மளிகை, Bakery, Food...)...',
                              hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Categories List
                Expanded(
                  child: filteredCategories.isNotEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: filteredCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final cat = filteredCategories[idx];
                            final isSelected = _selectedCategory == cat['name'];

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat['name']!;
                                  _selectedCategoryIcon = cat['icon'] ?? '🏷️';
                                });
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6).withOpacity(0.08)
                                          : Colors.black.withOpacity(0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Sleek Left Accent Indicator Pill
                                    Container(
                                      width: 4,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat['name']!,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w900,
                                              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (cat['desc'] != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              cat['desc']!,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12.5,
                                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                      )
                                    else
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text('No categories found', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                ),

                // Bottom + Add Custom Category Action Button
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddCustomCategorySheet();
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        label: Text(
                          '+ Add Custom Category / புதிய வகை சேர்க்க',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Clean Custom Category Creator Sheet (Category Name Only - No Icon Grid)
  void _showAddCustomCategorySheet() {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryOrange, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Custom Category',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.darkText),
                        ),
                        Text(
                          'புதிய வணிக வகையின் பெயரை உள்ளிடவும்',
                          style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.mediumText, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Category Name Input
              Text('Category Name / கடையின் வகை *', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: textController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Enter category name...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2)),
                ),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.darkText)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final newCat = textController.text.trim();
                        if (newCat.isNotEmpty) {
                          final exists = _categories.any((c) => c['name']!.toLowerCase() == newCat.toLowerCase());
                          if (!exists) {
                            setState(() {
                              _categories.insert(0, {
                                'name': newCat,
                                'icon': '🏷️',
                                'desc': 'Custom Category',
                              });
                              _selectedCategory = newCat;
                              _selectedCategoryIcon = '🏷️';
                            });
                          } else {
                            setState(() {
                              _selectedCategory = newCat;
                              _selectedCategoryIcon = '🏷️';
                            });
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Category "$newCat" created & selected!'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text('Create & Select', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleContinue() {
    setState(() => _errorMessage = null);
    if (_currentStep == 0) {
      if (_storeNameController.text.trim().isEmpty || _ownerNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Store name and owner name are required.');
        return;
      }
      if (_doorNoController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter Shop / Door No and Building Name.');
        return;
      }
      if (_streetController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter Street Name and Landmark.');
        return;
      }
      if (_areaController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter Area / Locality.');
        return;
      }
      if (_pincodeController.text.trim().length != 6) {
        setState(() => _errorMessage = 'Please enter a valid 6-digit PIN Code.');
        return;
      }
      if (!_hasPinnedLocation) {
        setState(() => _errorMessage = 'Please open the map and pin your exact shop location.');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_gstController.text.isNotEmpty && _gstController.text.length != 15) {
        setState(() => _errorMessage = 'GST Number must be 15 characters.');
        return;
      }
      if (_panController.text.isNotEmpty && _panController.text.length != 10) {
        setState(() => _errorMessage = 'PAN Number must be 10 characters.');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_phoneController.text.isEmpty || _phoneController.text.length < 10) {
        setState(() => _errorMessage = 'Valid 10-digit phone number is required.');
        return;
      }
      if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
        setState(() => _errorMessage = 'Password must be at least 6 characters.');
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _submitRegistration();
    }
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final fullManualAddress = '${_doorNoController.text.trim()}, ${_streetController.text.trim()}, ${_areaController.text.trim()}, ${_cityController.text.trim()} - ${_pincodeController.text.trim()}';

    final payload = {
      'storeName': _storeNameController.text.trim(),
      'ownerName': _ownerNameController.text.trim(),
      'address': fullManualAddress,
      'storeAddress': fullManualAddress,
      'doorNo': _doorNoController.text.trim(),
      'street': _streetController.text.trim(),
      'area': _areaController.text.trim(),
      'city': _cityController.text.trim(),
      'pincode': _pincodeController.text.trim(),
      'category': _selectedCategory,
      'phone': _phoneController.text.trim(),
      'password': _passwordController.text,
      'formattedAddress': fullManualAddress,
      if (_emailController.text.isNotEmpty) 'email': _emailController.text.trim(),
      if (_businessEmailController.text.isNotEmpty) 'businessEmail': _businessEmailController.text.trim(),
      if (_gstController.text.isNotEmpty) 'gstNumber': _gstController.text.trim(),
      if (_panController.text.isNotEmpty) 'panNumber': _panController.text.trim(),
      if (_pinnedLat != null && _pinnedLng != null) ...{
        'lat': _pinnedLat,
        'lng': _pinnedLng,
        'latitude': _pinnedLat,
        'longitude': _pinnedLng,
        'location': {
          'type': 'Point',
          'coordinates': [_pinnedLng, _pinnedLat],
          'city': _cityController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'formattedAddress': fullManualAddress,
        },
      },
    };

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/register-vendor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(res.body);

      if (res.statusCode == 201 && data['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WaitingApprovalScreen(
              storeName: _storeNameController.text.trim(),
              vendorId: data['vendor']['_id'] ?? '',
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = data['error'] ?? 'Registration failed. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Cannot connect to server. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStoreDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Store Identity', 'Enter basic details and exact address of your store'),
        const SizedBox(height: 16),
        _buildModernCleanTextField(_storeNameController, 'Store Name *', hintText: 'Enter store name'),
        const SizedBox(height: 16),
        _buildModernCleanTextField(_ownerNameController, 'Owner Full Name *', hintText: 'Enter owner full name'),
        const SizedBox(height: 22),

        // 1. GPS Map Location Pin Card (At the top of the Location section)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hasPinnedLocation ? const Color(0xFF10B981) : Colors.grey.shade300,
              width: _hasPinnedLocation ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hasPinnedLocation
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _hasPinnedLocation ? const Color(0xFFD1FAE5) : AppTheme.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _hasPinnedLocation ? Icons.check_circle_rounded : Iconsax.location,
                      color: _hasPinnedLocation ? const Color(0xFF059669) : AppTheme.primaryOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _hasPinnedLocation ? 'Shop Location Pinned!' : 'Pin Shop on Map *',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: _hasPinnedLocation ? const Color(0xFF065F46) : AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('📍', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        if (_hasPinnedLocation) ...[
                          const SizedBox(height: 3),
                          Text(
                            _pinnedAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'GPS: ${_pinnedLat?.toStringAsFixed(5)}, ${_pinnedLng?.toStringAsFixed(5)} • ${_cityController.text.trim()} - ${_pincodeController.text.trim()}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Set exact map pin for accurate delivery routing',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.mediumText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openMapLocationPicker,
                  icon: Icon(
                    _hasPinnedLocation ? Icons.edit_location_alt_rounded : Icons.map_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _hasPinnedLocation ? 'Change Pinned Location on Map' : 'Open Map & Pin Shop Location',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasPinnedLocation ? const Color(0xFF10B981) : AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Area / Locality (Auto-filled from Map Pin)
        _buildModernCleanTextField(
          _areaController,
          'Area / Locality *',
          hintText: 'Enter area or locality',
        ),
        const SizedBox(height: 14),

        // 3. City & Pincode (Auto-filled from Map Pin)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildModernCleanTextField(
                _cityController,
                'City / District *',
                hintText: 'Enter city',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildModernCleanTextField(
                _pincodeController,
                'PIN Code *',
                keyboardType: TextInputType.number,
                hintText: 'PIN code',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. Door / Shop No / Complex Name
        _buildModernCleanTextField(
          _doorNoController,
          'Shop / Door No & Complex / Building Name *',
          hintText: 'Enter door no / shop no / building name',
        ),
        const SizedBox(height: 14),

        // 5. Street Name & Landmark
        _buildModernCleanTextField(
          _streetController,
          'Street Name & Landmark *',
          hintText: 'Enter street name and landmark',
        ),
        const SizedBox(height: 22),

        // Business Category Selection Card at the BOTTOM of the page
        Text(
          'Business Category *',
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkText),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _openCategoryBottomSheet,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCategory,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to change category or add custom',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.mediumText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0F172A), size: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildBusinessDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Tax & Legal Info', 'Optional details for fast verified partner status'),
        const SizedBox(height: 16),
        _buildModernCleanTextField(
          _gstController,
          'GST Number (optional)',
          hintText: 'Enter 15-digit GST number (e.g. 33ABCDE1234F1Z5)',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            UpperCaseTextFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(15),
          ],
        ),
        const SizedBox(height: 16),
        _buildModernCleanTextField(
          _panController,
          'PAN Number (optional)',
          hintText: 'Enter 10-digit PAN number (e.g. ABCDE1234F)',
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            UpperCaseTextFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 16),
        _buildModernCleanTextField(
          _businessEmailController,
          'Business Email',
          keyboardType: TextInputType.emailAddress,
          hintText: 'Enter business email',
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildAccountForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Login Credentials', 'Used to sign in to your vendor dashboard'),
        const SizedBox(height: 16),
        _buildModernCleanTextField(_phoneController, 'Phone Number *', keyboardType: TextInputType.phone, hintText: 'Enter 10-digit mobile number'),
        const SizedBox(height: 16),
        _buildModernCleanTextField(_emailController, 'Owner Email (optional)', keyboardType: TextInputType.emailAddress, hintText: 'Enter owner email address'),
        const SizedBox(height: 16),
        _buildModernCleanTextField(
          _passwordController,
          'Set Password *',
          obscureText: _obscurePassword,
          hintText: 'Enter password (minimum 6 characters)',
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Iconsax.eye_slash : Iconsax.eye, color: AppTheme.mediumText, size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildReviewForm() {
    final fullManual = '${_doorNoController.text.trim()}, ${_streetController.text.trim()}, ${_areaController.text.trim()}, ${_cityController.text.trim()} - ${_pincodeController.text.trim()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Review Details', 'Please verify your application before submission'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Store Application Summary',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.darkText),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _currentStep = 0),
                    icon: const Icon(Iconsax.edit, size: 14, color: AppTheme.primaryOrange),
                    label: Text('Edit All', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange)),
                  ),
                ],
              ),
              const Divider(height: 24),
              _reviewRow('Store Name', _storeNameController.text, stepIndex: 0),
              _reviewRow('Owner', _ownerNameController.text, stepIndex: 0),
              _reviewRow('Category', '$_selectedCategoryIcon $_selectedCategory', stepIndex: 0),
              _reviewRow('Door / Complex', _doorNoController.text, stepIndex: 0),
              _reviewRow('Street & Landmark', _streetController.text, stepIndex: 0),
              _reviewRow('Area / Locality', _areaController.text, stepIndex: 0),
              _reviewRow('City & Pincode', '${_cityController.text} - ${_pincodeController.text}', stepIndex: 0),
              if (_pinnedAddress.isNotEmpty)
                _reviewRow('GPS Map Area', _pinnedAddress, stepIndex: 0),
              if (_pinnedLat != null && _pinnedLng != null)
                _reviewRow('Coordinates', '${_pinnedLat!.toStringAsFixed(5)}, ${_pinnedLng!.toStringAsFixed(5)}', stepIndex: 0),
              _reviewRow('Full Address', fullManual, stepIndex: 0),
              _reviewRow('Phone', _phoneController.text, stepIndex: 2),
              if (_gstController.text.isNotEmpty) _reviewRow('GST No', _gstController.text, stepIndex: 1),
              if (_panController.text.isNotEmpty) _reviewRow('PAN No', _panController.text, stepIndex: 1),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'After submission, our Super Admin team will verify your store and approve your account within 24 hours.',
                  style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.brown.shade900, fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.darkText, letterSpacing: -0.3),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.mediumText, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value, {int? stepIndex}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.darkText),
            ),
          ),
          if (stepIndex != null)
            GestureDetector(
              onTap: () => setState(() => _currentStep = stepIndex),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Iconsax.edit_2, size: 14, color: AppTheme.primaryOrange),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernCleanTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? hintText,
    Widget? suffixIcon,
    TextCapitalization? textCapitalization,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.darkText),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            obscureText: obscureText,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization ??
                ((keyboardType == TextInputType.emailAddress ||
                        keyboardType == TextInputType.phone ||
                        keyboardType == TextInputType.number ||
                        obscureText)
                    ? TextCapitalization.none
                    : TextCapitalization.words),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.darkText),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400, fontWeight: FontWeight.w500, fontSize: 13),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
