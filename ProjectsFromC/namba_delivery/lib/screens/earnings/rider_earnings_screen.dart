import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('EARNINGS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            _buildPrimeWalletCard(),
            const SizedBox(height: 32),
            _buildEarningBreakdown(),
            const SizedBox(height: 32),
            _buildPrimeRevenueTrend(),
            const SizedBox(height: 32),
            _buildPeakPerformanceModule(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RECENT TRANSACTIONS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.darkText.withValues(alpha: 0.3), letterSpacing: 1)),
                Text('EXPORT PDF', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange, letterSpacing: 1)),
              ],
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
            _buildPrimeTransactionList(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimeWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.darkText, // Dark contrast card
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: AppTheme.darkText.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15))],
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1639322537228-f710d846310a?q=80&w=2000&auto=format&fit=crop'), // Crypto patterns
          fit: BoxFit.cover, opacity: 0.05,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AVAILABLE BALANCE', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('₹', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text('4,280', style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      Text('.50', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 20, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                child: const Icon(icons.Iconsax.wallet_3_copy, color: AppTheme.primaryOrange, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildWalletAction('Withdraw', AppTheme.primaryOrange, icons.Iconsax.arrow_right_3_copy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWalletAction('Transactions', Colors.white.withValues(alpha: 0.1), icons.Iconsax.document_text_copy, isSecondary: true),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildWalletAction(String label, Color color, IconData icon, {bool isSecondary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSecondary ? null : [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Center(
        child: Text(label.toUpperCase(), style: GoogleFonts.outfit(color: isSecondary ? Colors.white70 : Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildEarningBreakdown() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(icons.Iconsax.lamp_charge_copy, color: AppTheme.primaryOrange, size: 18),
              const SizedBox(width: 10),
              Text('EARNING BREAKDOWN', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _breakdownItem('Base Pay', '₹2,840', AppTheme.darkText),
              _breakdownItem('Surge', '₹850', AppTheme.accentGreen),
              _breakdownItem('Tips', '₹590', Colors.blueAccent),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _breakdownItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(val, style: GoogleFonts.outfit(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildPrimeRevenueTrend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WEEKLY PERFORMANCE', style: GoogleFonts.outfit(color: AppTheme.darkText.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Container(
          height: 180,
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppTheme.softShadow),
          child: CustomPaint(painter: PrimeRevenuePainter()),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildPeakPerformanceModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PEAK OPERATIONAL WINDOWS', style: GoogleFonts.outfit(color: AppTheme.darkText.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppTheme.softShadow),
          child: Column(
            children: [
              _peakWindowRow('Lunch Rush', '12 PM - 3 PM', 0.9, AppTheme.primaryOrange),
              const SizedBox(height: 18),
              _peakWindowRow('Dinner Peak', '7 PM - 11 PM', 1.0, AppTheme.accentGreen),
              const SizedBox(height: 18),
              _peakWindowRow('Breakfast', '7 AM - 10 AM', 0.5, Colors.blueAccent),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _peakWindowRow(String label, String time, double intensity, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w900)),
              Text(time, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            height: 6,
            decoration: BoxDecoration(color: AppTheme.lightBg, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: intensity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.5)]),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimeTransactionList() {
    return Column(
      children: [
        _primeTransactionItem('Order Ref #921', 'Delivery Commission', '+₹45.00', true),
        _primeTransactionItem('Order Ref #918', 'Delivery Commission', '+₹52.50', true),
        _primeTransactionItem('Bank Transfer', 'Withdrawal Request', '-₹2,500.00', false),
        _primeTransactionItem('Order Ref #905', 'Delivery Commission', '+₹38.00', true),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _primeTransactionItem(String ref, String label, String amount, bool isCredit) {
    Color color = isCredit ? AppTheme.accentGreen : AppTheme.darkText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(isCredit ? icons.Iconsax.receive_square_copy : icons.Iconsax.send_square_copy, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(ref, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(amount, style: GoogleFonts.outfit(color: color, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ],
      ),
    );
  }
}

class PrimeRevenuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawCurve(canvas, size, [0.4, 0.6, 0.3, 0.8, 0.5, 0.9, 0.7], AppTheme.accentGreen);
    _drawCurve(canvas, size, [0.3, 0.4, 0.2, 0.5, 0.4, 0.6, 0.5], AppTheme.primaryOrange.withValues(alpha: 0.2));
  }

  void _drawCurve(Canvas canvas, Size size, List<double> points, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.1), Colors.transparent],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final step = size.width / (points.length - 1);
    
    path.moveTo(0, size.height * (1 - points[0]));
    
    for (int i = 0; i < points.length - 1; i++) {
        final x1 = step * i;
        final y1 = size.height * (1 - points[i]);
        final x2 = step * (i + 1);
        final y2 = size.height * (1 - points[i+1]);
        final cx = (x1 + x2) / 2;
        path.quadraticBezierTo(x1, y1, cx, (y1 + y2) / 2);
    }
    path.lineTo(size.width, size.height * (1 - points.last));

    canvas.drawPath(path, paint);
    
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
