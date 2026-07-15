import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';

class CustomShopOrderScreen extends StatefulWidget {
  const CustomShopOrderScreen({super.key});

  @override
  State<CustomShopOrderScreen> createState() => _CustomShopOrderScreenState();
}

class _CustomShopOrderScreenState extends State<CustomShopOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _shopAddressCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  // 🪄 Smart Draft Persistence (Sync with Store Detail style)
  List<Map<String, String>> _draftItems = [];
  String _draftNotes = "";
  XFile? _draftPhoto;

  // For Any Store Delivery, we don't have a pre-selected store,
  // we use the user-inputted name and address.

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    super.dispose();
  }

  void _confirmCustomOrder(BuildContext ctx, OrderType type, String content, {String? photoPath}) {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Confirm Order?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('உங்கள் order விவரங்களை அனுப்ப விருப்பமா?', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text('Free to Place Order', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF065F46))),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Delivery team விலையை கண்டுபிடித்து quote அனுப்புவார்கள். Accept பண்ணினாலே Pay ஆகும்.',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF065F46), height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              );

              try {
                await orderProvider.placeCustomOrder(
                  customStoreName: _shopNameCtrl.text.trim(),
                  customStoreAddress: _shopAddressCtrl.text.trim(),
                  userAddress: auth.address,
                  lat: auth.selectedAddress.lat,
                  lng: auth.selectedAddress.lng,
                  type: type,
                  content: content,
                  photoPath: photoPath,
                );
                
                if (mounted) {
                  _draftItems = []; // Clear drafts on success
                  _draftNotes = "";
                  _draftPhoto = null;
                  
                  Navigator.pop(context);      // Pop loading
                  Navigator.pop(confirmCtx);   // Close confirm dialog
                  Navigator.pop(ctx);          // Close bottom sheet
                  _showSuccessDialog();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Pop loading
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Confirm Order', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 64),
          const SizedBox(height: 16),
          Text('Order Sent!', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            'உங்கள் ஆர்டர் டெலிவரி பார்ட்னருக்கு அனுப்பப்பட்டது. அவர் கடையைத் தேடிப் பிடித்து பொருட்களை வாங்குவார்.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
          ),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('சபாஷ்! (Great)'),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Any Store Delivery', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEliteHeader(),
              const SizedBox(height: 32),
              _buildInputLabel('Shop Name / கடையின் பெயர்'),
              _buildTextField(_shopNameCtrl, 'e.g. Saravana Store, Nellai Appala Kadai...', Iconsax.shop),
              const SizedBox(height: 20),
              _buildInputLabel('Shop Area / இடம் (Landmark)'),
              _buildTextField(_shopAddressCtrl, 'e.g. T.Nagar, Near Bus Stand...', Iconsax.location),
              const SizedBox(height: 40),
              Text('How do you want to order?', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 16),
              _buildOrderOption(
                title: 'Text Order',
                subtitle: 'பொருட்களின் பெயர்களை டைப் செய்யவும்',
                icon: Iconsax.document_text,
                color: const Color(0xFF4F46E5),
                onTap: _showTextOrderSheet,
              ),
              const SizedBox(height: 16),
              _buildOrderOption(
                title: 'Photo Order',
                subtitle: 'லிஸ்ட் அல்லது பொருட்களை போட்டோ எடுக்கவும்',
                icon: Iconsax.camera,
                color: const Color(0xFF7C3AED),
                onTap: _showPhotoOrderSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEliteHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Icon(Iconsax.magicpen, color: Colors.white, size: 40),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Personal Assistant Mode', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          Text('நாங்கள் எந்த கடையிலிருந்தும் பொருட்களை வாங்கி வருவோம்!', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.blueGrey.shade800)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextFormField(
        controller: ctrl,
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blueGrey.shade300, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
        ),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildOrderOption({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          ])),
          Icon(Iconsax.arrow_right_3, color: Colors.grey, size: 18),
        ]),
      ),
    );
  }

  // ── Elite Structured Text Order (Copied from StoreDetail) ──
  void _showTextOrderSheet() {
    if (!_formKey.currentState!.validate()) return;

    final List<Map<String, String>> items = List.from(_draftItems);
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: _draftNotes);
    int? editingIndex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24, right: 24, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Iconsax.document_text, color: Color(0xFF4F46E5), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Shopping List', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('டைப் செய்து வரிசையாகச் சேர்க்கவும்', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ),
              ]),
              
              const SizedBox(height: 24),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: itemCtrl,
                        onChanged: (val) => setS(() {}),
                        decoration: InputDecoration(
                          hintText: 'Item Name (e.g. Milk)',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                        ),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: qtyCtrl,
                        decoration: InputDecoration(
                          hintText: 'Qty',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF4F46E5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      if (itemCtrl.text.trim().isNotEmpty) {
                        setS(() {
                          if (editingIndex != null) {
                            items[editingIndex!] = {
                              'name': itemCtrl.text.trim().toUpperCase(),
                              'qty': qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim().toUpperCase(),
                            };
                            editingIndex = null;
                          } else {
                            items.add({
                              'name': itemCtrl.text.trim().toUpperCase(),
                              'qty': qtyCtrl.text.trim().isEmpty ? '1' : qtyCtrl.text.trim().toUpperCase(),
                            });
                          }
                          itemCtrl.clear();
                          qtyCtrl.clear();
                          _draftItems = List.from(items);
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _getSuggestedQuantities(itemCtrl.text.trim()).map((q) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(q, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800)),
                      onPressed: () {
                        setS(() {
                          qtyCtrl.text = q;
                        });
                      },
                      backgroundColor: Colors.white,
                      labelStyle: const TextStyle(color: Color(0xFF4F46E5)),
                      side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  )).toList(),
                ),
              ),
              
              if (items.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Items Added', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey)),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.3),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: editingIndex == i ? const Color(0xFF4F46E5).withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: editingIndex == i ? const Color(0xFF4F46E5).withOpacity(0.2) : Colors.grey.shade100),
                      ),
                      child: Row(children: [
                        Text('${i+1}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(items[i]['name']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14))),
                        Text(items[i]['qty']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF4F46E5))),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => setS(() {
                            items.removeAt(i);
                            _draftItems = List.from(items);
                          }),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              TextField(
                controller: notesCtrl,
                onChanged: (val) => _draftNotes = val,
                decoration: InputDecoration(
                  hintText: 'Additional notes (optional)',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Iconsax.edit, size: 20),
                ),
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: items.isEmpty ? null : () {
                    String formattedMsg = "I want these items from ${_shopNameCtrl.text}:\n";
                    for (int i=0; i < items.length; i++) {
                      formattedMsg += "${i + 1}. ${items[i]['name']} (Qty: ${items[i]['qty']})\n";
                    }
                    if (notesCtrl.text.isNotEmpty) {
                      formattedMsg += "\nNote: ${notesCtrl.text}";
                    }
                    _confirmCustomOrder(ctx, OrderType.text, formattedMsg);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Confirm Order List', style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sophisticated Photo Order (Copied from StoreDetail) ──
  void _showPhotoOrderSheet() {
    if (!_formKey.currentState!.validate()) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Photo Order', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            _photoOptionBtn(
              icon: Iconsax.camera,
              label: 'Camera-ல் Photo எடு',
              color: const Color(0xFF7C3AED),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (img != null && mounted) _showPhotoPreview(img);
              },
            ),
            const SizedBox(height: 12),
            _photoOptionBtn(
              icon: Iconsax.gallery,
              label: 'Gallery-ல் இருந்து எடு',
              color: const Color(0xFF10B981),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (img != null && mounted) _showPhotoPreview(img);
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showPhotoPreview(XFile img) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Photo Preview', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(img.path), height: 250, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _confirmCustomOrder(ctx, OrderType.photo, "Check photo for details", photoPath: img.path);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Send Photo Order', style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ]),
      ),
    );
  }

  Widget _photoOptionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Icon(Iconsax.arrow_right_3, color: color.withOpacity(0.3), size: 18),
        ]),
      ),
    );
  }

  List<String> _getSuggestedQuantities(String itemName) {
    if (itemName.isEmpty) return ['1', '2', '3', '5', '10'];
    final name = itemName.toLowerCase();
    
    final liquids = ['milk', 'oil', 'ghee', 'water', 'curd', 'juice', 'paal', 'ennai', 'tayir'];
    if (liquids.any((l) => name.contains(l))) {
      return ['500 ML', '1 L', '1.5 L', '2 L', '5 L'];
    }

    final groceries = ['rice', 'sugar', 'flour', 'dal', 'tomato', 'potato', 'onion', 'arisi', 'uppu', 'sakkarai', 'chicken'];
    if (groceries.any((g) => name.contains(g))) {
      return ['250 G', '500 G', '1 KG', '1.5 KG', '2 KG', '5 KG'];
    }

    return ['1', '2', '3', '5', '12', '1 KG', '1 L'];
  }
}
