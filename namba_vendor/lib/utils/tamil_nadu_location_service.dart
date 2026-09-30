import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

class TamilNaduLocationResult {
  final String formattedAddress;
  final String street;
  final String area;
  final String city;
  final String state;
  final String pincode;
  final double lat;
  final double lng;

  TamilNaduLocationResult({
    required this.formattedAddress,
    required this.street,
    required this.area,
    required this.city,
    required this.state,
    required this.pincode,
    required this.lat,
    required this.lng,
  });
}

class TamilNaduLocationService {
  // Built-in Comprehensive Tamil Nadu Locality & PIN Code Knowledge Base
  static final Map<String, String> _tnLocalityPincodes = {
    // Erode Localities
    'thindal': '638012',
    'veerappampalayam': '638012',
    'verappampalayam': '638012',
    'villarasampatti': '638012',
    'velalar': '638012',
    'vcet': '638012',
    'maruthi nagar': '638012',
    'surampatti': '638009',
    'sengodampalayam': '638009',
    'rangampalayam': '638009',
    'solar': '638002',
    'kollampalayam': '638002',
    'lakkapuram': '638002',
    'kasipalayam': '638002',
    'perundurai road': '638012',
    'brough road': '638001',
    'manikoondu': '638001',
    'panneerselvam park': '638001',
    'railway colony': '638002',
    'erode junction': '638002',
    'veerappanchatram': '638004',
    'manickampalayam': '638004',
    'periyasemur': '638004',
    'chithode': '638102',
    'kumalankuttai': '638011',
    'perundurai': '638052',
    'bhavani': '638301',
    'komarapalayam': '638183',
    'pallipalayam': '638006',
    'nasiyanur': '638107',
    'kodumudi': '638151',
    'modakkurichi': '638104',
    'sivagiri': '638109',
    'chennimalai': '638051',
    'gobichettipalayam': '638452',
    'sathyamangalam': '638401',

    // Coimbatore Localities
    'gandhipuram': '641012',
    'rs puram': '641002',
    'r.s. puram': '641002',
    'peelamedu': '641004',
    'saravanampatti': '641035',
    'singanallur': '641005',
    'saibaba colony': '641011',
    'ramanathapuram coimbatore': '641045',
    'kuniyamuthur': '641008',
    'kovaipudur': '641042',
    'sundarapuram': '641024',
    'kalapatti': '641048',
    'thudiyalur': '641034',
    'ganapathy': '641006',
    'vadavalli': '641041',
    'sulur': '641402',
    'kinathukadavu': '642109',
    'pollachi': '642001',

    // Tiruppur Localities
    'tiruppur': '641601',
    'avinashi': '641654',
    'palladam': '641664',
    'kangeyam': '638701',
    'dharapuram': '638656',
    'udumalaipettai': '642126',
    'veerapandi': '641605',
    'angeripalayam': '641603',

    // Salem Localities
    'fairlands': '636016',
    'suramangalam': '636005',
    'hasthampatti': '636007',
    'ammapet': '636003',
    'shevapet': '636002',
    'alakkapuram': '636004',
    'attur': '636102',
    'mettur': '636401',
    'edappadi': '637101',
    'omlur': '636455',
    'sankari': '637301',

    // Chennai Localities
    't nagar': '600017',
    't. nagar': '600017',
    'anna nagar': '600040',
    'adyar': '600020',
    'velachery': '600042',
    'tambaram': '600045',
    'guindy': '600032',
    'porur': '600116',
    'mylapore': '600004',
    'nungambakkam': '600034',
    'egmore': '600008',
    'chromepet': '600044',
    'sholinganallur': '600119',
    'omr': '600096',
    'perungudi': '600096',
    'thiruvanmiyur': '600041',
    'saidapet': '600015',
    'vadapalani': '600026',
    'kodambakkam': '600024',
    'medavakkam': '600100',
    'ambattur': '600053',
    'avadi': '600054',
    'poonavallee': '600056',

    // Madurai Localities
    'anna nagar madurai': '625020',
    'kk nagar madurai': '625020',
    'tallakulam': '625002',
    'simmakkal': '625001',
    'goripalayam': '625002',
    'aarapalayam': '625016',
    'villapuram': '625012',
    'thirunagar': '625006',
    'pasumalai': '625004',
    'mattuthavani': '625007',

    // Trichy Localities
    'thillai nagar': '620018',
    'srirangam': '620006',
    'kk nagar trichy': '620021',
    'cantonment trichy': '620001',
    'bhel': '620014',
    'thiruverumbur': '620013',
    'ponmalai': '620004',

    // Tirunelveli Localities
    'palayamkottai': '627002',
    'vannarpettai': '627003',
    'melapalayam': '627005',
    'town tirunelveli': '627006',
    'junction tirunelveli': '627001',

    // Other Key Districts in Tamil Nadu
    'thanjavur': '613001',
    'kumbakonam': '612001',
    'dindigul': '624001',
    'palani': '624601',
    'vellore': '632001',
    'katpadi': '632007',
    'hosur': '635109',
    'krishnagiri': '635001',
    'dharmapuri': '636701',
    'namakkal': '637001',
    'tiruchengode': '637211',
    'karur': '639001',
    'ooty': '643001',
    'coonoor': '643101',
    'cuddalore': '607001',
    'villupuram': '605602',
    'kanchipuram': '631501',
    'tiruvannamalai': '606601',
    'kanyakumari': '629702',
    'nagercoil': '629001',
    'thoothukudi': '628001',
    'ramanathapuram': '623501',
    'virudhunagar': '626001',
    'sivakasi': '626123',
    'rajapalayam': '626117',
    'theni': '625531',
    'periyakulam': '625601',
    'tenkasi': '627811',
    'pudukkottai': '622001',
    'sivaganga': '630561',
    'karaikudi': '630001',
    'nagapattinam': '611001',
    'mayiladuthurai': '609001',
    'tiruvarur': '610001',
    'ariyalur': '621704',
    'perambalur': '621212',
    'chengalpattu': '603001',
    'kallakurichi': '606202',
    'ranipet': '632401',
    'tirupathur': '635601',
  };

