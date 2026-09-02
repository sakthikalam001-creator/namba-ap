import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, tamil, tanglish }

class CustomerLanguageProvider with ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  CustomerLanguageProvider() {
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
    final langStr = prefs.getString('customer_language');
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
    await prefs.setString('customer_language', langStr);
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
    'home': 'Home',
    'search': 'Search foods, groceries...',
    'cart': 'Cart',
    'orders': 'My Orders',
    'profile': 'Profile',
    'categories': 'Categories',
    'top_stores': 'Top Stores & Restaurants',
    'add_to_cart': 'ADD',
    'checkout': 'Proceed to Pay',
    'delivery_address': 'Deliver to',
    'order_placed': 'Order Placed Successfully!',
    'track_order': 'Track Live Order',
    'language': 'Language',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'support': 'Customer Helpdesk',
    'logout': 'Logout',
  };

  static const Map<String, String> _tamilTranslations = {
    'home': 'முகப்பு',
    'search': 'உணவு, மளிகை மற்றும் பலவற்றைத் தேடுக...',
    'cart': 'கூடை',
    'orders': 'என் ஆர்டர்கள்',
    'profile': 'சுயவிவரம்',
    'categories': 'வகைகள்',
    'top_stores': 'பிரபலமான கடைகள்',
    'add_to_cart': 'சேர்',
    'checkout': 'பணம் செலுத்து',
    'delivery_address': 'டெலிவரி முகவரி',
    'order_placed': 'ஆர்டர் வெற்றிகரமாக பதிவு செய்யப்பட்டது!',
    'track_order': 'நேரலை கண்காணிப்பு',
    'language': 'மொழி (Language)',
    'dark_mode': 'இருண்ட திரை (Dark Mode)',
    'light_mode': 'வெள்ளை திரை (Light Mode)',
    'support': 'வாடிக்கையாளர் உதவி மையம்',
    'logout': 'வெளியேறு',
  };

  static const Map<String, String> _tanglishTranslations = {
    'home': 'Home',
    'search': 'Food, grocery search pannunga...',
    'cart': 'Cart',
    'orders': 'Enoda Orders',
    'profile': 'Profile',
    'categories': 'Categories',
    'top_stores': 'Top Kadaigal',
    'add_to_cart': 'ADD PANNU',
    'checkout': 'Kaasu Kudu (Pay)',
    'delivery_address': 'Delivery Address',
    'order_placed': 'Order Confirm Aaiduchu! 🎉',
    'track_order': 'Live Track Pannunga',
    'language': 'Mozhi (Language)',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'support': 'Help & Support',
    'logout': 'Logout Pannu',
  };
}
