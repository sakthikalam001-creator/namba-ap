import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/language_provider.dart';
import '../../services/vendor_order_provider.dart';
import 'package:provider/provider.dart';
import 'earnings_screen.dart';
import '../../services/navigation_provider.dart';
import 'vendor_extra_screens.dart';
import '../../widgets/permissions_wizard_sheet.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 20),
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
                  color: AppTheme.darkText,
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
                icon: Icons.access_time_rounded, color: const Color(0xFF4F46E5),
                title: 'Operating Hours', subtitle: 'Set store timings',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperatingHoursScreen())),
              ),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.bar_chart_rounded, color: const Color(0xFF059669),
                title: 'Order Report', subtitle: 'Revenue & analytics',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderReportScreen(orders: context.read<VendorOrderProvider>().orders.map((o) => {'status': o.status.name, 'totalAmount': o.totalAmount}).toList()))),
              ),
              const SizedBox(height: 12),
              _buildNavCard(
                icon: Icons.settings_suggest_rounded, color: const Color(0xFF10B981),
                title: 'System Permission Checklist', subtitle: 'Check notification & sound settings',
                onTap: () => PermissionsWizardSheet.show(context),
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
              SizedBox(height: bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCard({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: Colors.grey.shade100)
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
            child: Icon(icon, color: color, size: 24)
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.darkText, height: 1.2)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.mediumText, fontWeight: FontWeight.w500)),
          ])),
          Icon(Icons.arrow_forward_ios, color: Colors.grey.shade300, size: 16),
        ]),
      ),
    );
  }

  Widget _buildEarningsLink(LanguageProvider lang) {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.1),
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
                      color: AppTheme.darkText,
                    ),
                  ),
                  Text(
                    'Track your revenue and payouts',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.mediumText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.lightText, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppTheme.darkText,
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
    return Container(
      decoration: _floatingBoxDecoration(),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onFieldSubmitted: onSubmitted,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.darkText),
        decoration: _floatingInputDecoration(label, icon),
      ),
    );
  }

  BoxDecoration _floatingBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      border: Border.all(color: Colors.grey.shade100, width: 2),
    );
  }

  InputDecoration _floatingInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: AppTheme.mediumText, fontWeight: FontWeight.w500),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
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
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
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
              final val = textController.text.trim();
              if (val.isNotEmpty) {
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
}