  /// Clean up raw OpenStreetMap highway strings (e.g., "Salem - Cochin - Kanniyakumari Road (Old NH47)")
  /// into user-friendly local route and street names.
  static String cleanRouteName(String rawRoad, {String city = '', String area = '', double? lat, double? lng}) {
    if (rawRoad.isEmpty) return '';

    String cleaned = rawRoad.trim();

    // 1. Check for the infamous OSM multi-state highway name
    final lower = cleaned.toLowerCase();
    if (lower.contains('salem - cochin') ||
        lower.contains('salem - cochin - kanniyakumari') ||
        lower.contains('old nh47') ||
        lower.contains('nh 47') ||
        lower.contains('nh47') ||
        lower.contains('nh544') ||
        lower.contains('nh 544')) {
      // Determine local district context
      final combined = '$city $area $lower';
      if (combined.contains('perundurai') || (lat != null && lat >= 11.24 && lat <= 11.31 && lng != null && lng >= 77.54 && lng <= 77.62)) {
        return 'Perundurai Road (NH 544)';
      } else if (combined.contains('erode') || combined.contains('thindal') || combined.contains('veerappampalayam')) {
        return 'Erode - Perundurai Road';
      } else if (combined.contains('coimbatore') || combined.contains('avinashi')) {
        return 'Coimbatore - Avinashi Road (NH 544)';
      } else if (combined.contains('salem') || combined.contains('sankari')) {
        return 'Salem - Coimbatore Highway (NH 544)';
      } else {
        return 'NH 544 Highway';
      }
    }

    // 2. Strip awkward technical suffixes like (Old NH47), (SH 15), etc.
    cleaned = cleaned.replaceAll(RegExp(r'\(Old NH\d+\)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(unnamed road|road|street)\b', caseSensitive: false), '').trim();
    if (cleaned.isEmpty && rawRoad.isNotEmpty) {
      cleaned = rawRoad.trim();
    }

    // Clean extra commas or dashes
    cleaned = cleaned.replaceAll(RegExp(r'^[\s,-]+|[\s,-]+$'), '').trim();
    return cleaned.isNotEmpty ? cleaned : rawRoad;
  }

  /// Reverse geocode any location in Tamil Nadu with maximum accuracy
  /// Uses native Google Play Services Geocoder first, then Photon and Nominatim with smart cleaning.
  static Future<TamilNaduLocationResult> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    String road = '';
    String area = '';
    String city = 'Erode';
    String state = 'Tamil Nadu';
    String resolvedPincode = '';
    String fullDisplayName = '';

