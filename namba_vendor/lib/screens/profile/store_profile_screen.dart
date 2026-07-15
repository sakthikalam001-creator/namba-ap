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

class StoreProfileScreen extends StatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Fresh Mart Store');
  final _addressController = TextEditingController(text: '123, Gandhi Road, Chennai');
  final _phoneController = TextEditingController(text: '+91 9876543210');
  String _selectedCategory = 'Grocery';

  final List<String> _categories = ['Grocery', 'Bakery', 'Medicines', 'Fruits & Vegetables', 'Meat & Fish'];

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Provider.of<NavigationProvider>(context, listen: false).backToDashboard();
            }
          },
        ),
        title: Text(
          lang.translate('profile'),
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkText,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 32),
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'Store Name',
                icon: Iconsax.shop,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: 'Store Address',
                icon: Iconsax.location,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Contact Number',
                icon: Iconsax.call,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Business Category'),
              const SizedBox(height: 16),
              Container(
                decoration: _floatingBoxDecoration(),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _floatingInputDecoration('Category', Iconsax.category),
                items: _categories.map((String category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category, style: GoogleFonts.outfit()),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
            ),
              const SizedBox(height: 32),
              _buildSectionTitle('Operating Hours'),
              const SizedBox(height: 16),
              _buildBusinessHoursCard(lang),
              const SizedBox(height: 48),
              Container(
                width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryOrange, AppTheme.primaryDeepOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      final isLocked = Provider.of<VendorOrderProvider>(context, listen: false).isLocked;
                      if (isLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Account Locked: Action not allowed. Please contact support.'),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated successfully!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessHoursCard(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildHourRow('Monday - Friday', '09:00 AM - 10:00 PM'),
          const Divider(height: 24),
          _buildHourRow('Saturday - Sunday', '08:00 AM - 11:00 PM'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showHoursPicker(lang),
              icon: const Icon(Iconsax.edit, size: 18),
              label: Text('Edit Schedule', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourRow(String days, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(days, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
        Text(time, style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.mediumText)),
      ],
    );
  }

  void _showHoursPicker(LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set Opening Hours', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            _buildPickerRow('Opening Time', '09:00 AM'),
            const SizedBox(height: 16),
            _buildPickerRow('Closing Time', '10:00 PM'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Update Schedule', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerRow(String label, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(time, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.primaryOrange)),
        ),
      ],
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
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: _floatingBoxDecoration(),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
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
}

