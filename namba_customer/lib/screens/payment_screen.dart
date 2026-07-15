import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/order_provider.dart';

class PaymentScreen extends StatefulWidget {
  final DeliveryOrder order;
  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _PayState { idle, processing, success, failure }

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  int _selectedMethod = 0;
  final _upiCtrl = TextEditingController();
  final _cardNumCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();
  final _cardExpCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();

  _PayState _state = _PayState.idle;
  String _failureReason = 'Payment declined. Please try again.';

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

  Future<void> _processPayment() async {
    setState(() => _state = _PayState.processing);
    await Future.delayed(const Duration(milliseconds: 2200));

    // 80% success, 20% failure simulation
    final success = Random().nextInt(10) < 8;

    if (success) {
      bool backendSuccess = false;
      if (mounted) {
        final method = _selectedMethod == 0 ? 'UPI' : (_selectedMethod == 1 ? 'CARD' : 'UPI');
        backendSuccess = await context.read<OrderProvider>().markPaymentDone(widget.order.id, method);
      }
      
      if (backendSuccess) {
        setState(() => _state = _PayState.success);
        _successAnim.forward();

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      } else {
        // Backend update failed
        _failureReason = 'Payment processed but server update failed. Please contact support.';
        setState(() => _state = _PayState.failure);
        if (mounted) {
          final method = _selectedMethod == 0 ? 'UPI' : (_selectedMethod == 1 ? 'CARD' : 'UPI');
          await context.read<OrderProvider>().markPaymentFailed(widget.order.id, method);
        }
        _failureAnim.forward(from: 0);
        return;
      }
    } else {
      final reasons = [
        'Payment declined by bank.',
        'Insufficient funds.',
        'Transaction timed out.',
        'UPI PIN mismatch.',
      ];
      setState(() {
        _state = _PayState.failure;
        _failureReason = reasons[Random().nextInt(reasons.length)];
      });
      if (mounted) {
        final method = _selectedMethod == 0 ? 'UPI' : (_selectedMethod == 1 ? 'CARD' : 'UPI');
        await context.read<OrderProvider>().markPaymentFailed(widget.order.id, method);
      }
      _failureAnim.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = (double v) => '₹${v.toStringAsFixed(0)}';

    if (_state == _PayState.success) return _buildSuccessScreen(fmt);
    if (_state == _PayState.failure) return _buildFailureScreen(fmt);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Secure Payment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              const Icon(Icons.lock_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 4),
              Text('SSL', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildOrderSummary(fmt),
            const SizedBox(height: 24),
            const Text('Choose Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildMethodTabs(),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedMethod == 0
                  ? _buildUpiSection()
                  : _selectedMethod == 1
                      ? _buildCardSection()
                      : _buildNetBankingSection(),
            ),
          ]),
        ),

