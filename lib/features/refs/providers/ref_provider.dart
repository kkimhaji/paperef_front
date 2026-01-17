import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/services/api_service.dart';
import '../../../shared/models/ref.dart';
import '../../../core/constants/api_constants.dart';

class RefProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Ref> _refs = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedHashtag;
  List<String> _hashtags = [];

  List<Ref> get refs => _refs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedHashtag => _selectedHashtag;
  List<String> get hashtags => _hashtags;

  RefProvider(this._apiService);

  // 레퍼런스 목록 조회
  Future<void> fetchRefs({String? hashtag, int? groupId}) async {
    _isLoading = true;
    _error = null;
    _selectedHashtag = hashtag;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (hashtag != null) queryParams['hashtag'] = hashtag;
      if (groupId != null) queryParams['group_id'] = groupId.toString();

      final response = await _apiService.get(
        ApiConstants.refs,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _refs = data
            .map((item) => Ref.fromJson(item as Map<String, dynamic>))
            .toList();
        _error = null;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchRefs(hashtag: hashtag, groupId: groupId);
          return;
        } else {
          _error = 'Session expired. Please login again.';
        }
      } else {
        _error = 'Failed to load refs: ${response.statusCode}';
      }
    } catch (e) {
      print('Error in fetchRefs: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // 특정 레퍼런스 조회
  Future<Ref?> fetchRef(int id) async {
    try {
      final response = await _apiService.get(ApiConstants.refDetail(id));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Ref.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await fetchRef(id);
        }
      }
    } catch (e) {
      print('Error in fetchRef: $e');
    }
    return null;
  }

  // 레퍼런스 생성
  Future<bool> createRef({
    required String title,
    String? summary,
    String? content,
    int? groupId,
    List<String>? hashtags,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.refs,
        {
          'title': title,
          'summary': summary,
          'content': content,
          'group_id': groupId,
          'hashtags': hashtags ?? [],
        },
        includeAuth: true,
      );

      print('Create ref response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        await fetchRefs();
        await fetchHashtags();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await createRef(
            title: title,
            summary: summary,
            content: content,
            groupId: groupId,
            hashtags: hashtags,
          );
        }
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to create ref';
        print('Create ref failed: $_error');
      }
    } catch (e) {
      print('Error in createRef: $e');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  // 레퍼런스 수정
  Future<bool> updateRef({
    required int id,
    String? title,
    String? summary,
    String? content,
    int? groupId,
    List<String>? hashtags,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (summary != null) body['summary'] = summary;
      if (content != null) body['content'] = content;
      if (groupId != null) body['group_id'] = groupId;
      if (hashtags != null) body['hashtags'] = hashtags;

      final response = await _apiService.put(
        ApiConstants.refDetail(id),
        body,
      );

      if (response.statusCode == 200) {
        await fetchRefs();
        await fetchHashtags();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await updateRef(
            id: id,
            title: title,
            summary: summary,
            content: content,
            groupId: groupId,
            hashtags: hashtags,
          );
        }
      }
    } catch (e) {
      print('Error in updateRef: $e');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  // 레퍼런스 삭제
  Future<bool> deleteRef(int id) async {
    try {
      final response = await _apiService.delete(ApiConstants.refDetail(id));

      if (response.statusCode == 204) {
        await fetchRefs();
        await fetchHashtags();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await deleteRef(id);
        }
      }
    } catch (e) {
      print('Error in deleteRef: $e');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  // 해시태그 목록 조회
  Future<void> fetchHashtags() async {
    try {
      final response = await _apiService.get(ApiConstants.hashtags);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _hashtags = data.map((item) => item.toString()).toList();
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchHashtags();
        }
      }
    } catch (e) {
      print('Error in fetchHashtags: $e');
    }
  }

  // 필터 초기화
  void clearFilter() {
    _selectedHashtag = null;
    fetchRefs();
  }
}
