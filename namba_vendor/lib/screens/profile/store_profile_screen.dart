import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/language_provider.dart';
import '../../services/theme_provider.dart';
import '../../services/vendor_order_provider.dart';
import 'package:provider/provider.dart';
import 'earnings_screen.dart';
import '../../services/navigation_provider.dart';
import 'vendor_extra_screens.dart';
import '../splash_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../auth/vendor_map_location_picker_screen.dart';
import '../../services/alert_service.dart';

class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  String _selectedCategory = 'Grocery';
  final List<String> _categories = ['Grocery', 'Bakery', 'Medicines', 'Fruits & Vegetables', 'Meat & Fish'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();

    // Populate profile details after initial frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });

    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) {
        _handleFieldSave('storeName', 'Store Name', _nameController.text);
      }
    });

    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus) {
        _handleFieldSave('address', 'Store Address', _addressController.text);
      }
    });

    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus) {
        _handleFieldSave('phone', 'Contact Number', _phoneController.text);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _addressFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _loadProfileData() {
    final profile = context.read<VendorOrderProvider>().profile;
    if (profile != null) {
      setState(() {
        _nameController.text = profile.storeName;
        _addressController.text = profile.address;
        _phoneController.text = profile.phone;
        if (profile.category.isNotEmpty) {
          if (!_categories.contains(profile.category)) {
            _categories.insert(0, profile.category);
          }
          _selectedCategory = profile.category;
        }
      });
    }
  }

  Future<void> _handleFieldSave(String key, String label, String newValue) async {
    final provider = context.read<VendorOrderProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    String currentValue = '';
    if (key == 'storeName') currentValue = profile.storeName;
    else if (key == 'address') currentValue = profile.address;
    else if (key == 'phone') currentValue = profile.phone;
    else if (key == 'category') currentValue = profile.category;

    final trimmedNew = newValue.trim();
    if (trimmedNew == currentValue.trim() || trimmedNew.isEmpty) return;

    // Show Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Update / உறுதிசெய்',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to update $label to "$trimmedNew"?\n\n$label -ஐ "$trimmedNew" என மாற்ற விரும்புகிறீர்களா?',
          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel (ரத்து)', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Confirm (உறுதிசெய்)', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await provider.updateProfileDetails({key: trimmedNew});
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $label updated successfully!'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to update $label. Try again.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _resetFieldToCurrent(key, currentValue);
        }
      }
    } else {
      _resetFieldToCurrent(key, currentValue);
    }
  }

  void _resetFieldToCurrent(String key, String currentValue) {
    setState(() {
      if (key == 'storeName') _nameController.text = currentValue;
      else if (key == 'address') _addressController.text = currentValue;
      else if (key == 'phone') _phoneController.text = currentValue;
      else if (key == 'category') _selectedCategory = currentValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final profile = Provider.of<VendorOrderProvider>(context).profile;

    // Keep controllers synced if profile loaded/updated from socket or API
    if (profile != null) {
      if (!_nameFocus.hasFocus && _nameController.text != profile.storeName) {
        _nameController.text = profile.storeName;
      }
      if (!_addressFocus.hasFocus && _addressController.text != profile.address) {
        _addressController.text = profile.address;
      }
      if (!_phoneFocus.hasFocus && _phoneController.text != profile.phone) {
        _phoneController.text = profile.phone;
      }
    }

    final double bottomPadding = MediaQuery.of(context).padding.bottom + 140;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText, size: 20),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Provider.of<NavigationProvider>(context, listen: false).backToDashboard();
                  }
                },
              ),
              const SizedBox(width: 8),
              Text(
                lang.translate('profile'),
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10))],
                        border: Border.all(color: Colors.white, width: 6),
                        image: const DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Iconsax.camera, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ).animate().scale(duration: 400.ms),
              ),
              const SizedBox(height: 32),
              _buildEarningsLink(lang),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.star_rounded, color: const Color(0xFFF59E0B),
                title: 'Customer Ratings', subtitle: 'See what customers think',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerRatingsScreen())),
              ),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.local_offer_rounded, color: const Color(0xFF7C3AED),
                title: 'Coupons & Offers', subtitle: 'Create discount codes',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouponsOffersScreen())),
              ),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.campaign_rounded, color: const Color(0xFF2563EB),
                title: 'In-App Advertisements', subtitle: 'Run banner ads in Customer App',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VendorAdCampaignsScreen())),
              ),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.access_time_rounded, color: const Color(0xFF4F46E5),
                title: 'Operating Hours', subtitle: 'Set store timings',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperatingHoursScreen())),
              ),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.bar_chart_rounded, color: const Color(0xFF059669),
                title: 'Order Report', subtitle: 'Revenue & analytics',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderReportScreen())),
              ),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.settings_suggest_rounded, color: const Color(0xFF10B981),
                title: 'System Permission Checklist', subtitle: 'Check notification & sound settings',
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const PermissionEnforcerDialog(),
                ),
              ),
              const SizedBox(height: 12),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return _buildNavCard(
                    icon: themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: const Color(0xFF6366F1),
                    title: themeProvider.isDarkMode ? 'Dark Mode (இருண்ட பயன்முறை)' : 'Light Mode (வெள்ளை பயன்முறை)',
                    subtitle: 'Tap to switch dark & white mode',
                    onTap: () {
                      themeProvider.toggleTheme();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(themeProvider.isDarkMode ? '🌙 Dark Mode Activated' : '☀️ Light Mode Activated'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Consumer<LanguageProvider>(
                builder: (context, langProvider, _) {
                  return _buildNavCard(
                    icon: Iconsax.translate,
                    color: const Color(0xFF0EA5E9),
                    title: 'App Language / மொழி',
                    subtitle: '${langProvider.languageName} • Tap to change',
                    onTap: () => _showProfileLanguageDialog(context),
                  );
                },
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                focusNode: _nameFocus,
                label: 'Store Name',
                icon: Iconsax.shop,
                onSubmitted: (val) => _handleFieldSave('storeName', 'Store Name', val),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                focusNode: _addressFocus,
                label: 'Store Address',
                icon: Iconsax.location,
                maxLines: 2,
                onSubmitted: (val) => _handleFieldSave('address', 'Store Address', val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final profile = context.read<VendorOrderProvider>().profile;
                    LatLng? initLoc;
                    if (profile != null && profile.latitude != 0 && profile.longitude != 0) {
                      initLoc = LatLng(profile.latitude, profile.longitude);
                    }
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VendorMapLocationPickerScreen(
                          initialLocation: initLoc,
                          initialAddress: _addressController.text.trim(),
                        ),
                      ),
                    );
                    if (result != null && mounted) {
                      final lat = (result['latitude'] ?? result['lat']) as double;
                      final lng = (result['longitude'] ?? result['lng']) as double;
                      final addr = (result['address'] ?? result['formattedAddress'] ?? '') as String;
                      _addressController.text = addr;
                      await context.read<VendorOrderProvider>().updateProfileDetails({
                        'address': addr,
                        'lat': lat,
                        'lng': lng,
                        'latitude': lat,
                        'longitude': lng,
                        'city': result['city'] ?? '',
                        'pincode': result['pincode'] ?? '',
                        'location': {
                          'type': 'Point',
                          'coordinates': [lng, lat],
                          'formattedAddress': addr,
                          'city': result['city'] ?? '',
                          'pincode': result['pincode'] ?? '',
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shop location pinned & updated successfully! 📍'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.pin_drop_rounded, size: 18, color: AppTheme.primaryOrange),
                  label: Text('Pin / Update Location on Map', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.primaryOrange)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primaryOrange.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                label: 'Contact Number',
                icon: Iconsax.call,
                keyboardType: TextInputType.phone,
                onSubmitted: (val) => _handleFieldSave('phone', 'Contact Number', val),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Business Category'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showBusinessCategoryBottomSheet(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: _floatingBoxDecoration(),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.category, color: AppTheme.primaryOrange, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category',
                              style: GoogleFonts.outfit(
                                color: AppTheme.mediumText,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedCategory.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryOrange, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Shop Payment / UPI Details'),
              const SizedBox(height: 16),
              _buildShopQrCodeSection(),
              const SizedBox(height: 16),
              _buildGpayNumberSection(),
              SizedBox(height: bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopQrCodeSection() {
    final profile = context.watch<VendorOrderProvider>().profile;
    final qrUrl = profile?.qrCodeUrl ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _floatingBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF4F46E5), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store UPI / Payment QR Code',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkText,
                      ),
                    ),
                    Text(
                      'Riders can view or scan your QR code during pickup',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (qrUrl.isNotEmpty)
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      qrUrl.startsWith('http') ? qrUrl : 'http://54.204.9.126:5000$qrUrl',
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.qr_code_2_rounded, size: 100, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
            label: Text(
              qrUrl.isNotEmpty ? 'CHANGE SHOP QR CODE' : 'UPLOAD SHOP QR CODE',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
            ),
            onPressed: _uploadShopQrCode,
          ),
        ],
      ),
    );
  }

  Future<void> _uploadShopQrCode() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    final provider = context.read<VendorOrderProvider>();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading Shop QR Code...')),
    );

    try {
      final uploadedUrl = await provider.uploadImage(image.path);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        await provider.updateProfileDetails({'qrCodeUrl': uploadedUrl});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Shop QR Code uploaded successfully! Delivery riders can now view/scan it.'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload QR Code: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildGpayNumberSection() {
    final profile = context.watch<VendorOrderProvider>().profile;
    final gpayNum = profile?.gpayNumber ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _floatingBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Pay / PhonePe Number',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkText,
                      ),
                    ),
                    Text(
                      'Enter your UPI registered mobile number for rider payments',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (gpayNum.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'GPay Number: ',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkText),
                  ),
                  Text(
                    gpayNum,
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF059669)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            label: Text(
              gpayNum.isNotEmpty ? 'UPDATE GPAY NUMBER' : 'ADD GPAY NUMBER',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
            ),
            onPressed: () => _showGpayNumberDialog(gpayNum),
          ),
        ],
      ),
    );
  }

  void _showGpayNumberDialog(String currentNum) {
    final controller = TextEditingController(text: currentNum);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Google Pay / UPI Mobile Number', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riders can view & copy this number to transfer order payments directly.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter 10-digit GPay number',
                prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF059669)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newNum = controller.text.trim();
              if (newNum.isEmpty) return;
              Navigator.pop(ctx);
              final provider = context.read<VendorOrderProvider>();
              final ok = await provider.updateProfileDetails({'gpayNumber': newNum});
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🎉 Google Pay number updated successfully!'), backgroundColor: Color(0xFF059669)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update Google Pay number'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Text('SAVE GPAY NUMBER', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), 
            child: Icon(icon, color: color, size: 24)
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText, height: 1.2)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.outfit(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText, fontWeight: FontWeight.w500)),
          ])),
          Icon(Icons.arrow_forward_ios, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade300, size: 16),
        ]),
      ),
    );
  }

  Widget _buildEarningsLink(LanguageProvider lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EarningsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: isDark ? const Color(0xFF273552) : AppTheme.primaryOrange.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.wallet, color: AppTheme.primaryOrange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('earnings'),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                    ),
                  ),
                  Text(
                    'Track your revenue and payouts',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: isDark ? const Color(0xFF64748B) : AppTheme.lightText, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onSubmitted,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: _floatingBoxDecoration(),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: (keyboardType == TextInputType.number ||
                keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.emailAddress)
            ? TextCapitalization.none
            : TextCapitalization.words,
        onFieldSubmitted: onSubmitted,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.darkText),
        decoration: _floatingInputDecoration(label, icon, isDark),
      ),
    );
  }

  BoxDecoration _floatingBoxDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF131B2E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      border: Border.all(color: isDark ? const Color(0xFF273552) : Colors.grey.shade100, width: 1.5),
    );
  }

  InputDecoration _floatingInputDecoration(String label, IconData icon, [bool isDark = false]) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText, fontWeight: FontWeight.w500),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(icon, color: AppTheme.primaryOrange, size: 22),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  void _showBusinessCategoryBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final bottomPadding = mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 24;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Business Category',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkText,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: mediaQuery.size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.lightSurface : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(context);
                                if (_selectedCategory != cat) {
                                  setState(() => _selectedCategory = cat);
                                  _handleFieldSave('category', 'Business Category', cat);
                                }
                              },
                              title: Text(
                                cat.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? AppTheme.primaryOrange : AppTheme.darkText,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryOrange, size: 20),
                                    onPressed: () {
                                      _showEditCategoryDialog(context, cat, (newName) {
                                        setSheetState(() {
                                          final idx = _categories.indexOf(cat);
                                          if (idx != -1) _categories[idx] = newName;
                                        });
                                      });
                                    },
                                  ),
                                  if (_categories.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.primaryRed, size: 20),
                                      onPressed: () {
                                        setSheetState(() {
                                          _categories.remove(cat);
                                          if (_selectedCategory == cat && _categories.isNotEmpty) {
                                            _selectedCategory = _categories.first;
                                          }
                                        });
                                        setState(() {});
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryOrange, Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddCustomCategoryDialog(context);
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        label: Text(
                          'Add Custom Category',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCategoryDialog(BuildContext context, String oldName, Function(String) onSaved) {
    final textController = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Business Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter new category name',
            hintStyle: GoogleFonts.outfit(),
          ),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.mediumText, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              final raw = textController.text.trim();
              if (raw.isNotEmpty) {
                final newName = raw.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');
                Navigator.pop(ctx);
                onSaved(newName);
                if (_selectedCategory.toLowerCase() == oldName.toLowerCase()) {
                  setState(() {
                    _selectedCategory = newName;
                  });
                  _handleFieldSave('category', 'Business Category', newName);
                }
              }
            },
            child: Text('Save', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddCustomCategoryDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Business Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter category name',
            hintStyle: GoogleFonts.outfit(),
          ),
          style: GoogleFonts.outfit(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              final raw = textController.text.trim();
              if (raw.isNotEmpty) {
                final val = raw.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');
                if (!_categories.contains(val)) {
                  _categories.insert(0, val);
                }
                setState(() {
                  _selectedCategory = val;
                });
                Navigator.pop(ctx);
                _handleFieldSave('category', 'Business Category', val);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: Text('Add & Save', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showProfileLanguageDialog(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Iconsax.translate, color: AppTheme.primaryOrange, size: 22),
            const SizedBox(width: 10),
            Text(
              lang.isTamil ? 'மொழியைத் தேர்வு செய்க' : 'Select Language',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option 1: Tamil (தமிழ்)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: lang.currentLanguage == AppLanguage.tamil ? AppTheme.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
              leading: const Text('🇮🇳', style: TextStyle(fontSize: 22)),
              title: Text('தமிழ் (Tamil)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              subtitle: Text('செந்தமிழ் முழு வடிவம்', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              trailing: lang.currentLanguage == AppLanguage.tamil ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange) : null,
              onTap: () {
                lang.setLanguage(AppLanguage.tamil);
                Navigator.pop(ctx);
                AlertService.showToast('மொழி தமிழுக்கு மாற்றப்பட்டது ✅');
              },
            ),
            const SizedBox(height: 8),
            // Option 2: Tanglish (தமிழ்)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: lang.currentLanguage == AppLanguage.tanglish ? AppTheme.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
              leading: const Text('🇮🇳', style: TextStyle(fontSize: 22)),
              title: Text('Tanglish (தமிழ்)', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              subtitle: Text('Tamil in English text (Kadai, Orders)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              trailing: lang.currentLanguage == AppLanguage.tanglish ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange) : null,
              onTap: () {
                lang.setLanguage(AppLanguage.tanglish);
                Navigator.pop(ctx);
                AlertService.showToast('Language switched to Tanglish ✅');
              },
            ),
            const SizedBox(height: 8),
            // Option 3: English
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: lang.currentLanguage == AppLanguage.english ? AppTheme.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
              title: Text('English', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              subtitle: Text('Standard English Interface', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              trailing: lang.currentLanguage == AppLanguage.english ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange) : null,
              onTap: () {
                lang.setLanguage(AppLanguage.english);
                Navigator.pop(ctx);
                AlertService.showToast('Language switched to English ✅');
              },
            ),
          ],
        ),
      ),
    );
  }
}
