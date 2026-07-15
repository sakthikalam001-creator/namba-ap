import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/voice_dispatch_service.dart';

class MissionBriefingScreen extends StatefulWidget {
  final String orderId;
  const MissionBriefingScreen({super.key, required this.orderId});

  @override
  State<MissionBriefingScreen> createState() => _MissionBriefingScreenState();
}

class _MissionBriefingScreenState extends State<MissionBriefingScreen> {
  bool _isAnalyzing = true;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    await Future.delayed(const Duration(milliseconds: 500));
    VoiceDispatchService.missionBriefing();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isAnalyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Text('ORDER BRIEFING', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: AppTheme.darkText)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Elegant Light Map Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.network(
                'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?q=80&w=2000&auto=format&fit=crop',
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SYSTEM INSIGHT', style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text('REF: OD-${widget.orderId.substring(widget.orderId.length - 4).toUpperCase()}', style: GoogleFonts.outfit(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  if (_isAnalyzing)
                    _buildAnalysisLoader()
                  else
                    _buildBriefingContent(),
                  
                  const Spacer(),
                  _buildActionFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisLoader() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80, height: 80,
                  child: CircularProgressIndicator(color: AppTheme.primaryOrange, strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange.withValues(alpha: 0.2))),
                ).animate(onPlay: (c) => c.repeat()).rotate(duration: 2.seconds),
                const Icon(icons.Iconsax.radar_2_copy, color: AppTheme.primaryOrange, size: 32),
              ],
            ),
            const SizedBox(height: 32),
            Text('OPTIMIZING ROUTE...', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text('Syncing real-time traffic data', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dispatch Briefing', style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text('SECTOR: COMMERCIAL HUB  •  OBJECTIVE: PRIORITY', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 32),
        
        _insightTile(icons.Iconsax.routing_copy, 'OPTIMAL PATH', 'Take the ring road to bypass heavy traffic in the market area.', AppTheme.accentGreen),
        const SizedBox(height: 16),
        _insightTile(icons.Iconsax.timer_1_copy, 'TIME ESTIMATE', 'Estimated time of arrival is 12-15 mins with current traffic.', AppTheme.primaryOrange),
        const SizedBox(height: 16),
        _insightTile(icons.Iconsax.danger_copy, 'PARKING ALERT', 'Restricted parking zone near drop-off. Use the back alley entrance.', Colors.redAccent),
        
        const SizedBox(height: 40),
        Text('ESTIMATED REVENUE', style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(
          children: [
            _rewardChip('₹45.00 BASE', AppTheme.accentGreen),
            const SizedBox(width: 12),
            _rewardChip('₹12.50 BONUS', AppTheme.primaryOrange),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _insightTile(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.outfit(color: AppTheme.darkText.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Text(label, style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildActionFooter() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        height: 60, width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.accentGreen,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: Text('START DELIVERY', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ),
      ),
    ).animate(target: _isAnalyzing ? 0 : 1).fadeIn().slideY(begin: 0.2, end: 0);
  }
}