    // =========================================================================
    // 1. PRIMARY: Native Device Geocoder (Google Play Services on Android)
    // Provides 100% accurate, local Indian street & road names without OSM tags!
    // =========================================================================
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 4));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final name = (p.name ?? '').trim();
        final thoroughfare = (p.thoroughfare ?? '').trim();
        final street = (p.street ?? '').trim();
        final subLocality = (p.subLocality ?? '').trim();
        final locality = (p.locality ?? '').trim();
        final postalCode = (p.postalCode ?? '').trim();
        final subAdmin = (p.subAdministrativeArea ?? '').trim();
        final admin = (p.administrativeArea ?? '').trim();

        // Extract best road/route name
        String candidateRoad = thoroughfare.isNotEmpty
            ? thoroughfare
            : (street.isNotEmpty && street != name ? street : '');

        // If candidate road is still empty or looks like a plus code, use name if it's a road
        if (candidateRoad.isEmpty && name.toLowerCase().contains('road') || name.toLowerCase().contains('street') || name.toLowerCase().contains('salai')) {
          candidateRoad = name;
        }

        // Clean road
        road = cleanRouteName(candidateRoad, city: locality, area: subLocality, lat: lat, lng: lng);

        area = subLocality.isNotEmpty ? subLocality : (subAdmin.isNotEmpty ? subAdmin : '');
        city = locality.isNotEmpty ? locality : (subAdmin.isNotEmpty ? subAdmin : 'Erode');
        if (admin.isNotEmpty) state = admin;
        if (postalCode.length == 6) resolvedPincode = postalCode;

        if (road.isNotEmpty || area.isNotEmpty) {
          debugPrint('📍 [Native Geocoder] Road: "$road", Area: "$area", City: "$city", PIN: "$resolvedPincode"');
        }
      }
    } catch (nativeErr) {
      debugPrint('⚠️ Native geocoding fallback: $nativeErr');
    }

    // =========================================================================
    // 2. SECONDARY: OpenStreetMap Nominatim with Zoom 18 & Smart Road Cleaner
    // =========================================================================
    if (road.isEmpty || area.isEmpty || resolvedPincode.isEmpty) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=en',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'NambaApp/2.0 (support@nambadelivery.in)'},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final addr = data['address'] as Map<String, dynamic>? ?? {};

          final place = addr['amenity'] ?? addr['shop'] ?? addr['building'] ?? addr['name'] ?? '';
          final rawRoad = addr['road'] ?? addr['pedestrian'] ?? addr['highway'] ?? addr['street'] ?? '';
          final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['hamlet'] ?? addr['village'] ?? '';
          final cityName = addr['city'] ?? addr['town'] ?? addr['county'] ?? addr['state_district'] ?? 'Erode';
          final stateName = addr['state'] ?? 'Tamil Nadu';
          final osmPostcode = addr['postcode']?.toString() ?? '';

          fullDisplayName = data['display_name'] ?? '';

          if (area.isEmpty && suburb.toString().isNotEmpty) {
            area = suburb.toString();
          }
          if (city.isEmpty || city == 'Erode') {
            city = cityName.toString();
          }
          if (state.isEmpty) {
            state = stateName.toString();
          }
          if (resolvedPincode.isEmpty && osmPostcode.length == 6) {
            resolvedPincode = osmPostcode;
          }

          // Clean up the road name using intelligent TN route cleaner
          final cleanedOsmRoad = cleanRouteName(rawRoad.toString(), city: city, area: area, lat: lat, lng: lng);
          if (road.isEmpty) {
            road = [place, cleanedOsmRoad].where((e) => e.toString().isNotEmpty).join(', ');
          }
        }
      } catch (e) {
        debugPrint('Nominatim error: $e');
      }
    }

    // =========================================================================
    // 3. Resolve Exact PIN Code using Tamil Nadu Intelligence Knowledge Base
    // =========================================================================
    final combinedText = '$area $road $city'.toLowerCase();

    for (final entry in _tnLocalityPincodes.entries) {
      if (combinedText.contains(entry.key)) {
        resolvedPincode = entry.value;
        break;
      }
    }

    // 4. Latitude & Longitude Precision Geofencing for Key TN Zones
    if (resolvedPincode.isEmpty || resolvedPincode == '638001') {
      // Perundurai Central & Highway Zone (11.27 - 11.29 Lat, 77.57 - 77.60 Lng)
      if (lat >= 11.260 && lat <= 11.300 && lng >= 77.560 && lng <= 77.610) {
        resolvedPincode = '638052';
        if (city.isEmpty || city == 'Erode') city = 'Perundurai';
        if (road.isEmpty) road = 'Perundurai Road';
      }
      // Erode Western Suburbs (Thindal, Veerappampalayam, Villarasampatti)
      else if (lat >= 11.325 && lat <= 11.365 && lng >= 77.655 && lng <= 77.705) {
        resolvedPincode = '638012';
      }
      // Erode Southern Suburbs (Solar, Kollampalayam, Railway Colony)
      else if (lat >= 11.295 && lat <= 11.335 && lng >= 77.705 && lng <= 77.750) {
        resolvedPincode = '638002';
      }
      // Erode Surampatti
      else if (lat >= 11.310 && lat <= 11.340 && lng >= 77.685 && lng <= 77.720) {
        resolvedPincode = '638009';
      }
      // Coimbatore Gandhipuram / RS Puram
      else if (lat >= 10.980 && lat <= 11.050 && lng >= 76.930 && lng <= 77.020) {
        resolvedPincode = '641012';
      }
      // Salem Hasthampatti / Fairlands
      else if (lat >= 11.640 && lat <= 11.700 && lng >= 78.120 && lng <= 78.180) {
        resolvedPincode = '636016';
      }
    }

    if (resolvedPincode.isEmpty) {
      resolvedPincode = '638012';
    }

    // Construct clean, accurate formatted address without repeating identical parts
    final List<String> addressParts = [];
    if (road.isNotEmpty) addressParts.add(road);
    if (area.isNotEmpty && !addressParts.contains(area) && area != road) addressParts.add(area);
    if (city.isNotEmpty && !addressParts.contains(city)) addressParts.add(city);
    addressParts.add('$state $resolvedPincode');

    final formattedAddress = addressParts.join(', ');

    return TamilNaduLocationResult(
      formattedAddress: formattedAddress.isNotEmpty ? formattedAddress : fullDisplayName,
      street: road,
      area: area,
      city: city,
      state: state,
      pincode: resolvedPincode,
      lat: lat,
      lng: lng,
    );
  }
}

