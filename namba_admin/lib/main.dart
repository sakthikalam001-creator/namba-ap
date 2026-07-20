import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'login_screen.dart';
import 'super_admin_dashboard.dart';
import 'theme/admin_theme.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ BOOT: Env Loaded');
  } catch (e) {
    debugPrint('❌ BOOT: Env Load Failed: $e');
  }
  runApp(const NambaAdminApp());
}

class NambaAdminApp extends StatelessWidget {
  const NambaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namba Delivery Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdminColors.primaryIndigo,
          primary: AdminColors.primaryIndigo,
          surface: AdminColors.background,
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        scaffoldBackgroundColor: AdminColors.background,
        useMaterial3: true,
      ),
      home: const AdminRoot(),
    );
  }
}

class AdminRoot extends StatefulWidget {
  const AdminRoot({super.key});
  @override
  State<AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<AdminRoot> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('admin_user');
    if (userStr != null) {
      setState(() => _user = jsonDecode(userStr));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return AdminLoginScreen(onLogin: (u) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_user', jsonEncode(u));
        setState(() => _user = u);
      });
    }
    return SuperAdminDashboard(
        user: _user!,
        onLogout: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('admin_user');
          await prefs.setBool('admin_manual_logout', true);
          setState(() => _user = null);
        });
  }
}


