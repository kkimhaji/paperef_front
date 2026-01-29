import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storageService;

  ApiService(this._storageService);

  // Authorization 헤더 생성
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await _storageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // OAuth2 로그인용 form-urlencoded POST 요청
  Future<http.Response> postFormUrlEncoded(
    String endpoint,
    Map<String, String> body,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    return await http.post(
      url,
      headers: headers,
      body: body,
    );
  }

  // POST 요청
  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool includeAuth = false,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders(includeAuth: includeAuth);

    return await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // GET 요청
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    var url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParameters != null) {
      url = url.replace(queryParameters: queryParameters);
    }

    final headers = await _getHeaders();
    return await http.get(url, headers: headers);
  }

  // PUT 요청
  Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final headers = await _getHeaders();

    return await http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // DELETE 요청
  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    var url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      url = url.replace(queryParameters: queryParameters);
    }
    final headers = await _getHeaders();

    return await http.delete(url, headers: headers);
  }

  // Refresh Token으로 Access Token 갱신
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        print('No refresh token available');
        return false;
      }

      print('Attempting to refresh access token...');

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refresh}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storageService.saveAccessToken(data['access_token']);
        await _storageService.saveRefreshToken(data['refresh_token']);
        print('Access token refreshed successfully');
        return true;
      } else {
        print('Token refresh failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }
}
