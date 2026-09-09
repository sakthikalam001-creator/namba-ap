import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';

enum AppLanguage { english, tanglish, tamil }

class CustomerLanguageProvider with ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.english;

  CustomerLanguageProvider() {
    _loadSavedLanguage();
  }

  AppLanguage get currentLanguage => _currentLanguage;

  bool get isTamil => _currentLanguage == AppLanguage.tamil;
  bool get isTanglish => _currentLanguage == AppLanguage.tanglish;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

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

  String get currentCode {
    switch (_currentLanguage) {
      case AppLanguage.tamil:
        return 'ta';
      case AppLanguage.tanglish:
        return 'tanglish';
      case AppLanguage.english:
        return 'en';
    }
  }

  Future<void> _loadSavedLanguage() async {
    try {
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
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _currentLanguage = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      String langStr = 'english';
      if (lang == AppLanguage.tamil) {
        langStr = 'tamil';
      } else if (lang == AppLanguage.tanglish) {
        langStr = 'tanglish';
      }
      await prefs.setString('customer_language', langStr);
    } catch (_) {}
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
    // Navigation & Main Tabs
    'home': 'Home',
    'offers': 'Offers',
    'cart': 'Cart',
    'orders': 'Orders',
    'profile': 'Profile',

    // Search & Headers
    'delivering_to': 'DELIVERING TO',
    'search_hint': 'Search foods, groceries, restaurants...',
    'explore_nearby': 'Explore Nearby',
    'search_results': 'Search Results',
    'no_stores_found': 'No stores found',

    // Home Banner & Quick Pin
    'pin_any_shop': 'PIN ANY LOCATION ON MAP',
    'order_now': 'ORDER NOW',
    'top_stores': 'Top Stores & Restaurants',
    'categories': 'Categories',
    'add_to_cart': 'ADD',
    'checkout': 'Proceed to Pay',
    'pay_now': 'PAY NOW',

    // Profile & Settings
    'my_profile': 'My Profile',
    'wallet_balance': 'Namba Wallet',
    'top_up': 'TOP UP',
    'saved_address': 'Saved Addresses',
    'order_history': 'Order History',
    'view_past_orders': 'View past orders',
    'dark_mode': 'Dark Mode',
    'language': 'Language',
    'select_language': 'Select App Language',
    'help_support': 'Help & Support Desk',
    'help_desc': 'Raise tickets, track refunds & issues',
    'logout': 'Logout',
    'logout_desc': 'Sign out of your account',

    // Map & Location
    'set_delivery_location': 'Set Delivery Location',
    'order_will_be_delivered': 'ORDER WILL BE DELIVERED HERE',
    'locating_address': 'Finding your accurate location...',
    'refining_address': 'Refining exact address...',
    'confirm_location': 'CONFIRM LOCATION & PROCEED',
    'search_map_hint': 'Search street, area, landmark...',
    'pin_shop_location': 'PIN SHOP LOCATION',
    'pin_drop_location': 'PIN DROP LOCATION',
    'out_of_radius': 'OUT OF SERVICE RADIUS',
    'select_address_warning': 'Please select and confirm your delivery address on the map.',
    'enter_complete_address': 'ENTER COMPLETE ADDRESS',
    'door_no': 'House / Flat / Block No',
    'street': 'Apartment / Road / Street Name',
    'landmark': 'Landmark',
    'area_locality': 'Area / Locality',
    'pincode': 'City & Pincode',
    'save_address': 'SAVE ADDRESS & CONFIRM',
    'no_orders_yet': 'No orders yet',
    'culinary_journey': 'Your orders will appear here once placed!',
    'todays_orders': "TODAY'S ORDERS",
    'previous_orders': 'PREVIOUS ORDERS',

    // Login & Auth
    'sign_in_to_continue': 'Sign in to continue',
    'enter_phone_number': 'Enter your mobile number',
    'enter_phone_desc': "We'll send you a 6-digit security PIN via WhatsApp",
    'send_pin': 'Send WhatsApp PIN',
    'verify_pin': 'Verify PIN & Continue',
    'enter_security_pin': 'Enter Security PIN',
    'change_number': 'Edit',
    'edit': 'Edit',
    'instant_autofill_pin': 'Instant PIN',
    'resend_pin': 'Resend PIN via WhatsApp',
    'resend_in': 'Resend PIN in',
    'whatsapp_verified': 'WhatsApp Verified Login',
    'terms_privacy': 'By continuing, you agree to Namba Terms & Privacy Policy',
  };

  static const Map<String, String> _tanglishTranslations = {
    // Navigation & Main Tabs
    'home': 'Home',
    'offers': 'Offers',
    'cart': 'Cart',
    'orders': 'Orders',
    'profile': 'Profile',

    // Search & Headers
    'delivering_to': 'DELIVER PANNURA IDAM',
    'search_hint': 'Food, grocery, kadaigal thedunga...',
    'explore_nearby': 'Kitta Irukka Kadaigal',
    'search_results': 'Thedal Mudivugal',
    'no_stores_found': 'Kadaigal ethuvum kidaikkala',

    // Home Banner & Quick Pin
    'pin_any_shop': 'MAP LA KADA PIN PANNUNGA',
    'order_now': 'ORDER PANNU',
    'top_stores': 'Super Kadaigal & Hotels',
    'categories': 'Categories',
    'add_to_cart': 'ADD PANNU',
    'checkout': 'Kaasu Kudu (Pay)',
    'pay_now': 'PAY PANNU',

    // Profile & Settings
    'my_profile': 'En Profile',
    'wallet_balance': 'Namba Wallet',
    'top_up': 'PANAM SER',
    'saved_address': 'Saved Address-gal',
    'order_history': 'Pazhaiya Orders',
    'view_past_orders': 'Mudinja order-gal paarka',
    'dark_mode': 'Dark Mode',
    'language': 'Language (Mozhi)',
    'select_language': 'App Mozhiyai Thernthedunga',
    'help_support': 'Help & Support',
    'help_desc': 'Help ketka, refund & issues paarka',
    'logout': 'Logout Pannu',
    'logout_desc': 'Account la irunthu veliya po',

    // Map & Location
    'set_delivery_location': 'Delivery Idam Set Pannunga',
    'order_will_be_delivered': 'INGA THAAN DELIVERY AAGUM',
    'locating_address': 'Ungal location thedi kondirukkirom...',
    'refining_address': 'Sariyana address-ai verify seikirom...',
    'confirm_location': 'CONFIRM PANNITU CONTINUE PANNU',
    'search_map_hint': 'Street, area, landmark thedunga...',
    'pin_shop_location': 'KADA LOCATION PIN PANNU',
    'pin_drop_location': 'DROP LOCATION PIN PANNU',
    'out_of_radius': 'SERVICE LIMIT THANDI ULLATHU',
    'select_address_warning': 'Map-il ungal delivery mugavariyai confirm seiyavum.',
    'enter_complete_address': 'FULL ADDRESS DETAILS PODUNGA',
    'door_no': 'Door / Flat No',
    'street': 'Street / Road Name',
    'landmark': 'Landmark',
    'area_locality': 'Area / Oor',
    'pincode': 'City & Pincode',
    'save_address': 'ADDRESS SAVE PANNU',
    'no_orders_yet': 'Orders ethuvum illai',
    'culinary_journey': 'Ungal order-gal inge kaanapadum!',
    'todays_orders': "INDREIYA ORDER-GAL",
    'previous_orders': 'PAZHAIYA ORDER-GAL',

    // Login & Auth
    'sign_in_to_continue': 'Ulla poga Sign In pannunga',
    'enter_phone_number': 'Ungal Mobile Number podunga',
    'enter_phone_desc': "WhatsApp-la 6-digit Security PIN anupuvom",
    'send_pin': 'WhatsApp PIN Anuppu',
    'verify_pin': 'PIN Confirm Pannu & Continue',
    'enter_security_pin': 'Security PIN உள்ளிடவும்',
    'change_number': 'Edit',
    'edit': 'Edit',
    'instant_autofill_pin': 'Instant PIN',
    'resend_pin': 'WhatsApp PIN Meendum Anuppu',
    'resend_in': 'PIN Meendum anuppa',
    'whatsapp_verified': 'WhatsApp Verified Login',
    'terms_privacy': 'Thodarkaiyil Namba Terms & Privacy-yai etrukiringal',
  };

  static const Map<String, String> _tamilTranslations = {
    // Navigation & Main Tabs
    'home': 'முகப்பு',
    'offers': 'சலுகைகள்',
    'cart': 'கூடை',
    'orders': 'ஆர்டர்கள்',
    'profile': 'சுயவிவரம்',

    // Search & Headers
    'delivering_to': 'டெலிவரி இடம்',
    'search_hint': 'உணவு, மளிகை, உணவகங்களைத் தேடுக...',
    'explore_nearby': 'அருகிலுள்ள கடைகள்',
    'search_results': 'தேடல் முடிவுகள்',
    'no_stores_found': 'கடைகள் எதுவும் கிடைக்கவில்லை',

    // Home Banner & Quick Pin
    'pin_any_shop': 'மேப்பில் கடையை பின் செய்க',
    'order_now': 'ஆர்டர் செய்',
    'top_stores': 'பிரபல உணவகங்கள் & கடைகள்',
    'categories': 'வகைகள்',
    'add_to_cart': 'சேர்',
    'checkout': 'பணம் செலுத்து',
    'pay_now': 'பணம் செலுத்துக',

    // Profile & Settings
    'my_profile': 'என் சுயவிவரம்',
    'wallet_balance': 'நம்ம பணப்பை (Wallet)',
    'top_up': 'பணம் சேர்',
    'saved_address': 'சேமிக்கப்பட்ட முகவரிகள்',
    'order_history': 'ஆர்டர் வரலாறு',
    'view_past_orders': 'முந்தைய ஆர்டர்களைப் பார்க்க',
    'dark_mode': 'இருண்ட திரை (Dark Mode)',
    'language': 'மொழி',
    'select_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
    'help_support': 'வாடிக்கையாளர் உதவி மையம்',
    'help_desc': 'உதவி பெற & புகார்களைத் தெரிவிக்க',
    'logout': 'வெளியேறு (Logout)',
    'logout_desc': 'கணக்கிலிருந்து வெளியேற',

    // Map & Location
    'set_delivery_location': 'டெலிவரி முகவரியை அமைக்கவும்',
    'order_will_be_delivered': 'ஆர்டர் இங்கு டெலிவரி செய்யப்படும்',
    'locating_address': 'துல்லியமான இடத்தை தேடுகிறது...',
    'refining_address': 'முகவரி துல்லியமாகப் பெறப்படுகிறது...',
    'confirm_location': 'முகவரியை உறுதி செய்து தொடரவும்',
    'search_map_hint': 'தெரு, பகுதி, அடையாளத்தைத் தேடுக...',
    'pin_shop_location': 'கடையின் இடத்தை பின் செய்க',
    'pin_drop_location': 'டெலிவரி இடத்தை பின் செய்க',
    'out_of_radius': 'சேவை எல்லைக்கு அப்பால் உள்ளது',
    'select_address_warning': 'மேப்பில் உங்கள் டெலிவரி முகவரியை உறுதி செய்யவும்.',
    'enter_complete_address': 'முழு முகவரி விவரங்கள்',
    'door_no': 'கதவு / பிளாட் எண்',
    'street': 'தெரு / சாலை பெயர்',
    'landmark': 'அடையாளம் (Landmark)',
    'area_locality': 'பகுதி / ஏரியா',
    'pincode': 'நகரம் & பின்கோடு',
    'save_address': 'முகவரியைச் சேமித்து உறுதிசெய்',
    'no_orders_yet': 'ஆர்டர்கள் எதுவும் இல்லை',
    'culinary_journey': 'உங்கள் ஆர்டர்கள் இங்கு தோன்றும்!',
    'todays_orders': "இன்றைய ஆர்டர்கள்",
    'previous_orders': 'முந்தைய ஆர்டர்கள்',

    // Login & Auth
    'sign_in_to_continue': 'தொடர உள்நுழையவும்',
    'enter_phone_number': 'உங்கள் மொபைல் எண் உள்ளிடவும்',
    'enter_phone_desc': "வாட்ஸ்அப் வழியாக 6 இலக்க பாதுகாப்பு PIN அனுப்பப்படும்",
    'send_pin': 'வாட்ஸ்அப் PIN அனுப்புக',
    'verify_pin': 'PIN உறுதி செய்து தொடரவும்',
    'enter_security_pin': 'பாதுகாப்பு PIN உள்ளிடவும்',
    'change_number': 'மாற்று',
    'edit': 'மாற்று',
    'instant_autofill_pin': 'உடனடி PIN',
    'resend_pin': 'வாட்ஸ்அப் PIN மீண்டும் அனுப்புக',
    'resend_in': 'மீண்டும் அனுப்ப',
    'whatsapp_verified': 'வாட்ஸ்அப் சரிபார்ப்பு உள்நுழைவு',
    'terms_privacy': 'தொடர்வதன் மூலம் நம்ம விதிமுறைகள் & தனியுரிமைக் கொள்கையை ஏற்கிறீர்கள்',
  };

  static void showLanguageModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final lang = Provider.of<CustomerLanguageProvider>(ctx);
        final theme = Provider.of<ThemeProvider>(ctx);
        final isDark = theme.isDarkMode;

        return Container(
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.translate_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        lang.translate('select_language'),
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Option 1: English (No flag)
              _buildLanguageTile(
                ctx,
                lang: lang,
                theme: theme,
                value: AppLanguage.english,
                title: 'English',
                subtitle: 'Standard English',
                badgeText: 'EN',
              ),
              const SizedBox(height: 10),

              // Option 2: Tanglish (No flag)
              _buildLanguageTile(
                ctx,
                lang: lang,
                theme: theme,
                value: AppLanguage.tanglish,
                title: 'Tanglish (தமிழ்)',
                subtitle: 'Tamil words in English letters',
                badgeText: 'TN',
              ),
              const SizedBox(height: 10),

              // Option 3: Tamil (No flag)
              _buildLanguageTile(
                ctx,
                lang: lang,
                theme: theme,
                value: AppLanguage.tamil,
                title: 'தமிழ் (Tamil)',
                subtitle: 'தூய தமிழ் வடிவம்',
                badgeText: 'தமிழ்',
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildLanguageTile(
    BuildContext context, {
    required CustomerLanguageProvider lang,
    required ThemeProvider theme,
    required AppLanguage value,
    required String title,
    required String subtitle,
    required String badgeText,
  }) {
    final isSelected = lang.currentLanguage == value;
    final isDark = theme.isDarkMode;

    return InkWell(
      onTap: () {
        lang.setLanguage(value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5).withOpacity(isDark ? 0.2 : 0.08)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : theme.borderCol,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF242C3D) : const Color(0xFFEEF2FF)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF4F46E5) : theme.borderCol,
                ),
              ),
              child: Center(
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    fontSize: badgeText.length > 2 ? 11 : 14,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF4F46E5)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF4F46E5) : theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.borderCol, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
