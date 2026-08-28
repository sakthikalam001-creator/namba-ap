import os
import re

file_path = r"d:\New folder (2)\namba_delivery\lib\screens\orders\delivery_order_detail_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

widget_code = """
class QuoteSubmitForm extends StatefulWidget {
  final DeliveryOrder order;
  final DeliveryProvider provider;
  
  const QuoteSubmitForm({Key? key, required this.order, required this.provider}) : super(key: key);

  @override
  _QuoteSubmitFormState createState() => _QuoteSubmitFormState();
}

class _QuoteSubmitFormState extends State<QuoteSubmitForm> {
  late TextEditingController amountCtrl;
  late TextEditingController gpayCtrl;
  String? localQrPath;
  String? localBillPath;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    amountCtrl = TextEditingController(
      text: widget.order.totalAmount > 0 ? widget.order.totalAmount.toStringAsFixed(0) : '',
    );
    gpayCtrl = TextEditingController(text: widget.order.vendorGpayNumber ?? '');
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    gpayCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBill, bool fromCamera) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75, // Optimize size
    );
    
    if (image != null) {
      setState(() {
        if (isBill) {
          localBillPath = image.path;
        } else {
          localQrPath = image.path;
        }
      });
    }
  }

  void _submitQuote() async {
    final amtText = amountCtrl.text.trim();
    if (amtText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the original bill amount.')));
      return;
    }

    final double? billAmt = double.tryParse(amtText);
    if (billAmt == null || billAmt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid bill amount.')));
      return;
    }

    // Bill Photo is Optional but recommended, however logic says it's required if we want to sync. 
    // Usually we allow if they enter the amount.
    
    setState(() => isSubmitting = true);

    try {
      final success = await widget.provider.submitShopQuote(
        orderId: widget.order.id,
        shopBillAmount: billAmt,
        gpayNumber: gpayCtrl.text.trim(),
        billImagePath: localBillPath,
        qrImagePath: localQrPath,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote details submitted successfully!')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit. Please try again.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Submit Shop Bill & Details', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
                    Text('கடை பில் தொகை, பில் படம் & Shop QR விவரங்களை அனுப்பவும்', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. BILL AMOUNT (MANDATORY)
          Text('1. ORIGINAL BILL AMOUNT (பொருட்களின் மொத்த விலை) *', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
              hintText: '0.00',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
            ),
          ),
          const SizedBox(height: 10),

          // ── LIVE FARE BREAKDOWN (SHOP BILL + DELIVERY FEE) ─────────────────
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: amountCtrl,
            builder: (context, val, _) {
              final enteredBill = double.tryParse(val.text) ?? 0.0;
              final deliveryFee = widget.order.deliveryFee > 0 ? widget.order.deliveryFee : (widget.order.totalAmount > 0 ? widget.order.totalAmount : 0.0);
              final totalCustomerPays = enteredBill + deliveryFee;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Shop / Items Bill (பொருட்கள் விலை):', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        Text('₹${enteredBill.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('Delivery Fee (டெலிவரி கட்டணம்):', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            if (widget.order.distanceInKm > 0) ...[
                              const SizedBox(width: 4),
                              Text('(${widget.order.distanceInKm.toStringAsFixed(1)} KM)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF6366F1))),
                            ],
                          ],
                        ),
                        Text('+₹${deliveryFee.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Customer Pays (மொத்த தொகை):', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: const Color(0xFF1E1B4B))),
                        Text('₹${totalCustomerPays.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 2. SHOP BILL PHOTO (CAMERA / GALLERY)
          Row(
            children: [
              Text('2. SHOP BILL PHOTO (கடை பில் ரசீது படம்)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('ADMIN SYNC', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF059669))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (localBillPath != null) ...[
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(localBillPath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
                GestureDetector(
                  onTap: () => setState(() => localBillPath = null),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(true, true),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF059669)),
                  label: Text('Snap Shop Bill', style: GoogleFonts.outfit(color: const Color(0xFF059669), fontWeight: FontWeight.w800, fontSize: 11)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF059669)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(true, false),
                  icon: const Icon(Icons.photo_library_rounded, size: 16, color: Colors.grey),
                  label: Text('Gallery', style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w800, fontSize: 11)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. SHOP QR CODE (OPTIONAL)
          Text('3. SHOP QR CODE (கடை கூகுள் பே QR கோட் - Optional)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          if (localQrPath != null) ...[
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(localQrPath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
                GestureDetector(
                  onTap: () => setState(() => localQrPath = null),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(false, true),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF4F46E5)),
                  label: Text('Snap Shop QR', style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w800, fontSize: 11)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF4F46E5)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(false, false),
                  icon: const Icon(Icons.photo_library_rounded, size: 16, color: Colors.grey),
                  label: Text('Gallery', style: GoogleFonts.outfit(color: Colors.grey.shade700, fontWeight: FontWeight.w800, fontSize: 11)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. GPAY OR PHONE NUMBER
          Text('4. SHOP GPAY / PHONE NUMBER (Optional - கடை எண்)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: gpayCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E1B4B)),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_iphone_rounded, color: Colors.grey, size: 18),
              hintText: 'e.g. 9876543210',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
            ),
          ),
          const SizedBox(height: 24),

          // SUBMIT BUTTON
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: isSubmitting ? null : _submitQuote,
              child: isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('SUBMIT BILL & SHOP PAYMENT DETAILS', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
"""

