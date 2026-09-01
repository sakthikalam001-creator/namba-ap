import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, tamil, tanglish }

class LanguageProvider with ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  AppLanguage get currentLanguage => _currentLanguage;

  bool get isTamil => _currentLanguage == AppLanguage.tamil;
  bool get isTanglish => _currentLanguage == AppLanguage.tanglish;

  String get languageName {
    switch (_currentLanguage) {
      case AppLanguage.tamil:
        return 'தமிழ் (Tamil)';
      case AppLanguage.tanglish:
        return 'Tanglish (தமிழ்ங்கிலீஷ்)';
      case AppLanguage.english:
      default:
        return 'English';
    }
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = prefs.getString('app_language');
    if (langStr == 'tamil') {
      _currentLanguage = AppLanguage.tamil;
      notifyListeners();
    } else if (langStr == 'tanglish') {
      _currentLanguage = AppLanguage.tanglish;
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _currentLanguage = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String langStr = 'english';
    if (lang == AppLanguage.tamil) langStr = 'tamil';
    if (lang == AppLanguage.tanglish) langStr = 'tanglish';
    await prefs.setString('app_language', langStr);
  }

  void toggleLanguage() {
    if (_currentLanguage == AppLanguage.english) {
      setLanguage(AppLanguage.tamil);
    } else if (_currentLanguage == AppLanguage.tamil) {
      setLanguage(AppLanguage.tanglish);
    } else {
      setLanguage(AppLanguage.english);
    }
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
    'analytics': 'Analytics',
    'revenue': 'Revenue',
    'top_products': 'Top Products',
    'fast_moving': 'Fast Moving Items',
    'slow_moving': 'Slow Moving Items',
    'peak_hours': 'Peak Hours',
    'avg_order_value': 'Avg Order Value',
    'weekly_report': 'Weekly Report',
    'monthly_report': 'Monthly Report',
    'reviews': 'Customer Reviews',
    'average_rating': 'Average Rating',
    'tracking': 'Live Tracking',
    'promotions': 'Promotions',
    'coupons': 'Coupons & Offers',
    'create_coupon': 'Create Coupon',
    'operating_hours': 'Operating Hours',
    'open_time': 'Opening Time',
    'close_time': 'Closing Time',
    'save_settings': 'Save Settings',
    'active': 'Active',
    'expired': 'Expired',
    'welcome_back': 'Welcome back,',
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
    'fast_moving': 'வேகமாக விற்கும் பொருட்கள்',
    'slow_moving': 'மெதுவாக விற்கும் பொருட்கள்',
    'peak_hours': 'அதிக ஆர்டர்கள் வரும் நேரம்',
    'avg_order_value': 'சராசரி ஆர்டர் மதிப்பு',
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
    'welcome_back': 'வணக்கம்,',
  };

  static const Map<String, String> _tanglishTranslations = {
    'dashboard': 'Dashboard (முகப்பு)',
    'store_online': 'KADAI ONLINE',
    'store_offline': 'KADAI OFFLINE',
    'todays_sales': 'Inraiya Sales',
    'total_orders': 'Motha Orders',
    'store_rating': 'Kadai Rating',
    'pending_orders': 'Puthu Orders',
    'active_orders': 'Nadakkura Orders',
    'view_all': 'Full-aa Paarkka',
    'revenue_overview': 'Varumaanam Summary',
    'weekly_growth': 'Vaara Valarchi',
    'no_active_orders': 'Ippo orders ethuvum illa.',
    'inventory': 'Products & Stock',
    'orders': 'Orders',
    'profile': 'Store Profile',
    'wallet': 'Wallet / Panappai',
    'earnings': 'Varumaanam / Payouts',
    'order_history': 'Pazhaiya Orders',
    'settings': 'Settings',
    'logout': 'Logout Panna',
    'search': 'Theduga / Search...',
    'stock': 'Stock',
    'price': 'Vilai (Price)',
    'out_of_stock': 'Stock Illa (Out of Stock)',
    'in_stock': 'Stock Irukku',
    'analytics': 'Sales Report',
    'revenue': 'Total Sales',
    'top_products': 'Athigam Vitha Items',
    'fast_moving': 'Fast-aa Sell Aagura Items',
    'slow_moving': 'Slow Items',
    'peak_hours': 'Busy Timing',
    'avg_order_value': 'Avg Order Vilai',
    'weekly_report': 'Vaara Report',
    'monthly_report': 'Maasa Report',
    'reviews': 'Customer Ratings',
    'average_rating': 'Avg Rating',
    'tracking': 'Live Tracking',
    'promotions': 'Offers & Ads',
    'coupons': 'Discounts & Coupons',
    'create_coupon': 'Puthu Coupon Poda',
    'operating_hours': 'Kadai Timings',
    'open_time': 'Open Time',
    'close_time': 'Close Time',
    'save_settings': 'Settings Save Panna',
    'active': 'Active-aa Irukku',
    'expired': 'Mudinthuvittathu',
    'welcome_back': 'Vanakkam,',
  };
}
