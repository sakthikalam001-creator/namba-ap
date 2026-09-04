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
        return 'Tanglish (தமிழ்)';
      case AppLanguage.english:
        return 'English';
    }
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = prefs.getString('app_language');
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
    'kadai_online': 'STORE ONLINE',
    'kadai_offline': 'STORE OFFLINE',
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
    'total_revenue': 'TOTAL REVENUE',
    'total_sales_today': 'Total sales today',
    'daily_target_tracker': 'Daily Target Tracker',
    'achieved': 'achieved',
    'goal': 'goal',
    'accepted_today': 'Accepted Today',
    'declined_today': 'Declined Today',
    'low_stock': 'Low Stock',
    'notifications_alerts': 'Notifications & Alerts',
    'raise_support_ticket': 'Raise Support Ticket',
    'admin_support': 'Contact Admin Support',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'language': 'Language',
    'allow_background_battery': 'Allow Background Usage (Battery)',
    'recent_orders': 'Recent Orders',
    'no_orders_yet': 'No incoming orders yet',
    'ready_for_orders': 'Ready to receive orders',
  };

  static const Map<String, String> _tamilTranslations = {
    'dashboard': 'முகப்பு',
    'store_online': 'கடை திறந்துள்ளது (ONLINE)',
    'store_offline': 'கடை மூடப்பட்டுள்ளது (OFFLINE)',
    'kadai_online': 'கடை ஆன்லைனில் உள்ளது',
    'kadai_offline': 'கடை ஆஃப்லைனில் உள்ளது',
    'todays_sales': 'இன்றைய விற்பனை',
    'total_orders': 'மொத்த ஆர்டர்கள்',
    'store_rating': 'கடை மதிப்பீடு',
    'pending_orders': 'புதிய ஆர்டர்கள்',
    'active_orders': 'தற்போதைய ஆர்டர்கள்',
    'view_all': 'அனைத்தையும் காண்க',
    'revenue_overview': 'வருவாய் மேலோட்டம்',
    'weekly_growth': 'வாராந்திர வளர்ச்சி',
    'no_active_orders': 'தற்போது ஆர்டர்கள் இல்லை.',
    'inventory': 'சரக்கு பட்டியல்',
    'orders': 'ஆர்டர்கள்',
    'profile': 'கடை சுயவிவரம்',
    'wallet': 'பணப்பை',
    'earnings': 'வருமானம் & வரவு',
    'order_history': 'ஆர்டர் வரலாறு',
    'settings': 'அமைப்புகள்',
    'logout': 'வெளியேறு',
    'search': 'பொருட்களைத் தேடுக...',
    'stock': 'இருப்பு',
    'price': 'விலை',
    'out_of_stock': 'இருப்பு இல்லை',
    'in_stock': 'இருப்பு உள்ளது',
    'quick_actions': 'விரைவுச் செயல்கள்',
    'analytics': 'விற்பனை அறிக்கை',
    'revenue': 'மொத்த வருவாய்',
    'top_products': 'அதிகம் விற்ற பொருட்கள்',
    'fast_moving': 'வேகமாக விற்கும் பொருட்கள்',
    'slow_moving': 'மெதுவாக விற்கும் பொருட்கள்',
    'peak_hours': 'அதிக ஆர்டர்கள் வரும் நேரம்',
    'avg_order_value': 'சராசரி ஆர்டர் மதிப்பு',
    'weekly_report': 'வாராந்திர அறிக்கை',
    'monthly_report': 'மாதாந்திர அறிக்கை',
    'reviews': 'வாடிக்கையாளர் மதிப்புரைகள்',
    'average_rating': 'சராசரி மதிப்பீடு',
    'tracking': 'நேரடி கண்காணிப்பு',
    'promotions': 'விளம்பர சலுகைகள்',
    'coupons': 'கூப்பன்கள் & தள்ளுபடி',
    'create_coupon': 'புதிய கூப்பன் உருவாக்கு',
    'operating_hours': 'செயல்பாட்டு நேரம்',
    'open_time': 'திறக்கும் நேரம்',
    'close_time': 'மூடும் நேரம்',
    'save_settings': 'அமைப்புகளைச் சேமி',
    'active': 'செயலில் உள்ளது',
    'expired': 'காலாவதியானது',
    'welcome_back': 'வணக்கம்,',
    'total_revenue': 'மொத்த வருவாய்',
    'total_sales_today': 'இன்றைய மொத்த விற்பனை',
    'daily_target_tracker': 'தினசரி இலக்கு கண்காணிப்பு',
    'achieved': 'அடைந்தது',
    'goal': 'இலக்கு',
    'accepted_today': 'இன்று ஏற்கப்பட்டவை',
    'declined_today': 'இன்று நிராகரிக்கப்பட்டவை',
    'low_stock': 'குறைந்த இருப்பு',
    'notifications_alerts': 'அறிவிப்புகள் & எச்சரிக்கைகள்',
    'raise_support_ticket': 'புகார் பதிவு (Support Hub)',
    'admin_support': 'அட்மின் உதவி & தொடர்பு',
    'dark_mode': 'இருண்ட திரை (Dark Mode)',
    'light_mode': 'வெள்ளை திரை (Light Mode)',
    'language': 'மொழி (Language)',
    'allow_background_battery': 'பின்னணி இயக்கம் (Battery)',
    'recent_orders': 'சமீபத்திய ஆர்டர்கள்',
    'no_orders_yet': 'தற்போது புதிய ஆர்டர்கள் இல்லை',
    'ready_for_orders': 'புதிய ஆர்டர்களைப் பெற தயாராக உள்ளது',
  };

  static const Map<String, String> _tanglishTranslations = {
    'dashboard': 'Dashboard',
    'store_online': 'KADAI ONLINE',
    'store_offline': 'KADAI OFFLINE',
    'kadai_online': 'Kadai Online-la Irukku',
    'kadai_offline': 'Kadai Offline-la Irukku',
    'todays_sales': 'Innaiku Sales',
    'total_orders': 'Motha Orders',
    'store_rating': 'Kadai Rating',
    'pending_orders': 'Pudhu Orders',
    'active_orders': 'Active Orders',
    'view_all': 'Ellam Paaru',
    'revenue_overview': 'Varumaanam Report',
    'weekly_growth': 'Weekly Growth',
    'no_active_orders': 'Ippo orders edhum illa.',
    'inventory': 'Items & Stock',
    'orders': 'Orders',
    'profile': 'Kadai Profile',
    'wallet': 'Wallet',
    'earnings': 'Varumaanam',
    'order_history': 'Order History',
    'settings': 'Settings',
    'logout': 'Logout',
    'search': 'Thedu / Search...',
    'stock': 'Stock',
    'price': 'Vilai',
    'out_of_stock': 'Stock Illa',
    'in_stock': 'Stock Irukku',
    'quick_actions': 'Quick Actions',
    'analytics': 'Sales Analytics',
    'revenue': 'Motha Revenue',
    'top_products': 'Adhigama Vitha Items',
    'fast_moving': 'Fast Moving Items',
    'slow_moving': 'Slow Moving Items',
    'peak_hours': 'Adhiga Order Neram',
    'avg_order_value': 'Average Order Value',
    'weekly_report': 'Weekly Report',
    'monthly_report': 'Monthly Report',
    'reviews': 'Customer Reviews',
    'average_rating': 'Average Rating',
    'tracking': 'Live Tracking',
    'promotions': 'Offers & Discounts',
    'coupons': 'Coupons',
    'create_coupon': 'Pudhu Coupon Create Pannu',
    'operating_hours': 'Kadai Neram',
    'open_time': 'Thirakkum Neram',
    'close_time': 'Moodum Neram',
    'save_settings': 'Save Settings',
    'active': 'Active',
    'expired': 'Expired',
    'welcome_back': 'Welcome back,',
    'total_revenue': 'MOTHA REVENUE',
    'total_sales_today': 'Innaiku motha sales',
    'daily_target_tracker': 'Daily Target Tracker',
    'achieved': 'achieved',
    'goal': 'goal',
    'accepted_today': 'Innaiku Accept Panniyadhu',
    'declined_today': 'Innaiku Decline Panniyadhu',
    'low_stock': 'Koraivaana Stock',
    'notifications_alerts': 'Notifications & Alerts',
    'raise_support_ticket': 'Admin-kitta Support Kaelunga',
    'admin_support': 'Admin Support Helpline',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'language': 'Language (Mozhi)',
    'allow_background_battery': 'Allow Background (Battery)',
    'recent_orders': 'Recent Orders',
    'no_orders_yet': 'Pudhu orders innum varala',
    'ready_for_orders': 'Pudhu orders edukka ready-a irukku',
  };
}
