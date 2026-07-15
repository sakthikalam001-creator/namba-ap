import 'package:flutter/material.dart';

enum AppLanguage { english, tamil }

class LanguageProvider with ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;

  bool get isTamil => _currentLanguage == AppLanguage.tamil;

  void toggleLanguage() {
    _currentLanguage = _currentLanguage == AppLanguage.english
        ? AppLanguage.tamil
        : AppLanguage.english;
    notifyListeners();
  }

  String translate(String key) {
    if (_currentLanguage == AppLanguage.tamil) {
      return _tamilTranslations[key] ?? _englishTranslations[key] ?? key;
    }
    return _englishTranslations[key] ?? key;
  }

  static const Map<String, String> _englishTranslations = {
    'dashboard': 'Dashboard',
    'store_online': 'STORE ONLINE',
    'store_offline': 'STORE OFFLINE',
    'todays_sales': 'Today\'s Sales',
    'total_orders': 'Total Orders',
    'store_rating': 'Store Rating',
    'pending_orders': 'Pending Orders',
    'active_orders': 'Active Orders',
    'view_all': 'View All',
    'revenue_overview': 'Revenue Overview',
    'weekly_growth': 'Weekly Growth',
    'no_active_orders': 'No active orders right now.',
    'inventory': 'Inventory',
    'orders': 'Orders',
    'profile': 'Profile',
    'wallet': 'Wallet',
    'earnings': 'Earnings',
    'order_history': 'Order History',
    'settings': 'Settings',
    'logout': 'Logout',
    'search': 'Search...',
    'stock': 'Stock',
    'price': 'Price',
    'out_of_stock': 'Out of Stock',
    'in_stock': 'In Stock',
    'quick_actions': 'Quick Actions',
  };

  static const Map<String, String> _tamilTranslations = {
    'dashboard': 'முகப்பு',
    'store_online': 'கடை திறந்திருக்கிறது',
    'store_offline': 'கடை மூடப்பட்டுள்ளது',
    'todays_sales': 'இன்றைய விற்பனை',
    'total_orders': 'மொத்த ஆர்டர்கள்',
    'store_rating': 'கடை மதிப்பீடு',
    'pending_orders': 'கிடைக்கும் ஆர்டர்கள்',
    'active_orders': 'தற்போதைய ஆர்டர்கள்',
    'view_all': 'அனைத்தையும் காண்க',
    'revenue_overview': 'வருவாய் மேலோட்டம்',
    'weekly_growth': 'வாராந்திர வளர்ச்சி',
    'no_active_orders': 'தற்போது ஆர்டர்கள் இல்லை.',
    'inventory': 'சரக்கு பட்டியல்',
    'orders': 'ஆர்டர்கள்',
    'profile': 'சுயவிவரம்',
    'wallet': 'பணப்பை',
    'earnings': 'வருமானம்',
    'order_history': 'ஆர்டர் வரலாறு',
    'settings': 'அமைப்புகள்',
    'logout': 'வெளியேறு',
    'search': 'தேடுக...',
    'stock': 'இருப்பு',
    'price': 'விலை',
    'out_of_stock': 'இருப்பு இல்லை',
    'in_stock': 'இருப்பு உள்ளது',
    'analytics': 'பகுப்பாய்வு',
    'revenue': 'வருவாய்',
    'top_products': 'சிறந்த தயாரிப்புகள்',
    'weekly_report': 'வாராந்திர அறிக்கை',
    'monthly_report': 'மாதாந்திர அறிக்கை',
    'reviews': 'மதிப்புரைகள்',
    'average_rating': 'சராசரி மதிப்பீடு',
    'tracking': 'நேரடி கண்காணிப்பு',
    'promotions': 'சலுகைகள்',
    'coupons': 'கூப்பன்கள்',
    'create_coupon': 'கூப்பன் உருவாக்கு',
    'operating_hours': 'செயல்பாட்டு நேரம்',
    'open_time': 'திறக்கும் நேரம்',
    'close_time': 'மூடும் நேரம்',
    'save_settings': 'அமைப்புகளைச் சேமி',
    'active': 'செயலில் உள்ளது',
    'expired': 'காலாவதியானது',
  };
}

