import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false; 
  String _phone = '';
  String _name = '';
  String _email = '';
  String _profileImage = 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=200';
  String? _uid;
  String? _token;
  bool _hasSetLocation = false;
  Future<void>? initFuture;

  AuthProvider() {
    initFuture = _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _phone = prefs.getString('phone') ?? '';
    _name = prefs.getString('name') ?? '';
    _email = prefs.getString('email') ?? '';
    _profileImage = prefs.getString('profileImage') ?? 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=200';
    _uid = prefs.getString('uid');
    _token = prefs.getString('token');
    _hasSetLocation = prefs.getBool('hasSetLocation') ?? false;

    // Load saved addresses if available
    final savedAddrString = prefs.getString('savedAddressesJson');
    if (savedAddrString != null && savedAddrString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedAddrString);
        if (decoded.isNotEmpty) {
          _addresses.clear();
          for (var item in decoded) {
            _addresses.add(UserAddress(
              id: item['id'] ?? 'a1',
              label: item['label'] ?? 'Home',
              address: item['address'] ?? '',
              lat: (item['lat'] as num?)?.toDouble() ?? 11.3410,
              lng: (item['lng'] as num?)?.toDouble() ?? 77.7172,
            ));
          }
        }
      } catch (e) {
        debugPrint('Error loading saved addresses: $e');
      }
    }

    final savedSelectedId = prefs.getString('selectedAddressId');
    if (savedSelectedId != null && _addresses.any((a) => a.id == savedSelectedId)) {
      _selectedAddressId = savedSelectedId;
    } else if (_addresses.isNotEmpty) {
      _selectedAddressId = _addresses.first.id;
    }
    
    if (_token != null) {
      CustomerApiService().setAuthToken(_token!);
    }
    
    notifyListeners();
  }
  
  // Multiple addresses management
  final List<UserAddress> _addresses = [
    UserAddress(id: 'a1', label: 'Home', address: 'Erode Bus Stand, Swastik Roundabout, Erode - 638001', lat: 11.3410, lng: 77.7172),
    UserAddress(id: 'a2', label: 'Work', address: 'Bhavani Road, Periyar Nagar, Erode - 638002', lat: 11.3480, lng: 77.7210),
  ];
  String _selectedAddressId = 'a1';

  bool get isLoggedIn => _isLoggedIn;
  bool get hasSetLocation => _hasSetLocation;
  String get phone => _phone;
  String get name => _name;
  String get email => _email;
  String get profileImage => _profileImage;
  String? get uid => _uid;
  String? get token => _token;
  List<UserAddress> get addresses => _addresses;
  
  // Wallet & Points
  double _walletBalance = 245.00; // Demo balance
  int _rewardPoints = 120; // Demo points
  
  double get walletBalance => _walletBalance;
  int get rewardPoints => _rewardPoints;
 
  void addPoints(double orderTotal) {
    _rewardPoints += (orderTotal / 100).floor();
    notifyListeners();
  }

  void useWallet(double amount) {
    if (_walletBalance >= amount) {
      _walletBalance -= amount;
      notifyListeners();
    }
  }

  void addWalletMoney(double amount) {
    _walletBalance += amount;
    notifyListeners();
  }

  UserAddress get selectedAddress => 
      _addresses.firstWhere((a) => a.id == _selectedAddressId, 
      orElse: () => _addresses.first);

  String get address => selectedAddress.address;
 
  Future<void> login(String phone, {String? name, String? email, String? uid, String? token}) async {
    _isLoggedIn = true;
    _phone = phone;
    if (name != null) _name = name;
    if (email != null) _email = email;
    if (uid != null) _uid = uid;
    if (token != null) {
      _token = token;
      CustomerApiService().setAuthToken(token);
    }
 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('phone', _phone);
    await prefs.setString('name', _name);
    await prefs.setString('email', _email);
    if (_uid != null) await prefs.setString('uid', _uid!);
    if (_token != null) await prefs.setString('token', _token!);
    
    notifyListeners();
  }

  Future<void> updateUid(String newUid) async {
    if (_uid == newUid) return;
    _uid = newUid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', newUid);
    notifyListeners();
  }

  Future<void> setUserData({required String name, required String email, String? profileImage}) async {
    _name = name;
    _email = email;
    if (profileImage != null) _profileImage = profileImage;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _name);
    await prefs.setString('email', _email);
    await prefs.setString('profileImage', _profileImage);
    
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? email, String? phone, String? image}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _name = name;
      await prefs.setString('name', _name);
    }
    if (email != null) {
      _email = email;
      await prefs.setString('email', _email);
    }
    if (phone != null) {
      _phone = phone;
      await prefs.setString('phone', _phone);
    }
    if (image != null) {
      _profileImage = image;
      await prefs.setString('profileImage', _profileImage);
    }
    notifyListeners();
  }

  Future<void> _saveAddressesToPrefs() async {
    _hasSetLocation = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSetLocation', true);
    await prefs.setString('selectedAddressId', _selectedAddressId);
    
    final jsonList = _addresses.map((a) => {
      'id': a.id,
      'label': a.label,
      'address': a.address,
      'lat': a.lat,
      'lng': a.lng,
    }).toList();
    
    await prefs.setString('savedAddressesJson', jsonEncode(jsonList));
  }

  Future<bool> useCurrentGpsLocation() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        await Geolocator.openLocationSettings();
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine || permission == LocationPermission.deniedForever) {
        return false;
      }
      final pos = await Geolocator.getCurrentPosition();
      
      final currentAddr = UserAddress(
        id: 'current_gps',
        label: 'Current Location',
        address: 'Current Location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
        lat: pos.latitude,
        lng: pos.longitude,
      );

      final idx = _addresses.indexWhere((a) => a.id == 'current_gps');
      if (idx != -1) {
        _addresses[idx] = currentAddr;
      } else {
        _addresses.insert(0, currentAddr);
      }
      _selectedAddressId = 'current_gps';
      await _saveAddressesToPrefs();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error getting current GPS location: $e');
      return false;
    }
  }

  void selectAddress(String id) {
    _selectedAddressId = id;
    _saveAddressesToPrefs();
    notifyListeners();
  }

  void addAddress(UserAddress address) {
    _addresses.add(address);
    _selectedAddressId = address.id;
    _saveAddressesToPrefs();
    notifyListeners();
  }

  void updateAddress(String id, UserAddress newAddress) {
    final idx = _addresses.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _addresses[idx] = newAddress;
      _saveAddressesToPrefs();
      notifyListeners();
    }
  }

  void removeAddress(String id) {
    if (_addresses.length > 1) {
      _addresses.removeWhere((a) => a.id == id);
      if (_selectedAddressId == id) {
        _selectedAddressId = _addresses.first.id;
      }
      _saveAddressesToPrefs();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    
    _isLoggedIn = false;
    _phone = '';
    _name = '';
    _email = '';
    _uid = null;
    _walletBalance = 0;
    _rewardPoints = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    notifyListeners();
  }
}
