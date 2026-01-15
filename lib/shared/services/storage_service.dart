import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  late final FlutterSecureStorage _storage;

  StorageService() {
    // 웹에서는 localStorage 사용
    _storage = FlutterSecureStorage(
      webOptions: WebOptions(
        dbName: 'paperef_db',
        publicKey: 'paperef_public_key',
      ),
    );
  }

  // Access Token 저장
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: 'access_token', value: token);
    } catch (e) {
      print('Error saving access token: $e');
    }
  }

  // Access Token 가져오기
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: 'access_token');
    } catch (e) {
      print('Error reading access token: $e');
      return null;
    }
  }

  // Refresh Token 저장
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: 'refresh_token', value: token);
    } catch (e) {
      print('Error saving refresh token: $e');
    }
  }

  // Refresh Token 가져오기
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: 'refresh_token');
    } catch (e) {
      print('Error reading refresh token: $e');
      return null;
    }
  }

  // 토큰 삭제
  Future<void> deleteTokens() async {
    try {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
    } catch (e) {
      print('Error deleting tokens: $e');
    }
  }

  // 모든 데이터 삭제
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('Error deleting all data: $e');
    }
  }
}