if "class QuoteSubmitForm" not in content:
    content = content.replace("}\n", widget_code + "\n}\n", 1) # Insert at the very end

# Now replace Case 3 in _buildVendorQrCodeCard
# Search for Case 3 comment block
pattern = r"// Case 3: Initial State - Need to Enter Quote & Snap Shop QR \(Clean Tap Banner\).*?return InkWell\(.*?onTap: \(\) => _showQuoteDialog.*?child: Container\(.*?width: double.infinity,.*?margin: const EdgeInsets.only\(bottom: 16\),.*?padding: const EdgeInsets.all\(16\),.*?decoration: BoxDecoration\(.*?color: const Color\(0xFFEEF2FF\),.*?borderRadius: BorderRadius.circular\(20\),.*?border: Border.all\(color: const Color\(0xFF6366F1\)\.withValues\(alpha: 0.35\)\),.*?child: Row\(.*?children: \[.*?Container\(.*?padding: const EdgeInsets.all\(10\),.*?decoration: BoxDecoration\(.*?color: const Color\(0xFF6366F1\),.*?borderRadius: BorderRadius.circular\(12\),.*?\),.*?child: const Icon\(Icons.receipt_long_rounded, color: Colors.white, size: 22\),.*?\),.*?const SizedBox\(width: 14\),.*?Expanded\(.*?child: Column\(.*?crossAxisAlignment: CrossAxisAlignment.start,.*?children: \[.*?Row\(.*?children: \[.*?Text\(.*?'STEP 1: SUBMIT BILL & QR',.*?style: GoogleFonts.outfit\(.*?fontSize: 12,.*?fontWeight: FontWeight.w900,.*?color: const Color\(0xFF312E81\),.*?letterSpacing: 0.5,.*?\),.*?\),.*?const Spacer\(\),.*?const Icon\(Icons.arrow_forward_ios_rounded, size: 12, color: Color\(0xFF6366F1\)\),.*?\],.*?\),.*?const SizedBox\(height: 2\),.*?Text\(.*?'கடை பில் தொகை, பில் ரசீது & Shop QR விவரங்களை உள்ளிடவும்\.',.*?style: GoogleFonts.outfit\(fontSize: 11, color: const Color\(0xFF4338CA\), fontWeight: FontWeight.w600\),.*?\),.*?\],.*?\),.*?\),.*?\],.*?\),.*?\),.*?;"
replacement = """// Case 3: Initial State - Need to Enter Quote & Snap Shop QR (Inline Form)
    return QuoteSubmitForm(order: order, provider: provider);"""

content_new = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content_new)

print("Done")
