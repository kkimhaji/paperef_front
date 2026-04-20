import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/models/ref.dart';
import '../../../core/constants/api_constants.dart';

enum RefSortBy {
  updatedDesc('updated_desc', '최신순 (수정일 포함)'),
  createdDesc('created_desc', '최신순'),
  createdAsc('created_asc', '등록순');

  const RefSortBy(this.value, this.label);
  final String value;
  final String label;
}

class RefProvider extends ChangeNotifier {
  static const int _pageSize = 20;

  final ApiService _apiService;

  List<Ref> _refs = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  List<String> _hashtags = [];
  String? _selectedHashtag;
  String? _searchQuery;
  bool _includeSubgroups = true;
  String? _error;
  RefSortBy _sortBy = RefSortBy.updatedDesc;
  // 현재 필터 상태 보존 (fetchMoreRefs에서 재사용)
  int? _currentGroupId;

  //getters
  List<Ref> get refs => _refs;
  List<String> get hashtags => _hashtags;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get selectedHashtag => _selectedHashtag;
  String? get searchQuery => _searchQuery;
  bool get includeSubgroups => _includeSubgroups;
  RefSortBy get sortBy => _sortBy;
  RefProvider(this._apiService);

  void toggleIncludeSubgroups() {
    _includeSubgroups = !_includeSubgroups;
    notifyListeners();
  }

  void setSortBy(RefSortBy sortBy) {
    if (_sortBy == sortBy) return;
    _sortBy = sortBy;
    fetchRefs(
      hashtag: _selectedHashtag,
      groupId: _currentGroupId,
      search: _searchQuery,
      includeSubgroups: _includeSubgroups,
    );
  }

  /// 첫 페이지 로드 — 필터 변경 시 호출
  Future<void> fetchRefs({
    String? hashtag,
    int? groupId,
    String? search,
    bool? includeSubgroups,
    RefSortBy? sortBy,
  }) async {
    _isLoading = true;
    _error = null;
    _refs = [];
    _nextCursor = null;
    _hasMore = true;
    _selectedHashtag = hashtag;
    _searchQuery = search;
    _currentGroupId = groupId;
    if (includeSubgroups != null) _includeSubgroups = includeSubgroups;
    if (sortBy != null) _sortBy = sortBy;
    notifyListeners();

    await _loadPage(cursor: null);
  }

  /// 다음 페이지 로드 — 스크롤 하단 도달 시 호출
  Future<void> fetchMoreRefs() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;
    _isLoadingMore = true;
    notifyListeners();
    await _loadPage(cursor: _nextCursor);
  }

  Future<void> _loadPage({required String? cursor}) async {
    try {
      final queryParams = <String, String>{
        'limit': _pageSize.toString(),
        'include_subgroups': _includeSubgroups.toString(),
        'sort_by': _sortBy.value,
        if (cursor != null) 'cursor': cursor,
        if (_selectedHashtag != null) 'hashtag': _selectedHashtag!,
        if (_currentGroupId != null) 'group_id': _currentGroupId.toString(),
        if (_searchQuery != null && _searchQuery!.isNotEmpty)
          'search': _searchQuery!,
      };

      final response = await _apiService.get(
        ApiConstants.refs,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newItems = (data['items'] as List)
            .map((item) => Ref.fromJson(item as Map<String, dynamic>))
            .toList();

        _refs = [..._refs, ...newItems];
        _hasMore = data['has_more'] as bool;
        _nextCursor = data['next_cursor'] as String?;
        _error = null;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await _loadPage(cursor: cursor);
          return;
        }
        _error = 'Session expired. Please login again.';
      } else {
        _error = 'Failed to load refs: ${response.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<Ref?> fetchRef(int id) async {
    try {
      final response = await _apiService.get(ApiConstants.refDetail(id));
      if (response.statusCode == 200) {
        return Ref.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) return await fetchRef(id);
      }
    } catch (e) {
      debugPrint('Error in fetchRef: $e');
    }
    return null;
  }

  Future<bool> createRef({
    required String title,
    List<String>? summaries,
    String? content,
    int? groupId,
    List<String>? hashtags,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.refs,
        {
          'title': title,
          'summaries': summaries ?? [],
          'content': content,
          'group_id': groupId,
          'hashtags': hashtags ?? [],
        },
        includeAuth: true,
      );

      if (response.statusCode == 201) {
        await Future.wait(
            [fetchRefs(groupId: _currentGroupId), fetchHashtags()]);
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await createRef(
            title: title,
            summaries: summaries,
            content: content,
            groupId: groupId,
            hashtags: hashtags,
          );
        }
      } else {
        _error =
            (jsonDecode(response.body))['detail'] ?? 'Failed to create ref';
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<bool> updateRef({
    required int id,
    String? title,
    List<String>? summaries,
    String? content,
    int? groupId,
    List<String>? hashtags,
  }) async {
    try {
      final body = <String, dynamic>{
        if (title != null) 'title': title,
        if (summaries != null) 'summaries': summaries,
        if (content != null) 'content': content,
        if (groupId != null) 'group_id': groupId,
        if (hashtags != null) 'hashtags': hashtags,
      };

      final response = await _apiService.put(ApiConstants.refDetail(id), body);

      if (response.statusCode == 200) {
        await Future.wait(
            [fetchRefs(groupId: _currentGroupId), fetchHashtags()]);
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await updateRef(
            id: id,
            title: title,
            summaries: summaries,
            content: content,
            groupId: groupId,
            hashtags: hashtags,
          );
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<bool> deleteRef(int id) async {
    try {
      final response = await _apiService.delete(ApiConstants.refDetail(id));
      if (response.statusCode == 204) {
        await Future.wait(
            [fetchRefs(groupId: _currentGroupId), fetchHashtags()]);
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) return await deleteRef(id);
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<void> fetchHashtags() async {
    try {
      final response = await _apiService.get(ApiConstants.hashtags);
      if (response.statusCode == 200) {
        _hashtags = (jsonDecode(response.body) as List)
            .map((e) => e.toString())
            .toList();
        notifyListeners();
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) await fetchHashtags();
      }
    } catch (e) {
      debugPrint('Error in fetchHashtags: $e');
    }
  }

  void clearFilter() {
    _selectedHashtag = null;
    _searchQuery = null;
    fetchRefs();
  }

  void clearSearch() {
    _searchQuery = null;
    fetchRefs(hashtag: _selectedHashtag, groupId: _currentGroupId);
  }
}
