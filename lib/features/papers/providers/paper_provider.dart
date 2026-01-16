import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/services/api_service.dart';
import '../../../shared/models/paper.dart';
import '../../../core/constants/api_constants.dart';

class PaperProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Paper> _papers = [];
  List<String> _hashtags = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedHashtag;

  List<Paper> get papers => _papers;
  List<String> get hashtags => _hashtags;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedHashtag => _selectedHashtag;

  PaperProvider(this._apiService);

  // 논문 목록 조회
  Future<void> fetchPapers({String? hashtag, int? groupId}) async {
    _isLoading = true;
    _error = null;
    _selectedHashtag = hashtag;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (hashtag != null) queryParams['hashtag'] = hashtag;
      if (groupId != null) queryParams['group_id'] = groupId.toString();

      final response = await _apiService.get(
        ApiConstants.papers,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        _papers = [];
        for (var item in data) {
          try {
            final paper = Paper.fromJson(item as Map<String, dynamic>);
            _papers.add(paper);
          } catch (e) {
            print('Error parsing paper: $e');
            print('Problem item: $item');
          }
        }

        _error = null;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchPapers(hashtag: hashtag);
          return;
        } else {
          _error = 'Session expired. Please login again.';
        }
      } else {
        _error = 'Failed to load papers: ${response.statusCode}';
      }
    } catch (e, stackTrace) {
      print('Error in fetchPapers: $e');
      print('Stack trace: $stackTrace');
      _error = 'Error: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  // 논문 상세 조회
  Future<Paper?> fetchPaper(int id) async {
    try {
      final response = await _apiService.get(ApiConstants.paperDetail(id));

      if (response.statusCode == 200) {
        return Paper.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await fetchPaper(id);
        }
      }
    } catch (e) {
      print('Error in fetchPaper: $e');
      _error = e.toString();
      notifyListeners();
    }
    return null;
  }

  // 논문 생성
  Future<bool> createPaper({
    required String title,
    String? summary,
    String? content,
    int? groupId, // 추가
    List<String>? hashtags,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.papers,
        {
          'title': title,
          'summary': summary,
          'content': content,
          'group_id': groupId, // 추가
          'hashtags': hashtags ?? [],
        },
        includeAuth: true,
      );
      if (response.statusCode == 201) {
        await fetchPapers(hashtag: _selectedHashtag);
        await fetchHashtags();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await createPaper(
            title: title,
            summary: summary,
            content: content,
            hashtags: hashtags,
          );
        }
      } else {
        _error = 'Failed to create paper: ${response.statusCode}';
        print('Create paper failed: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error in createPaper: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  // 논문 수정
  Future<bool> updatePaper({
    required int id,
    String? title,
    String? summary,
    String? content,
    int? groupId, // 추가
    List<String>? hashtags,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (summary != null) body['summary'] = summary;
      if (content != null) body['content'] = content;
      if (groupId != null) body['group_id'] = groupId; // 추가
      if (hashtags != null) body['hashtags'] = hashtags;

      final response = await _apiService.put(
        ApiConstants.paperDetail(id),
        body,
      );

      if (response.statusCode == 200) {
        await fetchPapers(hashtag: _selectedHashtag);
        await fetchHashtags();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await updatePaper(
            id: id,
            title: title,
            summary: summary,
            content: content,
            hashtags: hashtags,
          );
        }
      }
    } catch (e) {
      print('Error in updatePaper: $e');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  // 논문 삭제
  Future<bool> deletePaper(int id) async {
    try {
      final response = await _apiService.delete(ApiConstants.paperDetail(id));

      if (response.statusCode == 204) {
        await fetchPapers(hashtag: _selectedHashtag);
        await fetchHashtags();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await deletePaper(id);
        }
      }
    } catch (e) {
      print('Error in deletePaper: $e');
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
        _hashtags = data.cast<String>();
        notifyListeners();
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchHashtags();
        }
      }
    } catch (e) {
      print('Error in fetchHashtags: $e');
      _error = e.toString();
    }
  }

  // 필터 초기화
  void clearFilter() {
    _selectedHashtag = null;
    fetchPapers();
  }
}
