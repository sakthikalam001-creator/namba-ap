import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../models/vendor_product_model.dart';
import '../../services/vendor_inventory_provider.dart';

class EditProductScreen extends StatefulWidget {
  final VendorProductModel product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late String _selectedCategory;
  late bool _isAvailable;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(text: widget.product.description);
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(0));
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _selectedCategory = widget.product.category;
    _isAvailable = widget.product.isAvailable;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final updatedProduct = widget.product.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          price: double.parse(_priceController.text),
          stock: int.parse(_stockController.text),
          category: _selectedCategory,
          isAvailable: _isAvailable,
        );

        await context.read<VendorInventoryProvider>().updateProduct(updatedProduct);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating product: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: AppTheme.darkText, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text(
                'Edit Product',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.darkText),
              ),
            ],
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
              _buildSectionTitle('Product Details'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'Product Name',
                hint: 'e.g. Red Apples',
                validator: (v) => v!.isEmpty ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Short description of product',
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Pricing & Inventory'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Price (₹)',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'Stock Level',
                      hint: '0',
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Category & Availability'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showCategoryBottomSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: _floatingBoxDecoration(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                          const SizedBox(height: 4),
                          Text(
                            _selectedCategory.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: AppTheme.mediumText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: _floatingBoxDecoration(),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    'Mark as Available',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.darkText),
                  ),
                  value: _isAvailable,
                  activeColor: AppTheme.accentGreen,
                  onChanged: (v) => setState(() => _isAvailable = v),
                ),
              ),
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
                  onPressed: _isSaving ? null : _updateProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      )
                    : Text(
                        'Update Product',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 16),
              // Delete Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _confirmDelete(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    'Delete Product',
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to remove this item from your inventory?', style: GoogleFonts.outfit()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await context.read<VendorInventoryProvider>().deleteProduct(widget.product.id);
              if (mounted) Navigator.pop(context); // Close edit screen
            },
            child: Text('Delete', style: GoogleFonts.outfit(color: AppTheme.primaryRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  List<String> _getDropdownCategories(BuildContext context) {
    final provider = context.read<VendorInventoryProvider>();
    final deleted = provider.deletedCategories;
    final products = provider.products;
    
    return [
      ...AppCategories.defaultCategories,
      ...products.map((p) => p.category)
    ].map((cat) {
      return AppCategories.defaultCategories.firstWhere(
        (c) => c.toLowerCase() == cat.toLowerCase(),
        orElse: () => cat,
      );
    })
    .where((cat) => !deleted.map((d) => d.toLowerCase()).contains(cat.toLowerCase()))
    .toSet()
    .toList();
  }

  void _showCategoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Consumer<VendorInventoryProvider>(
          builder: (context, provider, child) {
            final availableCategories = _getDropdownCategories(context);

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Category',
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
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableCategories.length,
                      itemBuilder: (context, index) {
                        final cat = availableCategories[index];
                        final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                        final isDeletable = cat.toLowerCase() != 'other';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.lightSurface : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                _selectedCategory = cat;
                              });
                              Navigator.pop(context);
                            },
                            title: Text(
                              cat.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppTheme.primaryOrange : AppTheme.darkText,
                              ),
                            ),
                            trailing: isDeletable
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.primaryRed),
                                    onPressed: () {
                                      _confirmDeleteCategoryInSheet(context, provider, cat);
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddCustomCategoryDialog(context);
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        'Add Custom Category',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategoryInSheet(BuildContext context, VendorInventoryProvider provider, String categoryName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Category?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to delete "$categoryName"? All products in this category will be moved to "Other".',
          style: GoogleFonts.outfit(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              if (_selectedCategory.toLowerCase() == categoryName.toLowerCase()) {
                setState(() {
                  _selectedCategory = 'Other';
                });
              }
              await provider.deleteCategory(categoryName);
            },
            child: Text('Delete', style: GoogleFonts.outfit(color: AppTheme.primaryRed, fontWeight: FontWeight.w700)),
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
        title: Text('New Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
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
                setState(() {
                  _selectedCategory = val;
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Add', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w700)),
          ),
        ],
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
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: _floatingBoxDecoration(),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.darkText),
        decoration: _floatingInputDecoration(label).copyWith(hintText: hint),
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

  InputDecoration _floatingInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: AppTheme.mediumText, fontWeight: FontWeight.w500),
      hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.w400),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    );
  }
}

