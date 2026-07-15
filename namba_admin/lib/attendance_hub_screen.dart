import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AttendanceHubScreen extends StatefulWidget {
  final Map<String, String> headers;
  const AttendanceHubScreen({Key? key, required this.headers}) : super(key: key);

  @override
  State<AttendanceHubScreen> createState() => _AttendanceHubScreenState();
}

class _AttendanceHubScreenState extends State<AttendanceHubScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://100.53.131.76:5000/api/v1';

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/attendance/admin'), headers: widget.headers);
      final body = json.decode(res.body);
      if (body['success']) {
        setState(() {
          _logs = body['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      color: const Color(0xFFF9FAFB),
      child: Column(
        children: [
          _buildTabHeader('HR MANAGEMENT', "Today's Attendance Logs"),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: _buildTable(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(String subtitle, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: GoogleFonts.outfit(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.outfit(color: const Color(0xFF111827), fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade100)),
      child: DataTable(
        headingRowHeight: 60, dataRowHeight: 80,
        headingTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.grey.shade500, fontSize: 11, letterSpacing: 1),
        columns: const [
          DataColumn(label: Text('EMPLOYEE')),
          DataColumn(label: Text('ROLE')),
          DataColumn(label: Text('CHECK IN')),
          DataColumn(label: Text('CHECK OUT')),
          DataColumn(label: Text('STATUS')),
        ],
        rows: _logs.map((log) {
          final user = log['user'] ?? {};
          final checkIn = log['checkInTime'] != null ? log['checkInTime'].toString().split('T')[1].substring(0, 5) : '-';
          final checkOut = log['checkOutTime'] != null ? log['checkOutTime'].toString().split('T')[1].substring(0, 5) : '-';
          final status = log['status'] ?? 'Unknown';
          
          return DataRow(cells: [
            DataCell(Text(user['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w900))),
            DataCell(Text(user['role']?.toString().toUpperCase() ?? '', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
            DataCell(Text(checkIn)),
            DataCell(Text(checkOut)),
            DataCell(Text(status, style: TextStyle(color: status == 'Present' ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }
}
