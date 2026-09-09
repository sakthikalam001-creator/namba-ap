import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'order_details_screen.dart';

class PaymentScreen extends StatefulWidget {
  final DeliveryOrder? order;
  final CartCheckoutData? checkoutData;

  const PaymentScreen({
    super.key,
    this.order,
    this.checkoutData,
  }) : assert(order != null || checkoutData != null, 'Either order or checkoutData must be provided');

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _PayState { idle, processing, success, failure }

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  bool _codEnabled = true;
  int _selectedMethod = 0;
  final _upiCtrl = TextEditingController();
  final _cardNumCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();
  final _cardExpCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();

  _PayState _state = _PayState.idle;
  String _failureReason = 'Payment declined. Please try again.';
  DeliveryOrder? _finalOrder;

  late AnimationController _successAnim;
  late AnimationController _failureAnim;
  late AnimationController _pulseAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _pulseScale;

  final List<Map<String, dynamic>> _upiApps = [
    {'name': 'GPay', 'color': const Color(0xFF4285F4), 'icon': Icons.g_mobiledata_rounded},
    {'name': 'PhonePe', 'color': const Color(0xFF5F259F), 'icon': Icons.phone_android_rounded},
    {'name': 'Paytm', 'color': const Color(0xFF00BAF2), 'icon': Icons.account_balance_wallet_rounded},
    {'name': 'BHIM', 'color': const Color(0xFF1E3A5F), 'icon': Icons.currency_rupee_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPublicSettings();
    _successAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _failureAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scaleAnim = CurvedAnimation(parent: _successAnim, curve: Curves.elasticOut);
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _failureAnim, curve: Curves.easeInOut));
    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(_pulseAnim);
  }

  Future<void> _fetchPublicSettings() async {
    try {
      final res = await http.get(Uri.parse('${CustomerApiService.baseUrl}/admin/settings/public'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final settings = data['data'];
          if (mounted) {
            setState(() {
              _codEnabled = settings['codEnabled'] ?? true;
              if (!_codEnabled && _selectedMethod == 3) {
                _selectedMethod = 0;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching public settings in payment screen: $e');
    }
  }

  @override
  void dispose() {
    _successAnim.dispose();
    _failureAnim.dispose();
    _pulseAnim.dispose();
    _upiCtrl.dispose();
    _cardNumCtrl.dispose();
    _cardNameCtrl.dispose();
    _cardExpCtrl.dispose();
    _cardCvvCtrl.dispose();
    super.dispose();
  }

  double get _displayTotal {
    if (widget.checkoutData != null) return widget.checkoutData!.total;
    if (widget.order != null) {
      return widget.order!.totalAmount > 0
          ? widget.order!.totalAmount
          : (widget.order!.subTotal + widget.order!.platformFee + widget.order!.deliveryFee);
    }
    return 0.0;
  }

  String get _displayStoreName => widget.checkoutData?.storeName ?? widget.order?.storeName ?? 'Shop';

  String get _displayId {
    if (widget.checkoutData != null) return 'NEW';
    if (widget.order != null) {
      return widget.order!.displayId.isNotEmpty
          ? widget.order!.displayId
          : (widget.order!.id.length > 5 ? widget.order!.id.substring(widget.order!.id.length - 5).toUpperCase() : widget.order!.id);
    }
    return '';
  }

  Future<void> _processPayment() async {
    setState(() => _state = _PayState.processing);
    await Future.delayed(const Duration(milliseconds: 1600));

    final String method = _selectedMethod == 0
        ? 'UPI'
        : (_selectedMethod == 1
            ? 'CARD'
            : (_selectedMethod == 2 ? 'NETBANKING' : 'COD'));

    DeliveryOrder? finalizedOrder;

    if (widget.checkoutData != null) {
      // 🚀 NEW CHECKOUT FLOW: Place order NOW upon payment or COD confirmation
      try {
        final orderProvider = context.read<OrderProvider>();
        final bool isCod = method == 'COD';
        final bool isPaid = !isCod;

        final created = await orderProvider.placeOrder(
          storeId: widget.checkoutData!.storeId,
          storeName: widget.checkoutData!.storeName,
          storeCategory: widget.checkoutData!.storeCategory,
          items: widget.checkoutData!.items,
          total: widget.checkoutData!.total,
          address: widget.checkoutData!.address,
          lat: widget.checkoutData!.lat,
          lng: widget.checkoutData!.lng,
          paymentMethod: method,
          isPaymentDone: isPaid,
        );

        if (mounted) {
          // Clear cart only after order successfully placed!
          Provider.of<CartProvider>(context, listen: false).clear();
        }
        finalizedOrder = created;
      } catch (e) {
        debugPrint('Error placing order in payment screen: $e');
        _failureReason = e.toString().replaceAll('Exception: ', '');
        if (mounted) {
          setState(() => _state = _PayState.failure);
          _failureAnim.forward(from: 0);
        }
        return;
      }
    } else if (widget.order != null) {
      // EXISTING ORDER FLOW: Mark payment completed on existing order
      final backendSuccess = await context.read<OrderProvider>().markPaymentDone(widget.order!.id, method);
      if (backendSuccess) {
        finalizedOrder = widget.order;
      } else {
        _failureReason = 'Payment update failed on server. Please try again.';
        if (mounted) {
          setState(() => _state = _PayState.failure);
          _failureAnim.forward(from: 0);
        }
        return;
      }
    }

    if (finalizedOrder != null && mounted) {
      _finalOrder = finalizedOrder;
      setState(() => _state = _PayState.success);
      _successAnim.forward();

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: finalizedOrder!.id)),
          (route) => route.isFirst,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;
    final fmt = (double v) => '₹${v.toStringAsFixed(0)}';

    if (_state == _PayState.success) return _buildSuccessScreen(fmt, theme);
    if (_state == _PayState.failure) return _buildFailureScreen(fmt, theme);

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBg,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SECURE PAYMENT',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: theme.textPrimary),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 4),
                Text(
                  'SSL SECURED',
                  style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(fmt),
                const SizedBox(height: 24),
                Text(
                  'Choose Payment Method',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: theme.textPrimary),
                ),
                const SizedBox(height: 12),
                _buildMethodTabs(theme),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedMethod == 0
                      ? _buildUpiSection(theme)
                      : _selectedMethod == 1
                          ? _buildCardSection(theme)
                          : _selectedMethod == 2
                              ? _buildNetBankingSection(theme)
                              : _buildCodSection(theme),
                ),
              ],
            ),
          ),

          // Bottom Pay Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              decoration: BoxDecoration(
                color: theme.cardBg,
                border: Border(top: BorderSide(color: theme.borderCol, width: 1.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 20),
                child: AnimatedBuilder(
                  animation: _pulseScale,
                  builder: (_, child) => Transform.scale(scale: _pulseScale.value, child: child),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _state == _PayState.processing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedMethod == 3 ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 4,
                        shadowColor: (_selectedMethod == 3 ? const Color(0xFF10B981) : const Color(0xFF4F46E5)).withOpacity(0.4),
                      ),
                      child: _state == _PayState.processing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_selectedMethod == 3 ? Icons.check_circle_rounded : Icons.lock_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedMethod == 3
                                      ? 'CONFIRM & PLACE ORDER (COD)'
                                      : 'PAY ${fmt(_displayTotal)} SECURELY',
                                  style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Full-screen processing overlay
          if (_state == _PayState.processing)
            Container(
              color: Colors.black.withOpacity(0.65),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(40),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3.5),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Processing Payment...',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: theme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please do not close this screen',
                        style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Function fmt) {
    String itemsText = '';
    if (widget.checkoutData != null && widget.checkoutData!.items.isNotEmpty) {
      itemsText = widget.checkoutData!.items.map((i) => '${i.quantity}x ${i.product.name}').join(', ');
    } else if (widget.order != null) {
      if (widget.order!.textContent != null && widget.order!.textContent!.isNotEmpty) {
        itemsText = widget.order!.textContent!;
      } else if (widget.order!.items.isNotEmpty) {
        itemsText = widget.order!.items.map((i) => '${i.quantity}x ${i.product.name}').join(', ');
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayStoreName,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  'Order #$_displayId',
                  style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w700),
                ),
                if (itemsText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    itemsText,
                    style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700),
              ),
              Text(
                fmt(_displayTotal),
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabs(ThemeProvider theme) {
    final isDark = theme.isDarkMode;
    final methods = [
      {'label': 'UPI', 'icon': Icons.account_balance_wallet_rounded},
      {'label': 'Card', 'icon': Icons.credit_card_rounded},
      {'label': 'Net Banking', 'icon': Icons.account_balance_rounded},
      if (_codEnabled) {'label': 'COD', 'icon': Icons.money_rounded},
    ];

    return Row(
      children: List.generate(methods.length, (i) {
        final sel = _selectedMethod == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMethod = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < methods.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: sel
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel ? const Color(0xFF4F46E5) : theme.borderCol,
                  width: sel ? 1.5 : 1.0,
                ),
                boxShadow: sel
                    ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    methods[i]['icon'] as IconData,
                    color: sel ? Colors.white : theme.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    methods[i]['label'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : theme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUpiSection(ThemeProvider theme) {
    final isDark = theme.isDarkMode;

    return Column(
      key: const ValueKey('upi'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay with UPI App',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: theme.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: _upiApps.map((app) => Expanded(
            child: GestureDetector(
              onTap: _processPayment,
              child: Container(
                margin: EdgeInsets.only(right: app == _upiApps.last ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.borderCol),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (app['color'] as Color).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(app['icon'] as IconData, color: app['color'] as Color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      app['name'] as String,
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: theme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),
        _dividerOr(theme),
        const SizedBox(height: 16),
        _buildTextField(
          theme: theme,
          controller: _upiCtrl,
          label: 'UPI ID',
          hint: 'yourname@okhdfcbank',
          icon: Icons.alternate_email_rounded,
        ),
      ],
    );
  }

  Widget _buildCardSection(ThemeProvider theme) {
    return Column(
      key: const ValueKey('card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Card Preview
        Container(
          height: 185,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NAMBA PAY',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                  Icon(Icons.contactless_rounded, color: Colors.white.withOpacity(0.7), size: 24),
                ],
              ),
              const Spacer(),
              Text(
                _cardNumCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _formatCard(_cardNumCtrl.text),
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CARD HOLDER', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 8, letterSpacing: 1)),
                      Text(
                        _cardNameCtrl.text.isEmpty ? 'YOUR NAME' : _cardNameCtrl.text.toUpperCase(),
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXPIRES', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 8, letterSpacing: 1)),
                      Text(
                        _cardExpCtrl.text.isEmpty ? 'MM/YY' : _cardExpCtrl.text,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          theme: theme,
          controller: _cardNumCtrl,
          label: 'Card Number',
          hint: '1234 5678 9012 3456',
          icon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
          maxLength: 19,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          theme: theme,
          controller: _cardNameCtrl,
          label: 'Cardholder Name',
          hint: 'As on card',
          icon: Icons.person_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                theme: theme,
                controller: _cardExpCtrl,
                label: 'Expiry',
                hint: 'MM/YY',
                icon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
                maxLength: 5,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                theme: theme,
                controller: _cardCvvCtrl,
                label: 'CVV',
                hint: '•••',
                icon: Icons.lock_rounded,
                keyboardType: TextInputType.number,
                maxLength: 3,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
            const SizedBox(width: 6),
            Text(
              '256-bit SSL encrypted & bank-grade secure',
              style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNetBankingSection(ThemeProvider theme) {
    final isDark = theme.isDarkMode;
    final banks = [
      {'name': 'SBI', 'color': const Color(0xFF1E3A5F)},
      {'name': 'HDFC', 'color': const Color(0xFF003087)},
      {'name': 'ICICI', 'color': const Color(0xFFFF6600)},
      {'name': 'Axis Bank', 'color': const Color(0xFF800000)},
      {'name': 'Kotak', 'color': const Color(0xFFEC4842)},
      {'name': 'Yes Bank', 'color': const Color(0xFF007DC6)},
    ];

    return Column(
      key: const ValueKey('netbanking'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your Bank',
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: theme.textPrimary),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: banks.map((bank) => GestureDetector(
            onTap: _processPayment,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.borderCol),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (bank['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        (bank['name'] as String)[0],
                        style: GoogleFonts.outfit(color: bank['color'] as Color, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    bank['name'] as String,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: theme.textPrimary),
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.blue.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You will be redirected to your bank\'s secure payment gateway.',
                  style: GoogleFonts.outfit(color: isDark ? const Color(0xFF93C5FD) : Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodSection(ThemeProvider theme) {
    final isDark = theme.isDarkMode;

    return Container(
      key: const ValueKey('cod'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.borderCol),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E81) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.money_rounded, color: Color(0xFFD97706), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash on Delivery (COD)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: theme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pay in cash to delivery partner on arrival',
                      style: GoogleFonts.outfit(fontSize: 12, color: theme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.borderCol),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF4F46E5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please keep exact cash ready during delivery to ensure a smooth handover.',
                    style: GoogleFonts.outfit(fontSize: 12, color: theme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerOr(ThemeProvider theme) {
    return Row(
      children: [
        Expanded(child: Divider(color: theme.borderCol)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or enter UPI ID',
            style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Divider(color: theme.borderCol)),
      ],
    );
  }

  Widget _buildTextField({
    required ThemeProvider theme,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
  }) {
    final isDark = theme.isDarkMode;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.borderCol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.borderCol),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
        labelStyle: GoogleFonts.outfit(color: theme.textSecondary, fontWeight: FontWeight.w600),
        hintStyle: GoogleFonts.outfit(color: theme.textSecondary.withOpacity(0.6)),
      ),
    );
  }

  // ── Success Screen ─────────────────────────────────────────────────
  Widget _buildSuccessScreen(Function fmt, ThemeProvider theme) {
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981), width: 3),
                  ),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 64),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Order Placed Successfully! 🎉',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: theme.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  fmt(_displayTotal),
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.borderCol),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 12)],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _displayStoreName,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: theme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _selectedMethod == 3 ? 'Order confirmed (Cash on Delivery)' : 'Order confirmed & paid online',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF10B981), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))),
                  const SizedBox(width: 12),
                  Text(
                    'Opening order details...',
                    style: GoogleFonts.outfit(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Failure Screen ─────────────────────────────────────────────────
  Widget _buildFailureScreen(Function fmt, ThemeProvider theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFEF4444), width: 3),
                  ),
                  child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 60),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Payment Failed!',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: theme.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _failureReason,
                        style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Retry button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _state = _PayState.idle;
                    _failureAnim.reset();
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('Try Again', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.borderCol),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: theme.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCard(String value) {
    final cleaned = value.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(cleaned[i]);
    }
    return buf.toString();
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final text = n.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(text[i]);
    }
    final s = buf.toString();
    return n.copyWith(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    final text = n.text.replaceAll('/', '');
    if (text.length >= 3) {
      final f = '${text.substring(0, 2)}/${text.substring(2)}';
      return n.copyWith(text: f, selection: TextSelection.collapsed(offset: f.length));
    }
    return n;
  }
}
