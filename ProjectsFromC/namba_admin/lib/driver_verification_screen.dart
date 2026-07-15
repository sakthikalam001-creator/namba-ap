import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/verification_service.dart';
import 'theme/admin_theme.dart';

class DriverVerificationScreen extends StatefulWidget {
  const DriverVerificationScreen({super.key});

  @override
  State<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen> {
  List<dynamic> _pendingDrivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final res = await VerificationService.getPendingVerifications();
      setState(() {
        if (res['success'] == true && res['data'] != null) {
          _pendingDrivers = res['data'];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Text('DOCUMENT VERIFICATION HUB', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: AdminColors.textHeading),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryIndigo))
        : _pendingDrivers.isEmpty
          ? Center(child: Text('NO PENDING VERIFICATIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AdminColors.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _pendingDrivers.length,
              itemBuilder: (context, index) {
                final driver = _pendingDrivers[index];
                return _buildDriverCard(driver);
              },
            ),
    );
  }

  Widget _buildDriverCard(dynamic driver) {
    final rawDocs = driver['documents'];
    final docs = (rawDocs is Map<String, dynamic>) ? rawDocs : <String, dynamic>{};
    final pendingDocs = docs.entries
        .where((e) => e.value is Map && e.value['status'] == 'pending')
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: AdminColors.border)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text((driver['name'] ?? 'Unknown').toString().toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.textHeading)),
            subtitle: Text(driver['phone']?.toString() ?? 'N/A', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AdminColors.primaryIndigo)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AdminColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AdminColors.warning.withOpacity(0.3))),
              child: Text('PENDING: ${pendingDocs.length}', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AdminColors.warning)),
            ),
          ),
          Divider(color: AdminColors.border, height: 1),
          ...pendingDocs.map((doc) => _buildDocVerificationItem(driver['_id']?.toString() ?? '', doc.key, doc.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildDocVerificationItem(String driverId, String type, dynamic data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: AdminColors.primaryIndigo)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildImagePreview('FRONT', data['front']),
              if (type != 'selfie') ...[
                const SizedBox(width: 12),
                _buildImagePreview('BACK', data['back']),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleAction(driverId, type, 'verified'),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text('APPROVE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(backgroundColor: AdminColors.success, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(driverId, type),
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: Text('REJECT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  style: OutlinedButton.styleFrom(foregroundColor: AdminColors.danger, side: BorderSide(color: AdminColors.danger), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildImagePreview(String label, String? url) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AdminColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showFullImage(url),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AdminColors.background,
                border: Border.all(color: AdminColors.border),
                image: url != null ? DecorationImage(image: NetworkImage('http://100.53.131.76:5000$url'), fit: BoxFit.cover) : null,
              ),
              child: url == null ? Center(child: Icon(Icons.image_not_supported_outlined, color: AdminColors.textMuted)) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String? url) {
    if (url == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network('http://100.53.131.76:5000$url'),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String driverId, String type, String status, {String? reason}) async {
    final res = await VerificationService.verifyDocument(driverId: driverId, docType: type, status: status, reason: reason);
    if (res['success'] == true) {
      _loadPending();
    }
  }

  void _showRejectDialog(String driverId, String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('REJECTION REASON', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: AdminColors.textHeading)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g. Image blurry...',
            filled: true,
            fillColor: AdminColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AdminColors.textSub))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAction(driverId, type, 'rejected', reason: controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: Text('REJECT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          )
        ],
      ),
    );
  }
}
