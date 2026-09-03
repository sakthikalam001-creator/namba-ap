import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';

class CustomerSupportScreen extends StatefulWidget {
  final String? initialOrderId;
  final String? initialOrderDisplayId;
  final String? initialCategory;

  const CustomerSupportScreen({
    super.key,
    this.initialOrderId,
    this.initialOrderDisplayId,
    this.initialCategory,
  });

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerApiService _apiService = CustomerApiService();

  // Form State
  String _selectedCategory = 'Damaged Product / Broken Item';
  String _selectedPriority = 'High';
  String? _selectedOrderId;
  String? _selectedOrderDisplayId;
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  File? _pickedImageFile;
  bool _isSubmitting = false;

  // Tickets List State
  List<Map<String, dynamic>> _myTickets = [];
  bool _isLoadingTickets = false;

  final List<Map<String, dynamic>> _categories = [
    {'title': 'Damaged Product / Broken Item', 'icon': Icons.broken_image_rounded, 'desc': 'Product arrived damaged, leaked, or broken'},
    {'title': 'Order Delay / Food Issue', 'icon': Icons.fastfood_rounded, 'desc': 'Delivery taking longer or item delayed'},
    {'title': 'Refund / Payment Deducted', 'icon': Icons.account_balance_wallet_rounded, 'desc': 'Money debited or refund inquiry'},
    {'title': 'Missing / Wrong Items', 'icon': Icons.remove_shopping_cart_rounded, 'desc': 'Items delivered incorrectly or missing'},
    {'title': 'Address & GPS Pin Issue', 'icon': Icons.location_on_rounded, 'desc': 'Need driver to navigate to alternate location'},
    {'title': 'App / Technical Bug', 'icon': Icons.bug_report_rounded, 'desc': 'App freezing, checkout error, or crash'},
    {'title': 'General Support', 'icon': Icons.help_outline_rounded, 'desc': 'Any other platform question or feedback'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedOrderId = widget.initialOrderId;
    _selectedOrderDisplayId = widget.initialOrderDisplayId;

    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    if (_selectedOrderDisplayId != null) {
      _subjectCtrl.text = 'Issue with Order #$_selectedOrderDisplayId';
    }

    _loadMyTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final host = CustomerApiService.baseUrl.replaceAll('/api/v1', '');
    return '$host${path.startsWith('/') ? path : '/$path'}';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 75);
      if (picked != null) {
        setState(() {
          _pickedImageFile = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _loadMyTickets() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final phone = auth.phone;
    if (phone.isEmpty) return;

    setState(() => _isLoadingTickets = true);
    final tickets = await _apiService.fetchMyTickets(phone, userType: 'Customer');
    if (mounted) {
      setState(() {
        _myTickets = tickets;
        _isLoadingTickets = false;
      });
    }
  }

  Future<void> _submitTicket() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userName = auth.name.isNotEmpty ? auth.name : 'Customer';
    final userPhone = auth.phone;
    final message = _messageCtrl.text.trim();
    final subject = _subjectCtrl.text.trim().isNotEmpty
        ? _subjectCtrl.text.trim()
        : '$_selectedCategory - $userName';

    if (userPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please login to submit a support ticket')),
      );
      return;
    }

    if (message.isEmpty && _pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please describe your issue or attach a photo proof')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? uploadedImageUrl;
    if (_pickedImageFile != null) {
      uploadedImageUrl = await _apiService.uploadImage(_pickedImageFile!.path);
    }

    final payload = {
      'userType': 'Customer',
      'userId': auth.uid,
      'userName': userName,
      'userPhone': userPhone,
      'subject': subject,
      'category': _selectedCategory,
      'issueType': _selectedCategory,
      'priority': _selectedPriority,
      'orderId': _selectedOrderId,
      'orderDisplayId': _selectedOrderDisplayId ?? '',
      'message': message,
      if (uploadedImageUrl != null && uploadedImageUrl.isNotEmpty) 'imageUrl': uploadedImageUrl,
    };

    final result = await _apiService.createSupportTicket(payload);
    setState(() => _isSubmitting = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Ticket #${result['ticketId'] ?? ''} created! Our resolution team is on it.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _messageCtrl.clear();
      _subjectCtrl.clear();
      setState(() => _pickedImageFile = null);
      _loadMyTickets();
      _tabController.animateTo(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to raise ticket. Please try again.'), backgroundColor: Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support & Help Desk', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF0F172A))),
            Text('Fast resolution for orders & payments', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            const Tab(text: 'RAISE NEW ISSUE'),
            Tab(text: 'MY TICKETS (${_myTickets.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRaiseTicketTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Dynamic Smart Problem Assistant ──
  Widget _buildRaiseTicketTab() {
    final orderProvider = Provider.of<OrderProvider>(context);
    final orders = orderProvider.orders;

    final query = _messageCtrl.text.toLowerCase();
    
    // Smart Intent Detection
    final bool isDamaged = query.contains('damage') || query.contains('broken') || query.contains('spill') || 
        query.contains('leak') || query.contains('odanj') || query.contains('spoiled') || query.contains('setham') || 
        query.contains('kettupo') || query.contains('waste') || _selectedCategory.contains('Damaged');
        
    final bool isMissing = query.contains('miss') || query.contains('illai') || query.contains('varala') || 
        query.contains('left out') || query.contains('shortage') || query.contains('kammi') || 
        query.contains('maranthu') || _selectedCategory.contains('Missing');
        
    final bool isDelay = query.contains('delay') || query.contains('late') || query.contains('time') || 
        query.contains('where') || query.contains('rider') || query.contains('driver') || query.contains('slow') || 
        query.contains('eppo') || query.contains('tracking') || _selectedCategory.contains('Delay');
        
    final bool isPayment = query.contains('refund') || query.contains('payment') || query.contains('money') || 
        query.contains('deduct') || query.contains('upi') || query.contains('cut') || query.contains('kaasu') || 
        query.contains('panam') || query.contains('gpay') || _selectedCategory.contains('Refund');

    DeliveryOrder? selectedOrder;
    if (_selectedOrderId != null && orders.isNotEmpty) {
      try {
        selectedOrder = orders.firstWhere((o) => o.id == _selectedOrderId);
      } catch (_) {}
    } else if (orders.isNotEmpty) {
      selectedOrder = orders.first;
    }

    final quickPills = [
      {'title': 'Damaged Product (பொருள் சேதம்)', 'category': 'Damaged Product / Broken Item', 'icon': Icons.broken_image_rounded, 'color': const Color(0xFFEA580C)},
      {'title': 'Missing Item (பொருள் வரல)', 'category': 'Missing / Wrong Items', 'icon': Icons.remove_shopping_cart_rounded, 'color': const Color(0xFFDC2626)},
      {'title': 'Order Delay (டெலிவரி லேட்)', 'category': 'Order Delay / Food Issue', 'icon': Icons.access_time_filled_rounded, 'color': const Color(0xFFD97706)},
      {'title': 'Refund Issue (பணம் வரல)', 'category': 'Refund / Payment Deducted', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF2563EB)},
      {'title': 'Address Help (முகவரி மாற்றம்)', 'category': 'Address & GPS Pin Issue', 'icon': Icons.location_on_rounded, 'color': const Color(0xFF7C3AED)},
      {'title': 'General Support (மற்றவை)', 'category': 'General Support', 'icon': Icons.help_outline_rounded, 'color': const Color(0xFF475569)},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Namba Instant Helpdesk', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('உங்கள் பிரச்சனையை டைப் செய்யுங்கள், உடனடி தீர்வு பெறலாம்!', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Order Link Selector
          if (orders.isNotEmpty) ...[
            Text('SELECT ORDER TO GET HELP:', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF475569), letterSpacing: 0.5)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: orders.take(5).map((ord) {
                  final isSelected = (_selectedOrderId == ord.id) || (_selectedOrderId == null && ord == orders.first);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedOrderId = ord.id;
                        _selectedOrderDisplayId = ord.displayId.isNotEmpty ? ord.displayId : ord.id;
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 14, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Order #${ord.displayId.isNotEmpty ? ord.displayId : ord.id.substring(0, 6)}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Problem Input Box
          Text('DESCRIBE YOUR ISSUE (உங்கள் பிரச்சனை என்ன?):', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: TextField(
              controller: _messageCtrl,
              maxLines: 3,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type what happened (e.g. food was damaged, item missing, delay, refund)...',
                hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Selection Pills
          Text('OR QUICKLY TAP YOUR ISSUE:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickPills.map((p) {
              final isMatching = _selectedCategory == p['category'];
              final color = p['color'] as Color;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = p['category'] as String;
                    if (_messageCtrl.text.isEmpty) {
                      _messageCtrl.text = p['title'] as String;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMatching ? color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isMatching ? color : const Color(0xFFE2E8F0), width: isMatching ? 1.5 : 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p['icon'] as IconData, size: 14, color: isMatching ? color : const Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Text(
                        p['title'] as String,
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: isMatching ? color : const Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // ── DYNAMIC ACTION CARDS (MORPHS BASED ON TYPED INPUT) ──

          // 1. DYNAMIC DAMAGED ITEM CARD
          if (isDamaged) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFFEA580C), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📸 PHOTO PROOF REQUIRED FOR REFUND', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFC2410C), letterSpacing: 0.5)),
                            Text('சேதமடைந்த பொருளின் புகைப்படத்தை இப்போதே எடுக்கவும்', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF9A3412), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_pickedImageFile != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.file(
                            _pickedImageFile!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                            onPressed: () => setState(() => _pickedImageFile = null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: Text('Open Live Camera', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFFC2410C)),
                            label: Text('From Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFFC2410C))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFFDBA74)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. DYNAMIC MISSING ITEMS SELECTOR
          if (isMissing && selectedOrder != null && selectedOrder.items.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_shopping_cart_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Text('SELECT MISSING ITEMS (விடுபட்டவை):', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFB91C1C), letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...selectedOrder.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (!_messageCtrl.text.contains(item.product.name)) {
                              _messageCtrl.text = '${_messageCtrl.text} [Missing: ${item.product.name}]'.trim();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFEE2E2))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.quantity}x ${item.product.name}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF1F2937))),
                              Text('+ Tap to Add', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11.5, color: const Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. DYNAMIC DELAY / RIDER CONTACT
          if (isDelay && selectedOrder != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Text('RIDER DELIVERY DETAILS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFB45309), letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('டெலிவரி பார்ட்னரைத் தொடர்பு கொண்டு உடனடி நிலவரம் அறியலாம்.', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF92400E))),
                  const SizedBox(height: 12),
                  if (selectedOrder.deliveryPartner != null && selectedOrder.deliveryPartner!.phone.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('tel:${selectedOrder!.deliveryPartner!.phone}');
                          if (await canLaunchUrl(uri)) launchUrl(uri);
                        },
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                        label: Text('Call Rider (${selectedOrder.deliveryPartner!.name})', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4. DYNAMIC PAYMENT / REFUND CARD
          if (isPayment) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text('REFUND & PAYMENT SETTLEMENT', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF1D4ED8), letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('UPI / Bank மூலம் பணம் கழிக்கப்பட்டு ஆர்டர் தவறினால் 24 மணி நேரத்திற்குள் தானாக ரீஃபண்ட் செய்யப்படும்.', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF1E40AF))),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.receipt_rounded, size: 16, color: Color(0xFF2563EB)),
                    label: Text(_pickedImageFile != null ? 'Screenshot Attached ✅' : 'Upload Payment Screenshot / UTR', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF2563EB))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // General Photo Proof Box for other categories if no image yet
          if (!isDamaged && !isPayment && _pickedImageFile != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_pickedImageFile!, width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Photo Proof Attached', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF1E293B))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => setState(() => _pickedImageFile = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit / Connect Live Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitTicket,
              icon: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting ? 'CONNECTING WITH ADMIN...' : 'SEND TO ADMIN / START CHAT',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Tab 2: My Tickets ──
  Widget _buildMyTicketsTab() {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    if (_myTickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                child: const Icon(Icons.confirmation_num_outlined, color: Color(0xFF4F46E5), size: 40),
              ),
              const SizedBox(height: 16),
              Text('No Support Tickets Raised', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text('Your past issue reports and live resolutions will appear here.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('RAISE A TICKET', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, idx) {
          final t = _myTickets[idx];
          final ticketId = t['ticketId'] ?? 'TK-UNKNOWN';
          final subject = t['subject'] ?? t['issueType'] ?? 'Support Inquiry';
          final status = (t['status'] ?? 'Open').toString();
          final message = t['message'] ?? '';
          final replies = (t['replies'] as List?) ?? [];
          final orderDisplayId = t['orderDisplayId'] ?? '';
          final hasImage = (t['imageUrl'] != null && t['imageUrl'].toString().isNotEmpty);

          Color statusColor = const Color(0xFFD97706);
          Color statusBg = const Color(0xFFFFFBEB);
          if (status.toLowerCase() == 'resolved') {
            statusColor = const Color(0xFF16A34A);
            statusBg = const Color(0xFFF0FDF4);
          } else if (status.toLowerCase() == 'in progress') {
            statusColor = const Color(0xFF2563EB);
            statusBg = const Color(0xFFEFF6FF);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: InkWell(
              onTap: () => _showTicketChatSheet(t),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF4F46E5))),
                            if (orderDisplayId.toString().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: Text('Order #$orderDisplayId', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
                              ),
                            ],
                            if (hasImage) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.image_rounded, size: 11, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 3),
                                    Text('Photo', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(subject, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0F172A))),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${replies.length} Messages', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                          ],
                        ),
                        Row(
                          children: [
                            Text('View & Reply', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl) {
    final fullUrl = _getFullImageUrl(imageUrl);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: fullUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Text('Failed to load image proof'),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ticket Chat & Responses BottomSheet ──
  void _showTicketChatSheet(Map<String, dynamic> ticket) {
    final replyCtrl = TextEditingController();
    Map<String, dynamic> localTicket = Map<String, dynamic>.from(ticket);
    bool isUploadingChatImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final ticketId = localTicket['ticketId'] ?? 'TK-UNKNOWN';
            final subject = localTicket['subject'] ?? localTicket['issueType'] ?? 'Support Inquiry';
            final replies = (localTicket['replies'] as List?) ?? [];
            final initialMessage = localTicket['message'] ?? '';
            final initialImage = localTicket['imageUrl'];

            Future<void> sendReplyWithOptionalImage([String? uploadedImg]) async {
              final msg = replyCtrl.text.trim();
              if (msg.isEmpty && (uploadedImg == null || uploadedImg.isEmpty)) return;

              final auth = Provider.of<AuthProvider>(context, listen: false);
              final userName = auth.name.isNotEmpty ? auth.name : 'Customer';

              final ok = await _apiService.replyToTicket(
                localTicket['_id'],
                userName,
                msg.isNotEmpty ? msg : '📷 Photo Proof Attached',
                imageUrl: uploadedImg,
              );

              if (ok) {
                setSheetState(() {
                  final list = (localTicket['replies'] as List?) ?? [];
                  list.add({
                    'sender': userName,
                    'senderRole': 'Customer',
                    'message': msg.isNotEmpty ? msg : '📷 Photo Proof Attached',
                    if (uploadedImg != null && uploadedImg.isNotEmpty) 'imageUrl': uploadedImg,
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                  localTicket['replies'] = list;
                  replyCtrl.clear();
                });
                _loadMyTickets();
              }
            }

            Future<void> handleCameraOrGalleryPick(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: source, imageQuality: 75);
                if (picked == null) return;

                setSheetState(() => isUploadingChatImage = true);
                final uploadedUrl = await _apiService.uploadImage(picked.path);
                setSheetState(() => isUploadingChatImage = false);

                if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                  await sendReplyWithOptionalImage(uploadedUrl);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Image upload failed. Please try again.')),
                    );
                  }
                }
              } catch (e) {
                setSheetState(() => isUploadingChatImage = false);
                debugPrint('Chat image capture error: $e');
              }
            }

            void showPhotoAttachmentChooser() {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (chooserCtx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Send Damage Photo Proof', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4F46E5)),
                          ),
                          title: Text('Take Live Photo with Camera', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                          subtitle: Text('Capture damaged product now', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                          onTap: () {
                            Navigator.pop(chooserCtx);
                            handleCameraOrGalleryPick(ImageSource.camera);
                          },
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                            child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569)),
                          ),
                          title: Text('Choose from Photo Gallery', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14)),
                          subtitle: Text('Pick from saved pictures', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                          onTap: () {
                            Navigator.pop(chooserCtx);
                            handleCameraOrGalleryPick(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.80,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ticketId, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
                            Text(subject, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w800)),
                          ],
                        ),
                        IconButton(onPressed: () => Navigator.pop(bCtx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(height: 20),

                    // Message Timeline
                    Expanded(
                      child: ListView(
                        children: [
                          // Initial issue box
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YOUR INITIAL ISSUE REPORT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                if (initialMessage.isNotEmpty)
                                  Text(initialMessage, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF334155))),
                                if (initialImage != null && initialImage.toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _showImagePreviewDialog(context, initialImage.toString()),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: _getFullImageUrl(initialImage.toString()),
                                        height: 140,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(height: 140, color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          ...replies.map((r) {
                            final sender = r['sender'] ?? 'Support';
                            final isUser = r['senderRole'] == 'Customer' || sender.toString().toLowerCase().contains('customer');
                            final repMsg = r['message'] ?? '';
                            final repImg = r['imageUrl'];

                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isUser ? 'You' : 'Namba Support Executive',
                                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w800, color: isUser ? Colors.white70 : const Color(0xFF4338CA)),
                                    ),
                                    const SizedBox(height: 4),
                                    if (repMsg.isNotEmpty && repMsg != '📷 Photo Proof Attached')
                                      Text(repMsg, style: GoogleFonts.outfit(fontSize: 13, color: isUser ? Colors.white : const Color(0xFF0F172A))),
                                    if (repImg != null && repImg.toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () => _showImagePreviewDialog(context, repImg.toString()),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: _getFullImageUrl(repImg.toString()),
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(height: 160, color: Colors.black12, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    if (isUploadingChatImage) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))),
                            const SizedBox(width: 10),
                            Text('Uploading photo proof...', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Reply Input + Camera Button
                    Row(
                      children: [
                        // Camera Button to capture photo proof
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4F46E5), size: 22),
                            tooltip: 'Send Photo Proof',
                            onPressed: isUploadingChatImage ? null : showPhotoAttachmentChooser,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: replyCtrl,
                            style: GoogleFonts.outfit(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Type your reply or ask questions...',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5)),
                          onPressed: isUploadingChatImage ? null : () => sendReplyWithOptionalImage(),
                        ),
                      ],
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
}