        // Bottom Pay Button
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
            ),
            child: AnimatedBuilder(
              animation: _pulseScale,
              builder: (_, child) => Transform.scale(scale: _pulseScale.value, child: child),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _state == _PayState.processing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: _state == _PayState.processing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.lock_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('Pay ${fmt(widget.order.totalAmount + widget.order.deliveryFee)} Securely',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ]),
                ),
              ),
            ),
          ),
        ),

        // Full-screen processing overlay
        if (_state == _PayState.processing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(
                    width: 60, height: 60,
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  const Text('Processing Payment...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Please do not close this screen',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildOrderSummary(Function fmt) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.order.storeName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          Text('Order #${widget.order.id.substring(widget.order.id.length - 8)}',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          if (widget.order.textContent != null && widget.order.textContent!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.order.textContent!,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (widget.order.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', '),
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Total', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          Text(fmt(widget.order.totalAmount + widget.order.deliveryFee),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
        ]),
      ]),
    );
  }

  Widget _buildMethodTabs() {
    final methods = [
      {'label': 'UPI', 'icon': Icons.account_balance_wallet_rounded},
      {'label': 'Card', 'icon': Icons.credit_card_rounded},
      {'label': 'Net Banking', 'icon': Icons.account_balance_rounded},
    ];
    return Row(
      children: List.generate(methods.length, (i) {
        final sel = _selectedMethod == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMethod = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF4F46E5) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: sel
                    ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(methods[i]['icon'] as IconData,
                    color: sel ? Colors.white : Colors.grey.shade500, size: 22),
                const SizedBox(height: 4),
                Text(methods[i]['label'] as String,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        color: sel ? Colors.white : Colors.grey.shade600)),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUpiSection() {
    return Column(
      key: const ValueKey('upi'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pay with UPI App', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: _upiApps.map((app) => Expanded(
          child: GestureDetector(
            onTap: _processPayment,
            child: Container(
              margin: EdgeInsets.only(right: app == _upiApps.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: (app['color'] as Color).withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(app['icon'] as IconData, color: app['color'] as Color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(app['name'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        )).toList()),
        const SizedBox(height: 20),
        _dividerOr(),
        const SizedBox(height: 16),
        _buildTextField(controller: _upiCtrl, label: 'UPI ID', hint: 'yourname@upi', icon: Icons.alternate_email_rounded),
      ],
    );
  }

  Widget _buildCardSection() {
    return Column(
      key: const ValueKey('card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Card Preview
        Container(
          height: 180, width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('NAMBA PAY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
              Icon(Icons.contactless_rounded, color: Colors.white.withOpacity(0.7), size: 24),
            ]),
            const Spacer(),
            Text(
              _cardNumCtrl.text.isEmpty ? '•••• •••• •••• ••••' : _formatCard(_cardNumCtrl.text),
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 3),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CARD HOLDER', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, letterSpacing: 1)),
                Text(_cardNameCtrl.text.isEmpty ? 'YOUR NAME' : _cardNameCtrl.text.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('EXPIRES', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, letterSpacing: 1)),
                Text(_cardExpCtrl.text.isEmpty ? 'MM/YY' : _cardExpCtrl.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        _buildTextField(controller: _cardNumCtrl, label: 'Card Number', hint: '1234 5678 9012 3456',
          icon: Icons.credit_card_rounded, keyboardType: TextInputType.number, maxLength: 19,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _buildTextField(controller: _cardNameCtrl, label: 'Cardholder Name', hint: 'As on card',
          icon: Icons.person_rounded, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildTextField(controller: _cardExpCtrl, label: 'Expiry', hint: 'MM/YY',
            icon: Icons.calendar_today_rounded, keyboardType: TextInputType.number, maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
            onChanged: (_) => setState(() {}))),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(controller: _cardCvvCtrl, label: 'CVV', hint: '•••',
            icon: Icons.lock_rounded, keyboardType: TextInputType.number, maxLength: 3, obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 6),
          Text('256-bit SSL encrypted & secure', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ],
    );
  }

  Widget _buildNetBankingSection() {
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
        const Text('Select your Bank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.6,
          children: banks.map((bank) => GestureDetector(
            onTap: _processPayment,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
              child: Row(children: [
                const SizedBox(width: 12),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: (bank['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text((bank['name'] as String)[0],
                      style: TextStyle(color: bank['color'] as Color, fontWeight: FontWeight.w900, fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Text(bank['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          )).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('You will be redirected to your bank\'s secure page.',
                style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        ),
      ],
    );
  }

  Widget _dividerOr() {
    return Row(children: [
      Expanded(child: Divider(color: Colors.grey.shade200)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or enter UPI ID', style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Divider(color: Colors.grey.shade200)),
    ]);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label, required String hint, required IconData icon,
    TextInputType? keyboardType, bool obscureText = false,
    int? maxLength, List<TextInputFormatter>? inputFormatters, Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller, keyboardType: keyboardType,
      obscureText: obscureText, maxLength: maxLength,
      inputFormatters: inputFormatters, onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        filled: true, fillColor: Colors.white, counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
        labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Success Screen ─────────────────────────────────────────────────
  Widget _buildSuccessScreen(Function fmt) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981), width: 3),
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 64),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Payment Successful! 🎉',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(fmt(widget.order.totalAmount + widget.order.deliveryFee),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.store_rounded, color: Color(0xFF4F46E5), size: 18),
                  const SizedBox(width: 8),
                  Text(widget.order.storeName, style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  const Text('Order confirmed & paid', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                ]),
                if (widget.order.textContent != null && widget.order.textContent!.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.order.textContent!, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4))),
                  ]),
                ] else if (widget.order.items.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.order.items.map((i) => '${i.quantity}x ${i.product.name}').join(', '), style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4))),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))),
              const SizedBox(width: 10),
              Text('Returning to home...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Failure Screen ─────────────────────────────────────────────────
  Widget _buildFailureScreen(Function fmt) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0), child: child),
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEF4444), width: 3),
                ),
                child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 64),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Payment Failed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_failureReason,
                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ]),
            ),
            const SizedBox(height: 32),

            // Retry button
            SizedBox(
              width: double.infinity, height: 52,
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
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.refresh_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black54)),
              ),
            ),
          ]),
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
