import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:shared_preferences/shared_preferences.dart';
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
    
    if (_token != null) {
      CustomerApiService().setAuthToken(_token!);
    }
    
    notifyListeners();
  }
  
  // Multiple addresses management
  final List<UserAddress> _addresses = [
    UserAddress(id: 'a1', label: 'Home', address: '12, Anna Salai, Chennai - 600002', lat: 13.0827, lng: 80.2707),
    UserAddress(id: 'a2', label: 'Work', address: 'Tidel Park, Tharamani, Chennai - 600113', lat: 12.9894, lng: 80.2483),
  ];
  String _selectedAddressId = 'a1';

  bool get isLoggedIn => _isLoggedIn;
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

  void selectAddress(String id) {
    _selectedAddressId = id;
    notifyListeners();
  }

  void addAddress(UserAddress address) {
    _addresses.add(address);
    notifyListeners();
  }

  void updateAddress(String id, UserAddress newAddress) {
    final idx = _addresses.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _addresses[idx] = newAddress;
      notifyListeners();
    }
  }

  void removeAddress(String id) {
    if (_addresses.length > 1) {
      _addresses.removeWhere((a) => a.id == id);
      if (_selectedAddressId == id) {
        _selectedAddressId = _addresses.first.id;
      }
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
