import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import '../../models/vendor_profile_model.dart';
import '../../services/vendor_order_provider.dart';
import 'vendor_login_screen.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String storeName;
  final String vendorId;
  final String? phone;

  const WaitingApprovalScreen({
    super.key,
    required this.storeName,
    required this.vendorId,
    this.phone,
  });

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isCheckingStatus = false;
  bool _isApproved = false;
  Map<String, dynamic>? _approvedVendorData;

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://54.204.9.126:5000/api/v1';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _checkLiveStatus(silent: true);
  }

  Future<void> _checkLiveStatus({bool silent = false}) async {
    if (widget.phone == null || widget.phone!.isEmpty) return;
    if (!silent) setState(() => _isCheckingStatus = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/vendors/status-by-phone/${widget.phone}'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final v = data['data'];
          final status = (v['approvalStatus'] ?? v['status'] ?? '').toString().toLowerCase();
          if (status == 'approved' || status == 'active') {
            if (mounted) {
              setState(() {
                _isApproved = true;
                _approvedVendorData = v;
              });
            }
          }
        }
      }
    } catch (_) {}

    if (mounted && !silent) {
      setState(() => _isCheckingStatus = false);
      if (!_isApproved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status checked: Still under review by Super Admin.')),
        );
      }
    }
  }

  Future<void> _enterDashboard() async {
    if (_approvedVendorData == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isVendorLoggedIn', true);
      if (widget.phone != null) await prefs.setString('vendorPhone', widget.phone!);
      await prefs.setString('vendorProfileJson', jsonEncode(_approvedVendorData));

      final orderProvider = Provider.of<VendorOrderProvider>(context, listen: false);
      orderProvider.setProfile(VendorProfileModel.fromJson(_approvedVendorData!));
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFEEF2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // TOP HERO SECTION
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              // Glowing Animated Hero Ring
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (_, child) {
                                  return Container(
                                    padding: EdgeInsets.all(12 + (_pulseController.value * 4)),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_isApproved ? const Color(0xFF10B981) : const Color(0xFF4F46E5))
                                          .withOpacity(0.08 + (_pulseController.value * 0.05)),
                                    ),
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: _isApproved
                                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                                          : [const Color(0xFF4338CA), const Color(0xFF6366F1)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isApproved ? const Color(0xFF10B981) : const Color(0xFF4F46E5))
                                            .withOpacity(0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ).animate().scale(delay: 150.ms, duration: 500.ms, curve: Curves.elasticOut),

                              const SizedBox(height: 20),

                              Text(
                                _isApproved ? 'Store Approved!' : 'Application Under Review',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: _isApproved ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2, end: 0),

                              const SizedBox(height: 10),

                              // Store Badge Card
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (_isApproved ? const Color(0xFF059669) : const Color(0xFF4F46E5)).withOpacity(0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isApproved ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.storeName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (widget.phone != null && widget.phone!.isNotEmpty) ...[
                                      Text(' • ', style: TextStyle(color: Colors.grey.shade400)),
                                      Text(
                                        '+91 ${widget.phone}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ).animate().fadeIn(delay: 350.ms),

                              const SizedBox(height: 12),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _isApproved
                                      ? 'வாழ்த்துகள்! உங்கள் கடை அங்கீகரிக்கப்பட்டுவிட்டது. இப்போதே டாஷ்போர்டிற்குள் சென்று ஆர்டர்களை ஏற்கத் தொடங்கலாம்!'
                                      : 'நம்ம Super Admin உங்கள் கடையின் ஆவணங்களைச் சரிபார்த்து வருகிறார். சரிபார்ப்பு முடிந்ததும் உடனடியாக நேரலை செய்யப்படும்!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    color: const Color(0xFF64748B),
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ).animate().fadeIn(delay: 450.ms),
                            ],
                          ),

                          // CONNECTED VERTICAL TIMELINE CARD
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withOpacity(0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildTimelineStep(
                                  stepNumber: '1',
                                  title: 'Application Submitted',
                                  subtitle: 'Store profile and documents received',
                                  isCompleted: true,
                                  isActive: false,
                                  isLast: false,
                                ),
                                _buildTimelineStep(
                                  stepNumber: '2',
                                  title: 'Super Admin Verification',
                                  subtitle: _isApproved
                                      ? 'Business details verified & approved'
                                      : 'Document and location review in progress',
                                  isCompleted: _isApproved,
                                  isActive: !_isApproved,
                                  isLast: false,
                                ),
                                _buildTimelineStep(
                                  stepNumber: '3',
                                  title: 'Store Live & Dispatch Ready',
                                  subtitle: _isApproved
                                      ? 'Ready to accept customer orders!'
                                      : 'Final activation upon approval',
                                  isCompleted: _isApproved,
                                  isActive: false,
                                  isLast: true,
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),

                          // BOTTOM ACTIONS
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              children: [
                                if (_isApproved)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed: _enterDashboard,
                                      icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                                      label: Text(
                                        'Enter Vendor Dashboard 🚀',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14.5),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: const Color(0xFF059669).withOpacity(0.4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                                  )
                                else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _isCheckingStatus ? null : () => _checkLiveStatus(silent: false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shadowColor: const Color(0xFF4F46E5).withOpacity(0.3),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _isCheckingStatus
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.refresh_rounded, size: 18),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Check Live Status / நிலையைச் சரிபார்க்க',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(builder: (_) => const VendorLoginScreen()),
                                        (route) => false,
                                      );
                                    },
                                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF64748B)),
                                    label: Text(
                                      'Back to Vendor Login',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ).animate().fadeIn(delay: 650.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isActive = false,
    required bool isLast,
  }) {
    Color indicatorBg;
    Color indicatorIconColor;
    Widget indicatorChild;

    if (isCompleted) {
      indicatorBg = const Color(0xFF059669);
      indicatorIconColor = Colors.white;
      indicatorChild = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
    } else if (isActive) {
      indicatorBg = const Color(0xFF4F46E5);
      indicatorIconColor = Colors.white;
      indicatorChild = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else {
      indicatorBg = const Color(0xFFF1F5F9);
      indicatorIconColor = const Color(0xFF94A3B8);
      indicatorChild = Text(
        stepNumber,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF94A3B8)),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Icon + Vertical line
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorBg,
                  border: Border.all(
                    color: isActive ? const Color(0xFFC7D2FE) : Colors.transparent,
                    width: isActive ? 3 : 0,
                  ),
                ),
                child: Center(child: indicatorChild),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted ? const Color(0xFF059669).withOpacity(0.4) : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Step Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'IN PROGRESS',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      if (isCompleted)
                        const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

