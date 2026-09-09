import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/location_accuracy_service.dart';
import 'map_location_picker_screen.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  bool _isRefreshingGps = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<CustomerLanguageProvider>(context);
    final isDark = theme.isDarkMode;

    // Filter out current_gps from standard saved addresses list so it doesn't look like an editable card
    final savedList = auth.addresses.where((a) => a.id != 'current_gps').toList();
    final isCurrentGpsSelected = auth.selectedAddress.id == 'current_gps';

    // Resolved Live GPS details
    final liveGpsAddress = (LocationAccuracyService.lastKnownAddress != null &&
            LocationAccuracyService.lastKnownAddress!.isNotEmpty &&
            !LocationAccuracyService.lastKnownAddress!.toLowerCase().contains('detecting'))
        ? LocationAccuracyService.lastKnownAddress!
        : (auth.address.isNotEmpty && !auth.address.toLowerCase().contains('detecting')
            ? auth.address
            : (lang.isTamil ? 'நேரலை இருப்பிடத்தை கண்டறிகிறது...' : 'Detecting Live GPS Location...'));

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: theme.cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.borderCol),
                ),
                child: Icon(Icons.arrow_back_rounded, color: theme.textPrimary, size: 20),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.isTamil ? 'சேமிக்கப்பட்ட முகவரிகள்' : 'Saved Addresses',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17.5, color: theme.textPrimary),
            ),
            Text(
              lang.isTamil
                  ? '${savedList.length} முகவரிகள் சேமிக்கப்பட்டுள்ளன'
                  : '${savedList.length} Delivery Location${savedList.length == 1 ? '' : 's'} Saved',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 11.5, color: theme.textSecondary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => _openMapPicker(context, auth),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_location_alt_rounded, size: 16, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 4),
                    Text(
                      lang.isTamil ? 'புதியது' : 'Add New',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11.5, color: const Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. TOP HERO: CURRENT LIVE GPS LOCATION CARD ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF1E293B)]
                        : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCurrentGpsSelected
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF818CF8).withValues(alpha: 0.35),
                    width: isCurrentGpsSelected ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      auth.selectAddress('current_gps');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lang.isTamil
                                      ? 'தற்போதைய ஜிபிஎஸ் இருப்பிடம் தேர்ந்தெடுக்கப்பட்டது'
                                      : 'Live GPS location selected for delivery',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.my_location_rounded, color: Color(0xFF4F46E5), size: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          lang.isTamil ? 'தற்போதைய இருப்பிடம்' : 'Current Live Location',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            color: theme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'GPS LIVE',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color(0xFF10B981),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      lang.isTamil
                                          ? 'துல்லியமான ஜிபிஎஸ் டோர்-டெலிவரி'
                                          : 'Satellite accurate pin for doorstep delivery',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrentGpsSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        lang.isTamil ? 'தேர்வு' : 'SELECTED',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                InkWell(
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    setState(() => _isRefreshingGps = true);
                                    await auth.useCurrentGpsLocation(selectAsActive: true);
                                    if (mounted) setState(() => _isRefreshingGps = false);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: _isRefreshingGps
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : Text(
                                            lang.isTamil ? 'தேர்வு செய்' : 'USE GPS',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.borderCol.withValues(alpha: 0.7)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.place_rounded, size: 16, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    liveGpsAddress,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── SECTION HEADER: SAVED PLACES ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang.isTamil ? 'சேமிக்கப்பட்ட இடங்கள்' : 'YOUR SAVED PLACES',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: theme.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${savedList.length} ${lang.isTamil ? 'முகவரிகள்' : 'Places'}',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── EMPTY STATE OR ADDRESS LIST ──
          if (savedList.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.borderCol),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bookmark_add_rounded, size: 36, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        lang.isTamil ? 'சேமிக்கப்பட்ட முகவரிகள் இல்லை' : 'No Saved Addresses Yet',
                        style: GoogleFonts.outfit(fontSize: 16.5, fontWeight: FontWeight.w900, color: theme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lang.isTamil
                            ? 'வீடு, அலுவலகம் போன்ற இடங்களை வரைபடத்தில் விரைவாக தேர்வு செய்து சேமிக்கவும்.'
                            : 'Save your home, office, and favorite locations for seamless one-tap ordering.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 12.5, color: theme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _openMapPicker(context, auth),
                        icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                        label: Text(
                          lang.isTamil ? 'வரைபடத்தில் முகவரியைச் சேர்' : 'Add First Address on Map',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final addr = savedList[i];
                    final isSelected = auth.selectedAddress.id == addr.id;
                    return _buildAddressCard(context, addr, isSelected, auth, theme, lang, isDark);
                  },
                  childCount: savedList.length,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: theme.cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _openMapPicker(context, auth),
              icon: const Icon(Icons.add_location_alt_rounded, size: 20),
              label: Text(
                lang.isTamil ? 'வரைபடத்தில் புதிய முகவரியைச் சேர்' : 'Add New Address on Map',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: 0.3),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    UserAddress addr,
    bool isSelected,
    AuthProvider auth,
    ThemeProvider theme,
    CustomerLanguageProvider lang,
    bool isDark,
  ) {
    final normLabel = addr.label.trim().toLowerCase();
    final bool isHome = normLabel == 'home';
    final bool isWork = normLabel == 'work' || normLabel == 'office';

    final Color badgeColor = isHome
        ? const Color(0xFF4F46E5)
        : (isWork ? const Color(0xFF059669) : const Color(0xFFD97706));

    final IconData badgeIcon = isHome
        ? Icons.home_rounded
        : (isWork ? Icons.business_center_rounded : Icons.location_on_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFFBFBFF))
            : theme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF4F46E5) : theme.borderCol,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : (isSelected ? 0.08 : 0.03)),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            auth.selectAddress(addr.id);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Chip + Action Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(badgeIcon, color: badgeColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addr.label.isNotEmpty ? addr.label : (lang.isTamil ? 'முகவரி' : 'Saved Address'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                color: theme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 5),
                            Text(
                              lang.isTamil ? 'டெலிவரி இடம்' : 'DELIVER HERE',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF10B981),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Full Address Text
                Text(
                  addr.address,
                  style: GoogleFonts.outfit(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Action Buttons: Deliver Here / Edit / Delete
                Divider(color: theme.borderCol.withValues(alpha: 0.6), height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isSelected)
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          auth.selectAddress(addr.id);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.radio_button_unchecked_rounded, size: 16, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 6),
                              Text(
                                lang.isTamil ? 'இங்கு டெலிவரி செய்' : 'Set as Delivery Location',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radio_button_checked_rounded, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            lang.isTamil ? 'முதன்மை முகவரி' : 'Active Delivery Address',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _showAddAddressSheet(context, existing: addr),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 14, color: theme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  lang.isTamil ? 'திருத்து' : 'Edit',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: theme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _confirmDeleteAddress(context, addr, auth, lang),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                                const SizedBox(width: 4),
                                Text(
                                  lang.isTamil ? 'நீக்கு' : 'Delete',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAddress(BuildContext context, UserAddress addr, AuthProvider auth, CustomerLanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          lang.isTamil ? 'முகவரியை நீக்கவா?' : 'Delete Saved Address?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        content: Text(
          lang.isTamil
              ? 'இந்த முகவரியை நீக்க விரும்புகிறீர்களா: ${addr.label}?'
              : 'Are you sure you want to remove "${addr.label}" from your saved delivery locations?',
          style: GoogleFonts.outfit(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              lang.isTamil ? 'ரத்து' : 'Cancel',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              auth.removeAddress(addr.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              lang.isTamil ? 'நீக்கு' : 'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _openMapPicker(BuildContext context, AuthProvider auth) {
    final lastPos = LocationAccuracyService.lastKnownAccuratePosition;
    final initialLoc = (lastPos != null && lastPos.latitude != 0.0)
        ? LatLng(lastPos.latitude, lastPos.longitude)
        : (auth.selectedAddress.lat != null && auth.selectedAddress.lat != 0.0
            ? LatLng(auth.selectedAddress.lat!, auth.selectedAddress.lng!)
            : null);
    final initialAddr = (LocationAccuracyService.lastKnownAddress != null &&
            LocationAccuracyService.lastKnownAddress!.isNotEmpty)
        ? LocationAccuracyService.lastKnownAddress!
        : (auth.address.isNotEmpty ? auth.address : null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLocation: initialLoc,
          initialAddress: initialAddr,
        ),
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context, {UserAddress? existing}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final lang = Provider.of<CustomerLanguageProvider>(context, listen: false);
    final isDark = theme.isDarkMode;

    String selectedCategory = (existing?.label != null && existing!.label.isNotEmpty) ? existing.label : 'Home';
    final houseNoCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final landmarkCtrl = TextEditingController();

    // Parse existing address parts if editing
    if (existing != null) {
      final parts = existing.address.split(',');
      if (parts.length >= 3) {
        houseNoCtrl.text = parts[0].trim();
        streetCtrl.text = parts[1].trim();
        landmarkCtrl.text = parts.sublist(2).join(',').trim();
      } else if (parts.length == 2) {
        houseNoCtrl.text = parts[0].trim();
        streetCtrl.text = parts[1].trim();
      } else {
        streetCtrl.text = existing.address;
      }
    }

    double? detectedLat = existing?.lat ?? LocationAccuracyService.lastKnownAccuratePosition?.latitude;
    double? detectedLng = existing?.lng ?? LocationAccuracyService.lastKnownAccuratePosition?.longitude;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: theme.borderCol,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existing == null
                            ? (lang.isTamil ? 'புதிய முகவரியைச் சேர்' : 'Add New Address')
                            : (lang.isTamil ? 'முகவரியைத் திருத்து' : 'Edit Address Details'),
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Selector Chips: [ Home 🏠 ] [ Work 💼 ] [ Other 📍 ]
                  Text(
                    lang.isTamil ? 'முகவரி வகை (CATEGORY) *' : 'SAVE ADDRESS AS *',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Home', 'Work', 'Other'].map((cat) {
                      final isCatSelected = selectedCategory.toLowerCase() == cat.toLowerCase();
                      final IconData cIcon = cat == 'Home'
                          ? Icons.home_rounded
                          : (cat == 'Work' ? Icons.business_center_rounded : Icons.location_on_rounded);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setStateSheet(() => selectedCategory = cat);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isCatSelected
                                    ? const Color(0xFF4F46E5)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCatSelected ? const Color(0xFF4F46E5) : theme.borderCol,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    cIcon,
                                    size: 16,
                                    color: isCatSelected ? Colors.white : theme.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat == 'Home' ? (lang.isTamil ? 'வீடு' : 'Home') : (cat == 'Work' ? (lang.isTamil ? 'பணி' : 'Work') : (lang.isTamil ? 'மற்றவை' : 'Other')),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: isCatSelected ? Colors.white : theme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Mandatory House Number
                  _buildSheetInputField(
                    controller: houseNoCtrl,
                    label: lang.isTamil ? 'வீட்டு எண் / தளம் *' : 'House / Flat / Floor No. *',
                    hint: lang.isTamil ? 'எ.கா. 42B, முதல் தளம்' : 'e.g. 42B, 1st Floor',
                    icon: Icons.door_front_door_rounded,
                    theme: theme,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Street / Building Name
                  _buildSheetInputField(
                    controller: streetCtrl,
                    label: lang.isTamil ? 'கட்டிடம் / அபார்ட்மெண்ட் / தெரு *' : 'Building / Apartment / Street Name *',
                    hint: lang.isTamil ? 'எ.கா. ராஜாஜி தெரு' : 'e.g. Rajaji Street, Main Road',
                    icon: Icons.location_city_rounded,
                    theme: theme,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Landmark / Area
                  _buildSheetInputField(
                    controller: landmarkCtrl,
                    label: lang.isTamil ? 'அடையாளக் குறி (Landmark) *' : 'Landmark / Nearby Spot *',
                    hint: lang.isTamil ? 'எ.கா. சிவன் கோவில் அருகில்' : 'e.g. Near Vinayagar Temple / Bus Stop',
                    icon: Icons.place_rounded,
                    theme: theme,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Attached GPS Indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (detectedLat != null ? const Color(0xFF10B981) : Colors.orange).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (detectedLat != null ? const Color(0xFF10B981) : Colors.orange).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          detectedLat != null ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                          size: 18,
                          color: detectedLat != null ? const Color(0xFF10B981) : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            detectedLat != null
                                ? (lang.isTamil ? 'ஜிபிஎஸ் ஒருங்கிணைப்பு இணைக்கப்பட்டுள்ளது' : 'Live GPS Pin Coordinates Linked')
                                : (lang.isTamil ? 'வரைபடத்தில் துல்லியமாக தேர்வு செய்யவும்' : 'Pick on Map for exact GPS accuracy'),
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: detectedLat != null ? const Color(0xFF10B981) : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final house = houseNoCtrl.text.trim();
                        final street = streetCtrl.text.trim();
                        final landm = landmarkCtrl.text.trim();

                        if (house.isEmpty) {
                          HapticFeedback.vibrate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lang.isTamil ? 'தயவுசெய்து வீட்டு எண்ணை உள்ளிடவும்' : 'Please enter House / Flat Number',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        if (street.isEmpty) {
                          HapticFeedback.vibrate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lang.isTamil ? 'தெரு / கட்டிடம் பெயரை உள்ளிடவும்' : 'Please enter Street / Building Name',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final fullFormatted = '$house, $street${landm.isNotEmpty ? ', Near $landm' : ''}';
                        final auth = Provider.of<AuthProvider>(context, listen: false);

                        if (existing == null) {
                          auth.addAddress(
                            UserAddress(
                              id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                              label: selectedCategory,
                              address: fullFormatted,
                              lat: detectedLat,
                              lng: detectedLng,
                            ),
                          );
                        } else {
                          auth.updateAddress(
                            existing.id,
                            UserAddress(
                              id: existing.id,
                              label: selectedCategory,
                              address: fullFormatted,
                              lat: detectedLat ?? existing.lat,
                              lng: detectedLng ?? existing.lng,
                            ),
                          );
                        }

                        HapticFeedback.mediumImpact();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        existing == null
                            ? (lang.isTamil ? 'முகவரியைச் சேமி & தேர்வு செய்' : 'Save & Deliver Here')
                            : (lang.isTamil ? 'முகவரியைப் புதுப்பி' : 'Update Address'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSheetInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeProvider theme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600, color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: theme.textSecondary.withValues(alpha: 0.6)),
            prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 19),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.borderCol)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.borderCol)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8)),
          ),
        ),
      ],
    );
  }
}
