import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmployeeRosterScreen extends StatefulWidget {
  final Map<String, String> headers;
  const EmployeeRosterScreen({Key? key, required this.headers}) : super(key: key);

  @override
  State<EmployeeRosterScreen> createState() => _EmployeeRosterScreenState();
}

class _EmployeeRosterScreenState extends State<EmployeeRosterScreen> {
  List<dynamic> _employees = [];
  bool _isLoading = true;

  static String get _baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000/api/v1';

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/admin/employees'), headers: widget.headers);
      final body = json.decode(res.body);
      if (body['success']) {
        setState(() {
          _employees = body['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
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
          _buildTabHeader('HR MANAGEMENT', 'Employee Roster (Master Data)'),
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
          DataColumn(label: Text('NAME')),
          DataColumn(label: Text('ROLE')),
          DataColumn(label: Text('PHONE')),
          DataColumn(label: Text('JOIN DATE')),
          DataColumn(label: Text('BANK ADDED')),
        ],
        rows: _employees.map((e) {
          final profile = e['profile'];
          final isBankAdded = profile != null && profile['bankDetails'] != null && profile['bankDetails']['accountNumber'] != null;
          final joinDate = profile != null && profile['dateOfJoining'] != null ? profile['dateOfJoining'].toString().split('T')[0] : '-';
          return DataRow(cells: [
            DataCell(Text(e['name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w900))),
            DataCell(Text(e['role']?.toString().toUpperCase() ?? '', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
            DataCell(Text(e['phone'] ?? '-')),
            DataCell(Text(joinDate)),
            DataCell(
              isBankAdded 
              ? const Icon(Icons.check_circle, color: Colors.green) 
              : const Icon(Icons.cancel, color: Colors.red)
            ),
          ]);
        }).toList(),
      ),
    );
  }
}
