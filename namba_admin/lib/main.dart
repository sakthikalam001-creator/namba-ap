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
import 'dart:ui';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

void safeShowSnackBar(SnackBar snackBar) {
  final content = snackBar.content.toString();
  if (content.contains('AssetManifest') || content.contains('google_fonts')) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    globalMessengerKey.currentState?.hideCurrentSnackBar();
    globalMessengerKey.currentState?.showSnackBar(snackBar);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow google_fonts runtime fetching
  GoogleFonts.config.allowRuntimeFetching = true;

  // ── Load .env with graceful fallback ──
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ BOOT: Env Loaded');
  } catch (e) {
    debugPrint('ℹ️ BOOT: Env not bundled as asset ($e) — using built-in endpoints');
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('⚠️ UI RENDER ERROR: ${details.exception}');
    debugPrint('⚠️ STACK TRACE: ${details.stack}');
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text('UI Render Exception', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(details.exceptionAsString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const NambaAdminApp());
}

class NambaAdminApp extends StatelessWidget {
  const NambaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: globalMessengerKey,
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


