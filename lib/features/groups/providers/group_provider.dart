import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/services/api_service.dart';
import '../../../shared/models/group.dart';
import '../../../core/constants/api_constants.dart';

class GroupProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Group> _groups = [];
  bool _isLoading = false;
  String? _error;
  int? _selectedGroupId;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedGroupId => _selectedGroupId;

  GroupProvider(this._apiService);

  // 그룹 목록 조회
  Future<void> fetchGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.groups);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _groups = data
            .map((item) => Group.fromJson(item as Map<String, dynamic>))
            .toList();
        _error = null;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchGroups();
          return;
        } else {
          _error = 'Session expired. Please login again.';
        }
      } else {
        _error = 'Failed to load groups: ${response.statusCode}';
      }
    } catch (e) {
      print('Error in fetchGroups: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // 그룹 선택
  void selectGroup(int? groupId) {
    _selectedGroupId = groupId;
    notifyListeners();
  }

  // 그룹 생성
  Future<bool> createGroup({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.groups,
        {
          'name': name,
          'description': description,
        },
        includeAuth: true,
      );

      if (response.statusCode == 201) {
        await fetchGroups();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await createGroup(name: name, description: description);
        }
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to create group';
        print('Create group failed: $_error');
      }
    } catch (e) {
      print('Error in createGroup: $e');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  // 그룹 수정
  Future<bool> updateGroup({
    required int id,
    String? name,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;

      final response = await _apiService.put(
        ApiConstants.groupDetail(id),
        body,
      );

      if (response.statusCode == 200) {
        await fetchGroups();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await updateGroup(
              id: id, name: name, description: description);
        }
      }
    } catch (e) {
      print('Error in updateGroup: $e');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  // 그룹 삭제
  Future<bool> deleteGroup(int id) async {
    try {
      final response = await _apiService.delete(ApiConstants.groupDetail(id));

      if (response.statusCode == 204) {
        if (_selectedGroupId == id) {
          _selectedGroupId = null;
        }
        await fetchGroups();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await deleteGroup(id);
        }
      }
    } catch (e) {
      print('Error in deleteGroup: $e');
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }
}
