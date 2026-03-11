import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/models/ref.dart';
import '../../../shared/services/api_service.dart';

class RefProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Ref> _refs = [];
  List<String> _hashtags = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedHashtag;
  String? _searchQuery;
  bool _includeSubgroups = true;

  RefProvider(this._apiService);

  List<Ref> get refs => _refs;
  List<String> get hashtags => _hashtags;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedHashtag => _selectedHashtag;
  String? get searchQuery => _searchQuery;
  bool get includeSubgroups => _includeSubgroups;

  void toggleIncludeSubgroups() {
    _includeSubgroups = !_includeSubgroups;
    notifyListeners();
  }

  Future<void> fetchRefs({
    int skip = 0,
    int limit = 100,
    String? hashtag,
    int? groupId,
    String? search,
    bool? includeSubgroups,
  }) async {
    _isLoading = true;
    _error = null;
    _selectedHashtag = hashtag;
    _searchQuery = search;
    if (includeSubgroups != null) _includeSubgroups = includeSubgroups;
    notifyListeners();

    try {
      final queryParams = {
        'skip': skip.toString(),
        'limit': limit.toString(),
        'include_subgroups': _includeSubgroups.toString(),
        if (hashtag != null) 'hashtag': hashtag,
        if (groupId != null) 'group_id': groupId.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

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
          _isLoading = false;
          await fetchRefs(
            skip: skip,
            limit: limit,
            hashtag: hashtag,
            groupId: groupId,
            search: search,
            includeSubgroups: includeSubgroups,
          );
          return;
        } else {
          _error = "Session expired. Please login again.";
        }
      } else {
        _error = "Failed to load refs: ${response.statusCode}";
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
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
      final body = <String, dynamic>{
        'title': title,
        'summaries': summaries ?? [],
        'content': content,
        'group_id': groupId,
        'hashtags': hashtags ?? [],
      };

      final response =
          await _apiService.post(ApiConstants.refs, body, includeAuth: true);

      if (response.statusCode == 201) {
        await Future.wait([fetchRefs(), fetchHashtags()]);
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
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to create ref';
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
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (summaries != null) body['summaries'] = summaries; // [] = clear all
      if (content != null) body['content'] = content;
      if (groupId != null) body['group_id'] = groupId;
      if (hashtags != null) body['hashtags'] = hashtags;

      final response = await _apiService.put(ApiConstants.refDetail(id), body);

      if (response.statusCode == 200) {
        await Future.wait([fetchRefs(), fetchHashtags()]);
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
        await Future.wait([fetchRefs(), fetchHashtags()]);
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
        final List<dynamic> data = jsonDecode(response.body);
        _hashtags = data.map((item) => item.toString()).toList();
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
    fetchRefs(hashtag: _selectedHashtag);
  }
}
