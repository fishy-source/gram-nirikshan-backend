// Auth Provider - manages login state and user session

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../data/models/models.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _api = ApiService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  Future<void> init() async {
    final userData = await _storage.read(key: AppConstants.userDataKey);
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (userData != null && token != null) {
      _currentUser = UserModel.fromJson(jsonDecode(userData));
      notifyListeners();
      // Refresh user data from server
      try {
        final response = await _api.getMe();
        _currentUser = UserModel.fromJson(response.data);
        await _storage.write(key: AppConstants.userDataKey, value: jsonEncode(response.data));
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<bool> login(String mobile, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.loginWithPassword(mobile, password);
      final data = response.data;

      await _storage.write(key: AppConstants.accessTokenKey, value: data['access_token']);
      await _storage.write(key: AppConstants.refreshTokenKey, value: data['refresh_token']);

      _currentUser = UserModel.fromJson(data['user']);
      await _storage.write(key: AppConstants.userDataKey, value: jsonEncode(data['user']));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.changePassword(oldPassword, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userDataKey);
    _currentUser = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    try {
      final response = (e as dynamic).response;
      if (response?.data is Map) {
        return response.data['detail'] ?? 'An error occurred';
      }
    } catch (_) {}
    return e.toString();
  }
}
