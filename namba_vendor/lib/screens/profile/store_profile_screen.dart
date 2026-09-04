import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10))],
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.white, width: 5),
                        image: DecorationImage(
                          image: (profile?.storePhoto != null && profile!.storePhoto.isNotEmpty)
                              ? NetworkImage(profile.storePhoto.startsWith('http') ? profile.storePhoto : 'http://54.204.9.126:5000${profile.storePhoto}')
                              : const NetworkImage('https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _handleStorePhotoTap(profile),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (profile?.allowStorePhotoEdit == true) ? AppTheme.primaryOrange : const Color(0xFF64748B),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Icon(
                            (profile?.allowStorePhotoEdit == true) ? Iconsax.camera : Icons.lock_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Basic Information'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (profile?.allowBasicInfoEdit == true)
                          ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                          : const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (profile?.allowBasicInfoEdit == true)
                            ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                            : const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (profile?.allowBasicInfoEdit == true) ? Icons.lock_open_rounded : Icons.lock_rounded,
                          size: 12,
                          color: (profile?.allowBasicInfoEdit == true) ? const Color(0xFF6366F1) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (profile?.allowBasicInfoEdit == true) ? 'Unlocked by Admin' : 'Verified by Admin',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: (profile?.allowBasicInfoEdit == true) ? const Color(0xFF6366F1) : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFC7D2FE),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (profile?.allowBasicInfoEdit == true) ? Icons.edit_note_rounded : Icons.shield_rounded,
                      size: 18,
                      color: const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (profile?.allowBasicInfoEdit == true)
                            ? 'Admin has unlocked basic info editing. Tap edit icons to update your details.'
                            : 'Store name, address & phone are registered and locked. Contact Admin to request changes.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1. Store Name
              _buildInfoCard(
                label: 'Store Name',
                value: profile?.storeName ?? _nameController.text,
                icon: Iconsax.shop,
                isDark: isDark,
                isEditable: profile?.allowBasicInfoEdit == true,
                onEdit: () => _showEditInfoDialog('storeName', 'Store Name', profile?.storeName ?? _nameController.text),
                lockMessage: 'Store Name is verified on registration and can only be updated when Admin unlocks.',
              ),
              const SizedBox(height: 12),

              // 2. Store Address
              _buildInfoCard(
                label: 'Store Address',
                value: profile?.address ?? _addressController.text,
                icon: Iconsax.location,
                isDark: isDark,
                isEditable: profile?.allowBasicInfoEdit == true,
                onEdit: () => _showEditInfoDialog('address', 'Store Address', profile?.address ?? _addressController.text),
                lockMessage: 'Store Address is verified. Contact Admin Support to update location.',
              ),
              if (profile?.allowLocationEdit == true) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
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
              ],
              const SizedBox(height: 12),

              // 3. Contact Number
              _buildInfoCard(
                label: 'Contact Number',
                value: profile?.phone ?? _phoneController.text,
                icon: Iconsax.call,
                isDark: isDark,
                isEditable: profile?.allowBasicInfoEdit == true,
                onEdit: () => _showEditInfoDialog('phone', 'Contact Number', profile?.phone ?? _phoneController.text),
                lockMessage: 'Contact Number is registered with your account. Contact Admin to update.',
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
                                color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText,
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
                                color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
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
    final canEdit = (profile?.allowPaymentEdit == true) || qrUrl.isEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                      ),
                    ),
                    Text(
                      'Riders can view or scan your QR code during pickup',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (qrUrl.isNotEmpty) ...[
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
                  if (!canEdit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '🔒 Verified QR Code (Contact Admin to update)',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (canEdit)
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
    final profile = context.read<VendorOrderProvider>().profile;
    final canUseGallery = profile?.allowGalleryUpload == true;
    ImageSource? source = ImageSource.camera;

    if (canUseGallery) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Upload Shop UPI / Payment QR',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take a photo of your shop QR stand or choose from gallery',
                  style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.camera_alt_rounded, size: 36, color: Color(0xFF4F46E5)),
                              const SizedBox(height: 10),
                              Text('Camera Photo', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF4F46E5))),
                              Text('Take a photo now', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.photo_library_rounded, size: 36, color: Color(0xFF059669)),
                              const SizedBox(height: 10),
                              Text('Gallery Image', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF059669))),
                              Text('Choose from files', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
      if (source == null) return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Opening Camera for Live QR Capture (Gallery restricted by Admin)'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;

    if (!mounted) return;
    final provider = context.read<VendorOrderProvider>();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading Shop QR Code... ⏳')),
    );

    try {
      final uploadedUrl = await provider.uploadImage(image.path);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        await provider.updateProfileDetails({
          'qrCodeUrl': uploadedUrl,
          'paymentDetailsLocked': true,
          'allowPaymentEdit': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Shop QR Code uploaded & verified successfully! 🔒 Locked for security.'),
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

  Future<void> _handleStorePhotoTap(VendorProfileModel? profile) async {
    if (profile?.allowStorePhotoEdit != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('🔒 Store Photo is locked. Request Admin in Manage Access to allow photo change.')),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading Store Photo... ⏳')),
    );

    try {
      final provider = context.read<VendorOrderProvider>();
      final uploadedUrl = await provider.uploadImage(image.path);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        await provider.updateProfileDetails({
          'storePhoto': uploadedUrl,
          'image': uploadedUrl,
          'storePhotoUrl': uploadedUrl,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Store Photo updated successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showEditInfoDialog(String key, String label, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit $label',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : AppTheme.darkText),
        ),
        content: TextField(
          controller: controller,
          keyboardType: key == 'phone' ? TextInputType.phone : TextInputType.text,
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.darkText),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.outfit(color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleFieldSave(key, label, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required bool isEditable,
    required VoidCallback? onEdit,
    required String lockMessage,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: _floatingBoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isEditable ? AppTheme.primaryOrange : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryOrange, size: 20),
              onPressed: onEdit,
            )
          else
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(lockMessage)),
                      ],
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLockedInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required String message,
  }) {
    return _buildInfoCard(
      label: label,
      value: value,
      icon: icon,
      isDark: isDark,
      isEditable: false,
      onEdit: null,
      lockMessage: message,
    );
  }

  Widget _buildGpayNumberSection() {
    final profile = context.watch<VendorOrderProvider>().profile;
    final gpayNum = profile?.gpayNumber ?? '';
    final upiId = profile?.upiId ?? '';
    final hasDetails = gpayNum.isNotEmpty || upiId.isNotEmpty;
    final canEdit = (profile?.allowPaymentEdit == true) || !hasDetails;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Pay / PhonePe / UPI Details',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText,
                      ),
                    ),
                    Text(
                      'Riders will transfer customer order payments to these details',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasDetails) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFFA7F3D0),
                ),
              ),
              child: Column(
                children: [
                  if (gpayNum.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'UPI Number: ',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE2E8F0) : AppTheme.darkText,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            gpayNum,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF059669)),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: gpayNum));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('UPI Number copied! 📋'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  if (gpayNum.isNotEmpty && upiId.isNotEmpty)
                    Divider(color: isDark ? Colors.white12 : Colors.green.shade100, height: 16),
                  if (upiId.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.alternate_email_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'UPI ID: ',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE2E8F0) : AppTheme.darkText,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            upiId,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF059669)),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: upiId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('UPI ID copied! 📋'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (canEdit)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
              label: Text(
                hasDetails ? 'UPDATE UPI / GPAY DETAILS' : 'ADD UPI / GPAY DETAILS',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
              ),
              onPressed: () => _showGpayNumberDialog(gpayNum, upiId),
            ),
        ],
      ),
    );
  }

  void _showGpayNumberDialog(String currentNum, String currentUpiId) {
    final phoneController = TextEditingController(text: currentNum);
    final upiIdController = TextEditingController(text: currentUpiId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'UPI & Mobile Payment',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your UPI Mobile Number & UPI ID so delivery riders can send order payments directly.',
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'UPI Mobile Number',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 9876543210',
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400),
                prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF059669), size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'UPI ID / VPA Address',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: upiIdController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. yourstore@oksbi / 9876543210@upi',
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400),
                prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF059669), size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              final newNum = phoneController.text.trim();
              final newUpiId = upiIdController.text.trim();
              if (newNum.isNotEmpty || newUpiId.isNotEmpty) {
                Navigator.pop(ctx);
                await context.read<VendorOrderProvider>().updateProfileDetails({
                  'gpayNumber': newNum,
                  'upiId': newUpiId,
                  'vendorUpiNumber': newNum,
                  'vendorUpiId': newUpiId,
                  'paymentDetailsLocked': true,
                  'allowPaymentEdit': false,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎉 UPI Details saved & verified! 🔒 Locked for security.'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
              }
            },
            child: Text('Save & Lock', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white)),
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
                            color: isDark ? Colors.white : AppTheme.darkText,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : AppTheme.darkText),
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
                              color: isSelected
                                  ? (isDark ? const Color(0xFF1E1B4B) : AppTheme.lightSurface)
                                  : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1.0,
                              ),
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
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF818CF8) : AppTheme.primaryOrange)
                                      : (isDark ? const Color(0xFFF8FAFC) : AppTheme.darkText),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: isDark ? const Color(0xFF818CF8) : AppTheme.primaryOrange,
                                      size: 20,
                                    ),
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
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: isDark ? const Color(0xFFF87171) : AppTheme.primaryRed,
                                        size: 20,
                                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        title: Text(
          'Edit Business Category',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.darkText,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter new category name',
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.darkText),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: isDark ? const Color(0xFF94A3B8) : AppTheme.mediumText, fontWeight: FontWeight.w600)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        title: Text(
          'New Business Category',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.darkText,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter category name',
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          style: GoogleFonts.outfit(color: isDark ? Colors.white : AppTheme.darkText),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: isDark ? const Color(0xFF94A3B8) : AppTheme.darkText, fontWeight: FontWeight.w600)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Iconsax.translate, color: AppTheme.primaryOrange, size: 22),
            const SizedBox(width: 10),
            Text(
              lang.isTamil ? 'மொழியைத் தேர்வு செய்க' : 'Select Language',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : AppTheme.darkText,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Option 1: Tamil (தமிழ்)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: lang.currentLanguage == AppLanguage.tamil
                  ? (isDark ? const Color(0xFF4338CA).withValues(alpha: 0.3) : AppTheme.primaryOrange.withValues(alpha: 0.1))
                  : Colors.transparent,
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('த', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF6366F1))),
              ),
              title: Text(
                'தமிழ் (Tamil)',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.darkText,
                ),
              ),
              subtitle: Text(
                'எளிய தமிழ் வடிவம்',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
              ),
              trailing: lang.currentLanguage == AppLanguage.tamil
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange)
                  : null,
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
              tileColor: lang.currentLanguage == AppLanguage.tanglish
                  ? (isDark ? const Color(0xFF4338CA).withValues(alpha: 0.3) : AppTheme.primaryOrange.withValues(alpha: 0.1))
                  : Colors.transparent,
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('த/E', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF6366F1), fontSize: 11)),
              ),
              title: Text(
                'Tanglish (தமிழ்)',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.darkText,
                ),
              ),
              subtitle: Text(
                'Tamil in English text (Kadai, Orders)',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
              ),
              trailing: lang.currentLanguage == AppLanguage.tanglish
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange)
                  : null,
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
              tileColor: lang.currentLanguage == AppLanguage.english
                  ? (isDark ? const Color(0xFF4338CA).withValues(alpha: 0.3) : AppTheme.primaryOrange.withValues(alpha: 0.1))
                  : Colors.transparent,
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('EN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF6366F1))),
              ),
              title: Text(
                'English',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.darkText,
                ),
              ),
              subtitle: Text(
                'Standard English Interface',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade500),
              ),
              trailing: lang.currentLanguage == AppLanguage.english
                  ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryOrange)
                  : null,
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
