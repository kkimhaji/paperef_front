import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/models/user.dart';
import '../../../core/constants/api_constants.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider(this._apiService, this._storageService) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storageService.getAccessToken();
    if (token != null) {
      await fetchCurrentUser();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // OAuth2PasswordRequestForm 형식으로 전송
      final response = await _apiService.postFormUrlEncoded(
        ApiConstants.login,
        {
          'username': username,
          'password': password,
          'grant_type': 'password',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storageService.saveAccessToken(data['access_token']);
        await _storageService.saveRefreshToken(data['refresh_token']);
        await fetchCurrentUser();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.register,
        {
          'email': email,
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        // 회원가입 성공 후 자동 로그인
        return await login(email, password);
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCurrentUser() async {
    try {
      final response = await _apiService.get(ApiConstants.me);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = User.fromJson(data);
        notifyListeners();
      } else if (response.statusCode == 401) {
        // Access Token 만료 시 Refresh Token으로 갱신 시도
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchCurrentUser();
        } else {
          await logout();
        }
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storageService.getRefreshToken();

    if (refreshToken != null) {
      try {
        await _apiService.post(
          ApiConstants.logout,
          {'refresh_token': refreshToken},
          includeAuth: true,
        );
      } catch (e) {
        // 로그아웃 API 실패해도 로컬 토큰은 삭제
      }
    }

    await _storageService.deleteTokens();
    _user = null;
    notifyListeners();
  }
}
