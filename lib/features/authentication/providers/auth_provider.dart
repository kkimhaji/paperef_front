import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/user_stats.dart';
import '../../../core/constants/api_constants.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  AuthProvider(this._apiService, this._storageService) {
    _initializeAuth();
  }
  // 초기화 - 저장된 토큰 확인
  Future<void> _initializeAuth() async {
    try {
      final token = await _storageService.getAccessToken();

      if (token != null && token.isNotEmpty) {
        print('Found existing token, fetching user info...');
        await fetchCurrentUser();
      } else {
        print('No token found, user needs to login');
      }
    } catch (e) {
      print('Error during auth initialization: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // 초기화 완료 대기
  Future<void> waitForInitialization() async {
    if (_isInitialized) return;

    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return !_isInitialized;
    });
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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
        print('Login failed: $_error');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      print('Login error: $_error');
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
        print('Registration failed: $_error');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      print('Registration error: $_error');
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
        _error = null;
        notifyListeners();
      } else if (response.statusCode == 401) {
        print('Access token expired, attempting refresh...');
        // Access Token 만료 시 Refresh Token으로 갱신 시도
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          print('Token refreshed, retrying user fetch...');
          await fetchCurrentUser();
        } else {
          print('Token refresh failed, logging out...');
          await _clearUserData();
        }
      } else {
        print('Failed to fetch user: ${response.statusCode}');
        await _clearUserData();
      }
    } catch (e) {
      print('Error fetching current user: $e');
      _error = e.toString();
      // 네트워크 에러 등에서는 로그아웃하지 않음
    }
  }

  // 사용자 데이터 초기화 (내부 메서드)
  Future<void> _clearUserData() async {
    _user = null;
    _error = null;
    await _storageService.deleteTokens();
    notifyListeners();
  }

  Future<void> logout() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken != null) {
      try {
        print('Logging out...');
        await _apiService.post(
          ApiConstants.logout,
          {'refresh_token': refreshToken},
          includeAuth: true,
        );
      } catch (e) {
        print('Logout API error (ignored): $e');
        // 로그아웃 API 실패해도 로컬 토큰은 삭제
      }
    }
    await _clearUserData();
    print('Logout complete');
  }

  // 비밀번호 재설정 요청
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await _apiService.post(
        '/auth/forgot-password',
        {'email': email},
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to send reset email';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error in requestPasswordReset: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

// 비밀번호 재설정 확인
  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      final response = await _apiService.post(
        '/auth/reset-password',
        {
          'token': token,
          'new_password': newPassword,
        },
        includeAuth: false,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to reset password';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error in resetPassword: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 사용자 통계 조회
  Future<UserStats?> fetchUserStats() async {
    try {
      final response = await _apiService.get(ApiConstants.userStats);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserStats.fromJson(data);
      } else {
        print('Failed to fetch user stats: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user stats: $e');
      return null;
    }
  }

  /// 비밀번호 변경
  Future<bool> changePassword(
    String currentPassword,
    String newPassword, {
    bool logoutOtherDevices = true, // 기본값 true
  }) async {
    _error = null;

    try {
      print('Changing password (logout other devices: $logoutOtherDevices)...');

      // 쿼리 파라미터로 옵션 전달
      final endpoint = logoutOtherDevices
          ? '${ApiConstants.changePassword}?logout_other_devices=true'
          : '${ApiConstants.changePassword}?logout_other_devices=false';

      final response = await _apiService.post(
        endpoint,
        {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        includeAuth: true,
      );

      print('Change password response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Password changed successfully');
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to change password';
        print('Password change failed: $_error');
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error changing password: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 계정 삭제
  Future<bool> deleteAccount(String password) async {
    try {
      final response = await _apiService.delete(
        '${ApiConstants.deleteAccount}?password=${Uri.encodeComponent(password)}',
      );

      if (response.statusCode == 204) {
        // 계정 삭제 성공 시 데이터 정리
        await clearUserData();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to delete account';
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error deleting account: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> clearUserData() async {
    _user = null;
    _error = null;
    await _storageService.deleteTokens();
    notifyListeners();
  }
}
