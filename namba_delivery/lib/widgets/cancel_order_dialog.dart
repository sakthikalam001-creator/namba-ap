import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CancelOrderDialog extends StatefulWidget {
  final String role; // 'Vendor', 'Delivery Partner', 'Customer'
  final Function(String reason) onConfirm;

  const CancelOrderDialog({
    super.key,
    required this.role,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String role,
    required Function(String reason) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CancelOrderDialog(role: role, onConfirm: onConfirm),
    );
  }

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  int _selectedIndex = -1;
  final TextEditingController _otherReasonController = TextEditingController();

  List<String> get _reasons {
    if (widget.role == 'Vendor') {
      return [
        '📦 Items / Ingredients Out of Stock (பொருட்கள் இருப்பு இல்லை)',
        '🏪 Store Closing for the Day (கடை மூடும் நேரம்)',
        '⚡ Kitchen Overloaded / High Order Volume (அதிக பணிச்சுமை)',
        '💰 Item Unavailable / Price Mismatch (பொருள் / விலை மாற்றம்)',
        '✏️ Other Reason (மற்றக் காரணங்கள் - டைப் செய்யவும்)',
      ];
    } else if (widget.role == 'Delivery Partner') {
      return [
        '📱 Customer Unreachable / Phone Switched Off (வாடிக்கையாளர் போனை எடுக்கவில்லை)',
        '📍 Address Out of Service Coverage Area (எல்லைக்கு வெளியே உள்ளது)',
        '🚲 Vehicle Mechanical Breakdown / Emergency (வாகனப் பழுது / அவசரநிலை)',
        '🌧️ Severe Weather / Heavy Rain Conditions (கடுமையான வானிலை / மழை)',
        '✏️ Other Reason (மற்றக் காரணங்கள் - டைப் செய்யவும்)',
      ];
    } else {
      // Customer
      return [
        '❌ Placed Order by Mistake (தவறாக ஆர்டர் செய்துவிட்டேன்)',
        '⏳ Long Delivery Time / ETA Too High (டெலிவரி நேரம் அதிகம்)',
        '📝 Need to Change Items or Delivery Address (ஆர்டர் விபரங்களை மாற்ற வேண்டும்)',
        '🏬 Change of Plans / No Longer Needed (ஆர்டர் தேவைப்படவில்லை)',
        '✏️ Other Reason (மற்றக் காரணங்கள் - டைப் செய்யவும்)',
      ];
    }
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedIndex < 0) return;

    String finalReason = _reasons[_selectedIndex];
    if (_selectedIndex == 4) {
      final custom = _otherReasonController.text.trim();
      if (custom.isEmpty) return;
      finalReason = 'Other: $custom';
    }

    widget.onConfirm(finalReason);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancel Order',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Select a reason for cancellation (${widget.role})',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Scrollable Options List
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._reasons.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final text = entry.value;
                        final isSelected = _selectedIndex == idx;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedIndex = idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEF4444).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFEF4444) : Colors.grey.shade200,
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: isSelected ? const Color(0xFFEF4444) : Colors.grey.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_selectedIndex == 4) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _otherReasonController,
                          autofocus: true,
                          maxLines: 2,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.outfit(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type your cancellation reason here...',
                            hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: Colors.grey.shade400),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Actions Row (Pinned at bottom)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Keep Order',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_selectedIndex < 0 || (_selectedIndex == 4 && _otherReasonController.text.trim().isEmpty))
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        disabledBackgroundColor: Colors.grey.shade200,
                      ),
                      child: Text(
                        'Confirm Cancel',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
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
}
