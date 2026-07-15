import 'package:flutter/material.dart';
import '../main.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    // TTS initialization removed
  }

  void showAlert({required String title, required String message}) {
    final context = NambaVendorApp.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> playNewOrderAlert(String orderId) async {
    print("MOCK ALERT: New order $orderId received!");
  }

  Future<void> speak(String text) async {
    print("MOCK SPEAK: $text");
  }
}

