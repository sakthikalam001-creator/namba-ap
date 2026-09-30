import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, tamil, tanglish }

extension TranslationExtension on BuildContext {
  String tr(String key) {
    try {
      return Provider.of<DeliveryLanguageProvider>(this).translate(key);
    } catch (_) {
      return key;
    }
  }
}

class DeliveryLanguageProvider with ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  DeliveryLanguageProvider() {
    _loadSavedLanguage();
  }

  AppLanguage get currentLanguage => _currentLanguage;

  bool get isTamil => _currentLanguage == AppLanguage.tamil;
  bool get isTanglish => _currentLanguage == AppLanguage.tanglish;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  String text({required String en, required String ta, String? tanglish}) {
    if (isTamil) return ta;
    if (isTanglish) return tanglish ?? en;
    return en;
  }

  String get languageName {
    switch (_currentLanguage) {
      case AppLanguage.tamil:
        return 'தமிழ்';
      case AppLanguage.tanglish:
        return 'Tanglish';
      case AppLanguage.english:
        return 'English';
    }
  }

  String get languageCodeName {
    switch (_currentLanguage) {
      case AppLanguage.tamil:
        return 'Tamil';
      case AppLanguage.tanglish:
        return 'Tanglish';
      case AppLanguage.english:
        return 'English';
    }
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langStr = (prefs.getString('driver_language') ?? prefs.getString('app_language') ?? 'english').toLowerCase();
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
    String displayStr = 'English';
    if (lang == AppLanguage.tamil) {
      langStr = 'tamil';
      displayStr = 'Tamil';
    } else if (lang == AppLanguage.tanglish) {
      langStr = 'tanglish';
      displayStr = 'Tanglish';
    }
    await prefs.setString('driver_language', langStr);
    await prefs.setString('app_language', displayStr);
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
    // Top Bar & Duty
    'duty_on': 'DUTY ON',
    'duty_off': 'DUTY OFF',
    'dashboard': 'Dashboard',
    'orders': 'Orders',
    'good_morning': 'GOOD MORNING',
    'good_afternoon': 'GOOD AFTERNOON',
    'good_evening': 'GOOD EVENING',
    'today_metrics': 'TODAY\'S METRICS',
    'total_revenue': 'TOTAL REVENUE',
    'view_details': 'VIEW DETAILS',
    'find_hot_zones': 'FIND HOT ZONES',
    'active_missions': 'ACTIVE MISSIONS',
    'available_jobs': 'AVAILABLE JOBS',
    'completed_today': 'COMPLETED TODAY',
    'customer_rating': 'CUSTOMER RATING',
    'new_rider': 'NEW RIDER',
    'you_are_offline': 'YOU ARE OFFLINE',
    'offline_prompt': 'Swipe the toggle at the top or tap below to go live and receive customer orders.',
    'go_online_now': 'GO ONLINE NOW ⚡',
    'looking_nearby_orders': 'Searching for nearby orders...',
    'radar_listening': 'Looking for orders in your zone',
    'online_ready': 'ONLINE • READY FOR MISSIONS',
    'swipe_to_go_online': 'SWIPE TO GO ONLINE',
    'go_offline_q': 'Go Offline?',
    'go_offline_desc': 'Are you sure you want to go offline? You will stop receiving new delivery requests.',
    'cancel': 'CANCEL',
    'go_offline': 'GO OFFLINE',
    'scanning_missions': 'SCANNING FOR MISSIONS',
    'stay_online_desc': 'Stay online to receive instant delivery requests nearby...',
    'customer_ratings_count': 'CUSTOMER RATINGS',

    // Earnings Screen
    'earnings_payouts': 'EARNINGS & PAYOUTS',
    'total_earned_balance': 'TOTAL EARNED BALANCE',
    'live_sync': 'LIVE SYNC',
    'deliveries_completed': 'Deliveries Completed',
    'admin_settled': 'Admin Settled',
    'direct_admin_settlement': 'DIRECT ADMIN SETTLEMENT',
    'settlement_desc': 'Earnings are calculated automatically per order and transferred directly to your bank account or UPI by Super Admin.',
    'performance_breakdown': 'PERFORMANCE BREAKDOWN',
    'delivered_orders': 'DELIVERED ORDERS',
    'delivered_trips': 'Delivered Trips',
    'avg_per_trip': 'Avg per Trip',
    'completed_delivery_earnings': 'COMPLETED DELIVERY EARNINGS',
    'settled': 'SETTLED',
    'no_earnings_yet': 'NO DELIVERIES RECORDED YET',
    'no_earnings_sub': 'Completed orders will appear here along with verified trip earnings.',
    'pending_payout': 'PENDING PAYOUT',
    'settled_payout': 'SETTLED PAYOUT',
    'all_settled': 'ALL SETTLED',
    'awaiting_admin': 'Awaiting Admin Settlement',
    'transferred_upi': 'Transferred to Bank or UPI',
    'all_orders_tab': 'ALL',
    'pending_tab': 'PENDING',
    'settled_tab': 'SETTLED',
    'payout_method': 'Payout Mode',
    'settled_on': 'Settled Date',
    'txn_ref': 'Txn Ref',
    'credited_to_acc': 'Credited to Registered Bank or UPI',
    'awaiting_payout_notice': 'Awaiting Super Admin payout cycle. Will be transferred directly to your bank account or UPI.',
    'no_pending_payouts': 'ALL DELIVERIES SETTLED!',
    'no_pending_payouts_sub': 'Zero pending balance. All your completed orders have been paid and settled by admin.',
    'no_settled_payouts': 'NO SETTLED PAYOUTS YET',
    'no_settled_payouts_sub': 'Delivered orders will appear here once admin processes your payouts.',
    'lifetime_delivered': 'LIFETIME DELIVERIES',

    // Profile Screen
    'profile': 'PROFILE',
    'rider_profile': 'Rider Profile',
    'jobs': 'JOBS',
    'rating': 'RATING',
    'tier': 'TIER',
    'kyc_under_review': 'KYC UNDER REVIEW',
    'verified_partner': 'VERIFIED PARTNER',
    'action_required': 'RE-UPLOAD REQUIRED',
    'ai_fleet_assistant': 'AI FLEET ASSISTANT',
    'fleet_help_live_chat': 'Fleet Help & Live Chat',
    'instant_support_desc': 'Instant Help & Support Desk',
    'earnings_payments': 'Earnings & Payments',
    'partner_tiers': 'Partner Tiers',
    'partner_perks': 'Partner Perks & Benefits',
    'document_verification': 'Document Verification',
    'refer_earn': 'Refer & Earn',
    'ai_chatbot': 'AI Rider Assistant',
    'support_help': 'Support & Help Desk',
    'settings': 'Settings',
    'logout_account': 'Logout Account',
    'safety_center': 'SAFETY CENTER',
    'emergency_sos_help': 'Emergency SOS & Help',

    // Settings Screen
    'app_configuration': 'APP CONFIGURATION',
    'communication': 'COMMUNICATION',
    'order_notifications': 'Order Notifications',
    'app_language': 'App Language',
    'account_security': 'ACCOUNT & SECURITY',
    'rider_setup_permissions': 'Rider Setup & Permissions',
    'verified_profile_details': 'Profile & Vehicle Details',
    'profile_admin_locked': 'ADMIN PROTECTED PROFILE',
    'profile_locked_desc': 'Profile details are verified and managed exclusively by Super Admin. Contact Admin to request changes.',
    'contact_admin_notice': 'Contact Super Admin to update your Name, Phone, Vehicle, or Bank / UPI details.',
    'full_name': 'Full Name',
    'mobile_number': 'Registered Mobile Number',
    'vehicle_type': 'Vehicle Type',
    'vehicle_number': 'Vehicle Number Plate',
    'upi_id': 'Payout Bank or UPI ID',
    'close': 'Close',

    // Language Modal
    'select_app_language': 'SELECT APP LANGUAGE',
    'choose_display_lang': 'Choose your preferred display language',
    'lang_english_title': 'English',
    'lang_english_desc': 'Global standard interface & voice dispatch',
    'lang_tamil_title': 'Tamil',
    'lang_tamil_desc': 'Pure Tamil interface & voice guidance',
    'lang_tanglish_title': 'Tanglish',
    'lang_tanglish_desc': 'Tamil in English script',

    // Partner Tiers
    'partner_tiers_progress': 'PARTNER TIERS & PROGRESS',
    'current_partner_level': 'CURRENT PARTNER LEVEL',
    'partner_level_label': 'PARTNER',
    'completed_deliveries': 'Completed Deliveries',
    'tier_privileges': 'TIER PRIVILEGES',
    'progress_to': 'PROGRESS TO',
    'achievement_badges': 'ACHIEVEMENT BADGES',
    'silver_tier': 'SILVER',
    'gold_tier': 'GOLD',
    'platinum_tier': 'PLATINUM',
  };

  static const Map<String, String> _tamilTranslations = {
    // Top Bar & Duty
    'duty_on': 'பணியில் உள்ளார்',
    'duty_off': 'பணி நிறைவு',
    'dashboard': 'முகப்பு',
    'orders': 'ஆர்டர்கள்',
    'good_morning': 'காலை வணக்கம்',
    'good_afternoon': 'மதிய வணக்கம்',
    'good_evening': 'மாலை வணக்கம்',
    'today_metrics': 'இன்றைய விவரங்கள்',
    'total_revenue': 'மொத்த வருமானம்',
    'view_details': 'விவரங்களை காண்க',
    'find_hot_zones': 'அதிக ஆர்டர் பகுதிகள்',
    'active_missions': 'தற்போதைய ஆர்டர்கள்',
    'available_jobs': 'கிடைக்கும் ஆர்டர்கள்',
    'completed_today': 'இன்று முடித்தவை',
    'customer_rating': 'வாடிக்கையாளர் மதிப்பீடு',
    'new_rider': 'புதிய ரைடர்',
    'you_are_offline': 'நீங்கள் ஆஃப்லைனில் உள்ளீர்கள்',
    'offline_prompt': 'ஆன்லைனுக்கு மாறி புதிய வாடிக்கையாளர் ஆர்டர்களைப் பெற மேலே உள்ள ஸ்லைடரை நகர்த்தவும்.',
    'go_online_now': 'இப்போதே ஆன்லைனுக்கு வாருங்கள் ⚡',
    'looking_nearby_orders': 'அருகிலுள்ள ஆர்டர்களைத் தேடுகிறது...',
    'radar_listening': 'உங்கள் பகுதியில் ஆர்டர்கள் கண்காணிக்கப்படுகின்றன',
    'online_ready': 'ஆன்லைன் • ஆர்டர்களுக்கு தயார்',
    'swipe_to_go_online': 'ஆன்லைனுக்கு செல்ல ஸ்வைப் செய்யவும்',
    'go_offline_q': 'ஆஃப்லைனுக்கு செல்லவா?',
    'go_offline_desc': 'நீங்கள் ஆஃப்லைனுக்கு செல்ல விரும்புகிறீர்களா? புதிய ஆர்டர்கள் வருவது நிறுத்தப்படும்.',
    'cancel': 'ரத்து செய்',
    'go_offline': 'ஆஃப்லைன் போ',
    'scanning_missions': 'ஆர்டர்களைத் தேடுகிறது',
    'stay_online_desc': 'அருகிலுள்ள ஆர்டர்களைப் பெற ஆன்லைனில் இணைந்திருங்கள்...',
    'customer_ratings_count': 'வாடிக்கையாளர் மதிப்பீடுகள்',

    // Earnings Screen
    'earnings_payouts': 'வருமானம் மற்றும் பணப்பரிமாற்றம்',
    'total_earned_balance': 'மொத்த வருமான இருப்பு',
    'live_sync': 'நேரலை வரவு',
    'deliveries_completed': 'டெலிவரிகள் முடிந்தது',
    'admin_settled': 'அட்மின் வரவு வைக்கப்பட்டது',
    'direct_admin_settlement': 'நேரடி அட்மின் பணப்பரிமாற்றம்',
    'settlement_desc': 'ஒவ்வொரு ஆர்டருக்குமான வருமானம் தானாக கணக்கிடப்பட்டு, சூப்பர் அட்மின் மூலம் உங்கள் வங்கி அல்லது UPI கணக்கிற்கு நேரடியாக வரவு வைக்கப்படும்.',
    'performance_breakdown': 'செயல்திறன் விவரம்',
    'delivered_orders': 'முடித்த ஆர்டர்கள்',
    'delivered_trips': 'முடித்த பயணங்கள்',
    'avg_per_trip': 'பயண சராசரி',
    'completed_delivery_earnings': 'முடிக்கப்பட்ட ஆர்டர்களின் வருமானம்',
    'settled': 'வரவு வைக்கப்பட்டது',
    'no_earnings_yet': 'இன்னும் ஆர்டர்கள் முடிக்கப்படவில்லை',
    'no_earnings_sub': 'நீங்கள் முடிக்கும் ஆர்டர்களின் வருமான விவரங்கள் உடனடியாக இங்கே பட்டியலிடப்படும்.',
    'pending_payout': 'செட்டில்மென்ட் நிலுவை',
    'settled_payout': 'செட்டில் ஆன தொகை',
    'all_settled': 'முழுவதும் செட்டில் செய்யப்பட்டது',
    'awaiting_admin': 'அட்மின் செட்டில்மெண்டிற்காக காத்திருக்கிறது',
    'transferred_upi': 'வங்கி அல்லது UPI-க்கு வரவு வைக்கப்பட்டது',
    'all_orders_tab': 'அனைத்தும்',
    'pending_tab': 'நிலுவை',
    'settled_tab': 'வரவானவை',
    'payout_method': 'செட்டில்மென்ட் முறை',
    'settled_on': 'செட்டில் செய்த தேதி',
    'txn_ref': 'பரிவர்த்தனை குறிப்பு',
    'credited_to_acc': 'பதிவு செய்யப்பட்ட வங்கி அல்லது UPI கணக்கு',
    'awaiting_payout_notice': 'அடுத்த அட்மின் பணப்பரிமாற்ற சுழற்சியில் உங்கள் வங்கி அல்லது UPI கணக்கிற்கு நேரடியாக அனுப்பப்படும்.',
    'no_pending_payouts': 'அனைத்து வருமானமும் செட்டில் செய்யப்பட்டது!',
    'no_pending_payouts_sub': 'எந்த நிலுவைத் தொகையும் இல்லை. உங்கள் அனைத்து டெலிவரி வருமானமும் அட்மினால் வரவு வைக்கப்பட்டுவிட்டது.',
    'no_settled_payouts': 'இன்னும் செட்டில்மென்ட் வரவில்லை',
    'no_settled_payouts_sub': 'அட்மின் பணப்பரிமாற்றம் செய்ததும் அவை இங்கே காட்டப்படும்.',
    'lifetime_delivered': 'மொத்த டெலிவரிகள்',

    // Profile Screen
    'profile': 'சுயவிவரம்',
    'rider_profile': 'ரைடர் சுயவிவரம்',
    'jobs': 'பயணங்கள்',
    'rating': 'மதிப்பீடு',
    'tier': 'அடுக்கு',
    'kyc_under_review': 'அட்மின் மதிப்பாய்வில்',
    'verified_partner': 'சரிபார்க்கப்பட்ட பார்ட்னர்',
    'action_required': 'ஆவணங்களை மீண்டும் பதிவேற்றவும்',
    'ai_fleet_assistant': 'AI ரைடர் உதவி மையம்',
    'fleet_help_live_chat': 'நேரடி உதவி & அரட்டை',
    'instant_support_desc': 'உடனடி அட்மின் உதவி மையம்',
    'earnings_payments': 'வருமானம் மற்றும் பணப்பரிமாற்றம்',
    'partner_tiers': 'பார்ட்னர் அடுக்குகள்',
    'partner_perks': 'பார்ட்னர் சலுகைகள் மற்றும் நன்மைகள்',
    'document_verification': 'ஆவண சரிபார்ப்பு',
    'refer_earn': 'பகிர்ந்து சம்பாதிக்கவும்',
    'ai_chatbot': 'AI ரைடர் உதவியாளர்',
    'support_help': 'ஆதரவு மற்றும் உதவி மையம்',
    'settings': 'அமைப்புகள்',
    'logout_account': 'வெளியேறு',
    'safety_center': 'பாதுகாப்பு மையம்',
    'emergency_sos_help': 'அவசர உதவி மற்றும் தொடர்பு',

    // Settings Screen
    'app_configuration': 'ஆப் அமைப்புகள்',
    'communication': 'தகவல்தொடர்பு',
    'order_notifications': 'ஆர்டர் அறிவிப்புகள்',
    'app_language': 'ஆப் மொழி',
    'account_security': 'கணக்கு மற்றும் பாதுகாப்பு',
    'rider_setup_permissions': 'ரைடர் அமைப்புகள் மற்றும் அனுமதிகள்',
    'verified_profile_details': 'சுயவிவரம் மற்றும் வாகன விவரங்கள்',
    'profile_admin_locked': 'அட்மினால் சரிபார்க்கப்பட்டது',
    'profile_locked_desc': 'உங்கள் சுயவிவர விவரங்கள் சூப்பர் அட்மினால் சரிபார்க்கப்பட்டு பூட்டப்பட்டுள்ளன. மாற்றங்கள் செய்ய சூப்பர் அட்மினை அணுகவும்.',
    'contact_admin_notice': 'பெயர், தொலைபேசி, வண்டி எண் அல்லது UPI விவரங்களை மாற்ற சூப்பர் அட்மினைத் தொடர்பு கொள்ளவும்.',
    'full_name': 'முழு பெயர்',
    'mobile_number': 'பதிவு செய்யப்பட்ட மொபைல் எண்',
    'vehicle_type': 'வாகன வகை',
    'vehicle_number': 'வாகன எண் பலகை',
    'upi_id': 'பணப்பரிமாற்ற வங்கி அல்லது UPI முகவரி',
    'close': 'மூடு',

    // Language Modal
    'select_app_language': 'ஆப் மொழியைத் தேர்ந்தெடுக்கவும்',
    'choose_display_lang': 'உங்கள் விருப்ப மொழியைத் தேர்ந்தெடுக்கவும்',
    'lang_english_title': 'ஆங்கிலம்',
    'lang_english_desc': 'தரமான ஆங்கில இடைமுகம்',
    'lang_tamil_title': 'தமிழ்',
    'lang_tamil_desc': 'தூய தமிழ் இடைமுகம் & குரல் வழிகாட்டல்',
    'lang_tanglish_title': 'தங்கிலீஷ்',
    'lang_tanglish_desc': 'ஆங்கில எழுத்தில் தமிழ் உரை',

    // Partner Tiers
    'partner_tiers_progress': 'பார்ட்னர் நிலைகள் & முன்னேற்றம்',
    'current_partner_level': 'தற்போதைய பார்ட்னர் நிலை',
    'partner_level_label': 'பார்ட்னர்',
    'completed_deliveries': 'முடிக்கப்பட்ட டெலிவரிகள்',
    'tier_privileges': 'அடுக்கு சலுகைகள்',
    'progress_to': 'அடுத்த நிலை இலக்கு',
    'achievement_badges': 'சாதனை பதக்கங்கள்',
    'silver_tier': 'சில்வர்',
    'gold_tier': 'கோல்ட்',
    'platinum_tier': 'பிளாட்டினம்',
  };

  static const Map<String, String> _tanglishTranslations = {
    // Top Bar & Duty
    'duty_on': 'DUTY ON',
    'duty_off': 'DUTY OFF',
    'dashboard': 'Dashboard',
    'orders': 'Orders',
    'good_morning': 'GOOD MORNING',
    'good_afternoon': 'GOOD AFTERNOON',
    'good_evening': 'GOOD EVENING',
    'today_metrics': 'INAIKU METRICS',
    'total_revenue': 'TOTAL EARNINGS',
    'view_details': 'DETAILS PARUNGA',
    'find_hot_zones': 'HOT ZONES THEEDUNGA',
    'active_missions': 'ACTIVE ORDERS',
    'available_jobs': 'AVAILABLE ORDERS',
    'completed_today': 'Inaiku Mudichathu',
    'customer_rating': 'Customer Rating',
    'new_rider': 'Pudhu Rider',
    'you_are_offline': 'NEENGA OFFLINE-LA IRUKKEENGA',
    'offline_prompt': 'Orders eduka mela irukka toggle swipe pannunga or go online button click pannunga.',
    'go_online_now': 'IPPO ONLINE VAANGA ⚡',
    'looking_nearby_orders': 'Pakkathula orders theduthu...',
    'radar_listening': 'Unga area-la orders check panrom',
    'online_ready': 'ONLINE • READY FOR MISSIONS',
    'swipe_to_go_online': 'SWIPE PANNI ONLINE VAANGA',
    'go_offline_q': 'Offline Pogavaa?',
    'go_offline_desc': 'Kandippa offline poringala? Puthiya orders varaathu.',
    'cancel': 'CANCEL',
    'go_offline': 'GO OFFLINE',
    'scanning_missions': 'ORDERS THEDUTHU',
    'stay_online_desc': 'Orders kedaika online-la irunga...',
    'customer_ratings_count': 'CUSTOMER RATINGS',

    // Earnings Screen
    'earnings_payouts': 'EARNINGS & PAYOUTS',
    'total_earned_balance': 'TOTAL EARNED BALANCE',
    'live_sync': 'LIVE SYNC',
    'deliveries_completed': 'Deliveries Mudichathu',
    'admin_settled': 'Admin Settled',
    'direct_admin_settlement': 'DIRECT ADMIN SETTLEMENT',
    'settlement_desc': 'Orders mudiyum pothu earnings auto-va calculate aagi Admin direct-ah unga Bank/UPI-ku anupuvaanga.',
    'performance_breakdown': 'PERFORMANCE BREAKDOWN',
    'delivered_orders': 'MUDICHA ORDERS',
    'delivered_trips': 'Delivered Trips',
    'avg_per_trip': 'Avg per Trip',
    'completed_delivery_earnings': 'COMPLETED ORDERS EARNINGS',
    'settled': 'SETTLED',
    'no_earnings_yet': 'INNUM ORDERS MUDIKALA',
    'no_earnings_sub': 'Orders mudicha trip earnings inga accurate-ah kaattum.',
    'pending_payout': 'PENDING PAYOUT',
    'settled_payout': 'SETTLED PAYOUT',
    'all_settled': 'ALL SETTLED',
    'awaiting_admin': 'Admin Settlement Pending',
    'transferred_upi': 'Bank or UPI-ku Anupiyachu',
    'all_orders_tab': 'ALL',
    'pending_tab': 'PENDING',
    'settled_tab': 'SETTLED',
    'payout_method': 'Payout Mode',
    'settled_on': 'Settled Date',
    'txn_ref': 'Txn Ref',
    'credited_to_acc': 'Registered Bank or UPI-ku Credited',
    'awaiting_payout_notice': 'Super Admin adutha settlement cycle-la unga Bank or UPI-ku direct-ah transfer pannuvaanga.',
    'no_pending_payouts': 'ALL ORDERS SETTLED!',
    'no_pending_payouts_sub': 'Zero pending balance. Neenga mudicha ella order earnings-um admin pay pannitaanga.',
    'no_settled_payouts': 'INNUM SETTLED ORDERS ILLA',
    'no_settled_payouts_sub': 'Admin transfer pannathum settled orders inga list aagum.',
    'lifetime_delivered': 'LIFETIME DELIVERIES',

    // Profile Screen
    'profile': 'PROFILE',
    'rider_profile': 'Rider Profile',
    'jobs': 'JOBS',
    'rating': 'RATING',
    'tier': 'TIER',
    'kyc_under_review': 'Admin Review-la Irukku',
    'verified_partner': 'Verified Partner',
    'action_required': 'Doc Re-upload Pannu',
    'ai_fleet_assistant': 'AI Rider Assistant',
    'fleet_help_live_chat': 'Live Help & Chat Desk',
    'instant_support_desc': 'Instant Admin Help Desk',
    'earnings_payments': 'Earnings & Payouts',
    'partner_tiers': 'Partner Tiers',
    'partner_perks': 'Partner Benefits & Perks',
    'document_verification': 'Document Status Check',
    'refer_earn': 'Refer & Sambathiyunga',
    'ai_chatbot': 'AI Rider Chatbot',
    'support_help': 'Help & Support Desk',
    'settings': 'Settings',
    'logout_account': 'Logout Pannu',
    'safety_center': 'SAFETY CENTER',
    'emergency_sos_help': 'Emergency SOS & Help',

    // Settings Screen
    'app_configuration': 'APP CONFIGURATION',
    'communication': 'COMMUNICATION',
    'order_notifications': 'Order Notifications',
    'app_language': 'App Language',
    'account_security': 'ACCOUNT & SECURITY',
    'rider_setup_permissions': 'Rider Permissions Setup',
    'verified_profile_details': 'Profile & Vehicle Details',
    'profile_admin_locked': 'ADMIN VERIFIED (LOCKED)',
    'profile_locked_desc': 'Profile details Super Admin verify panni lock pannirukaanga. Changes venumna Admin-a contact pannunga.',
    'contact_admin_notice': 'Name, Phone, Vehicle number or UPI ID maatha Super Admin-a contact pannunga.',
    'full_name': 'Full Name',
    'mobile_number': 'Mobile Number',
    'vehicle_type': 'Vehicle Type',
    'vehicle_number': 'Vehicle Number Plate',
    'upi_id': 'Payout Bank or UPI ID',
    'close': 'Close',

    // Language Modal
    'select_app_language': 'SELECT APP LANGUAGE',
    'choose_display_lang': 'Ungalukku pidicha language select pannunga',
    'lang_english_title': 'English',
    'lang_english_desc': 'Global standard interface & voice dispatch',
    'lang_tamil_title': 'Tamil',
    'lang_tamil_desc': 'Thooya Tamil interface',
    'lang_tanglish_title': 'Tanglish',
    'lang_tanglish_desc': 'Tamil in English script',

    // Partner Tiers
    'partner_tiers_progress': 'PARTNER TIERS & PROGRESS',
    'current_partner_level': 'CURRENT PARTNER LEVEL',
    'partner_level_label': 'PARTNER',
    'completed_deliveries': 'Completed Deliveries',
    'tier_privileges': 'TIER PRIVILEGES',
    'progress_to': 'ADUTHA LEVEL TARGET',
    'achievement_badges': 'ACHIEVEMENT BADGES',
    'silver_tier': 'SILVER',
    'gold_tier': 'GOLD',
    'platinum_tier': 'PLATINUM',
  };
}
