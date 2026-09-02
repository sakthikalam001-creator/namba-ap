import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, tamil, tanglish }

class DeliveryLanguageProvider with ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  DeliveryLanguageProvider() {
    _loadSavedLanguage();
  }

  AppLanguage get currentLanguage => _currentLanguage;

  bool get isTamil => _currentLanguage == AppLanguage.tamil;
  bool get isTanglish => _currentLanguage == AppLanguage.tanglish;

  String get languageName {
    switch (_currentLanguage) {
      case AppLanguage.tamil:
        return '🇮🇳 தமிழ் (Tamil)';
      case AppLanguage.tanglish:
        return '🇮🇳 Tanglish (தமிழ்)';
      case AppLanguage.english:
      default:
        return '🇬🇧 English';
    }
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = prefs.getString('driver_language');
    if (langStr == 'tamil') {
      _currentLanguage = AppLanguage.tamil;
    } else if (langStr == 'tanglish') {
      _currentLanguage = AppLanguage.tanglish;
    } else {
      _currentLanguage = AppLanguage.english;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _currentLanguage = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String langStr = 'english';
    if (lang == AppLanguage.tamil) {
      langStr = 'tamil';
    } else if (lang == AppLanguage.tanglish) {
      langStr = 'tanglish';
    }
    await prefs.setString('driver_language', langStr);
  }

  String translate(String key) {
    if (_currentLanguage == AppLanguage.tamil) {
      return _tamilTranslations[key] ?? _englishTranslations[key] ?? key;
    } else if (_currentLanguage == AppLanguage.tanglish) {
      return _tanglishTranslations[key] ?? _englishTranslations[key] ?? key;
    }
    return _englishTranslations[key] ?? key;
  }

  static const Map<String, String> _englishTranslations = {
    'duty_on': 'DUTY ON (ONLINE)',
    'duty_off': 'DUTY OFF (OFFLINE)',
    'dashboard': 'Dashboard',
    'orders': 'Orders',
    'todays_earnings': 'Today\'s Earnings',
    'completed_trips': 'Completed Trips',
    'live_orders': 'Live Orders',
    'accept_order': 'ACCEPT ORDER',
    'decline_order': 'DECLINE',
    'pickup_store': 'Pickup Store',
    'deliver_customer': 'Deliver to Customer',
    'navigate': 'Start Navigation',
    'order_delivered': 'ORDER DELIVERED',
    'wallet': 'My Wallet',
    'payouts': 'Payouts & Transfers',
    'profile': 'Rider Profile',
    'settings': 'Settings',
    'language': 'App Language',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'support': 'Rider Helpdesk',
    'logout': 'Logout',
    'emergency_sos': 'Emergency SOS',
    'documents': 'Documents',
    'verified': 'Verified',
    'pending_review': 'Pending Review',
    'action_needed': 'Action Needed',
  };

  static const Map<String, String> _tamilTranslations = {
    'duty_on': 'பணியில் உள்ளார் (ONLINE)',
    'duty_off': 'பணி நிறைவு (OFFLINE)',
    'dashboard': 'முகப்பு',
    'orders': 'ஆர்டர்கள்',
    'todays_earnings': 'இன்றைய வருமானம்',
    'completed_trips': 'முடிக்கப்பட்ட பயணங்கள்',
    'live_orders': 'நேரலை ஆர்டர்கள்',
    'accept_order': 'ஆர்டரை ஏற்றுக்கொள்',
    'decline_order': 'நிராகரி',
    'pickup_store': 'கடைக்குச் செல்லவும்',
    'deliver_customer': 'வாடிக்கையாளரிடம் வழங்கவும்',
    'navigate': 'வழிகாட்டுதலைத் தொடங்கு',
    'order_delivered': 'ஆர்டர் வழங்கப்பட்டது',
    'wallet': 'என் பணப்பை',
    'payouts': 'பணப்பரிமாற்றம் & வரவு',
    'profile': 'ரைடர் சுயவிவரம்',
    'settings': 'அமைப்புகள்',
    'language': 'மொழி (Language)',
    'dark_mode': 'இருண்ட திரை (Dark Mode)',
    'light_mode': 'வெள்ளை திரை (Light Mode)',
    'support': 'ரைடர் உதவி மையம்',
    'logout': 'வெளியேறு',
    'emergency_sos': 'அவசர உதவி (SOS)',
    'documents': 'ஆவணங்கள்',
    'verified': 'சரிபார்க்கப்பட்டது',
    'pending_review': 'அட்மின் மதிப்பாய்வில்',
    'action_needed': 'கவனம் தேவை',
  };

  static const Map<String, String> _tanglishTranslations = {
    'duty_on': 'DUTY ON (ONLINE)',
    'duty_off': 'DUTY OFF (OFFLINE)',
    'dashboard': 'Dashboard',
    'orders': 'Orders',
    'todays_earnings': 'Inaiku Sambathiyathathu',
    'completed_trips': 'Mudicha Trips',
    'live_orders': 'Live Orders',
    'accept_order': 'ORDER ACCEPT PANNU',
    'decline_order': 'REJECT PANNU',
    'pickup_store': 'Kadai Pickup',
    'deliver_customer': 'Customer Delivery',
    'navigate': 'Route Kaattu (Map)',
    'order_delivered': 'ORDER DELIVERED',
    'wallet': 'Enoda Wallet',
    'payouts': 'Bank Payouts',
    'profile': 'Rider Profile',
    'settings': 'Settings',
    'language': 'Mozhi (Language)',
    'dark_mode': 'Dark Mode (Iruttu)',
    'light_mode': 'Light Mode (Vellai)',
    'support': 'Rider Support Desk',
    'logout': 'Logout Pannu',
    'emergency_sos': 'Emergency SOS',
    'documents': 'Documents',
    'verified': 'Verify Aaiduchu',
    'pending_review': 'Admin Review-la Irukku',
    'action_needed': 'Re-upload Pannu',
  };
}
