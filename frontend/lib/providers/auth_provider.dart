import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isInitializing = true; // true while doing auto-login check
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/login', {
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('access_token', data['access_token']);
      await prefs.setString('user_data', jsonEncode(data['user']));
      
      _user = User.fromJson(data['user']);
      _isLoading = false;
      notifyListeners();
      return true;
    } on HttpException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
      debugPrint('Login exception: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    try {
      await _apiService.post('/logout', {});
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_data');
    _user = null;
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    _isInitializing = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('access_token')) {
      _isInitializing = false;
      notifyListeners();
      return;
    }

    try {
      // Verify token by getting current user data
      final response = await _apiService.get('/user');
      final userData = jsonDecode(response.body);
      
      _user = User.fromJson(userData);
      await prefs.setString('user_data', jsonEncode(userData));
    } catch (e) {
      // If verification fails (e.g. 401), clear data
      debugPrint('Auto-login failed or token expired: $e');
      await logout();
    }

    _isInitializing = false;
    notifyListeners();
  }
}
