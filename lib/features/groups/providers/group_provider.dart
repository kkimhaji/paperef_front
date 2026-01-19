import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/services/api_service.dart';
import '../../../shared/models/group.dart';
import '../../../core/constants/api_constants.dart';

class GroupProvider with ChangeNotifier {
  final ApiService _apiService;

  List<Group> _groups = [];
  List<Group> _groupTree = [];
  List<Map<String, dynamic>> _breadcrumbs = [];
  bool _isLoading = false;
  String? _error;
  int? _selectedGroupId;
  int? _currentParentId;

  List<Group> get groups => _groups;
  List<Group> get groupTree => _groupTree;
  List<Map<String, dynamic>> get breadcrumbs => _breadcrumbs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedGroupId => _selectedGroupId;
  int? get currentParentId => _currentParentId;

  GroupProvider(this._apiService);

  // 그룹 목록 조회 (특정 레벨)
  Future<void> fetchGroups({int? parentId}) async {
    _isLoading = true;
    _error = null;
    _currentParentId = parentId;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (parentId != null) {
        queryParams['parent_id'] = parentId.toString();
      }

      final response = await _apiService.get(
        ApiConstants.groups,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      print('Groups response status: ${response.statusCode}');
      print('Groups response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _groups = data
            .map((item) => Group.fromJson(item as Map<String, dynamic>))
            .toList();
        _error = null;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchGroups(parentId: parentId);
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

  // 전체 트리 구조 조회
  Future<void> fetchGroupTree() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.groupsTree);

      print('Group tree response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _groupTree = data
            .map((item) => Group.fromJson(item as Map<String, dynamic>))
            .toList();
        _error = null;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          await fetchGroupTree();
          return;
        }
      }
    } catch (e) {
      print('Error in fetchGroupTree: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // 그룹 경로(breadcrumb) 조회
  Future<void> fetchGroupPath(int groupId) async {
    try {
      final response = await _apiService.get(ApiConstants.groupPath(groupId));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _breadcrumbs = data
            .map((item) => {
                  'id': item['id'] as int,
                  'name': item['name'] as String,
                })
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error in fetchGroupPath: $e');
    }
  }

  // 그룹 선택
  void selectGroup(int? groupId) {
    _selectedGroupId = groupId;
    if (groupId != null) {
      fetchGroupPath(groupId);
    } else {
      _breadcrumbs = [];
    }
    notifyListeners();
  }

  // 부모 그룹으로 이동
  void navigateToParent(int? parentId) {
    _currentParentId = parentId;
    fetchGroups(parentId: parentId);
  }

  // 그룹 생성
  Future<bool> createGroup({
    required String name,
    String? description,
    int? parentId,
  }) async {
    try {
      print('Creating group with name: $name, parentId: $parentId');

      final response = await _apiService.post(
        ApiConstants.groups,
        {
          'name': name,
          'description': description,
          'parent_id': parentId,
        },
        includeAuth: true,
      );

      print('Create group response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        await fetchGroups(parentId: _currentParentId);
        await fetchGroupTree();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await createGroup(
              name: name, description: description, parentId: parentId);
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
    int? parentId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (parentId != null) body['parent_id'] = parentId;

      final response = await _apiService.put(
        ApiConstants.groupDetail(id),
        body,
      );

      if (response.statusCode == 200) {
        await fetchGroups(parentId: _currentParentId);
        await fetchGroupTree();
        return true;
      } else if (response.statusCode == 401) {
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await updateGroup(
              id: id, name: name, description: description, parentId: parentId);
        }
      } else {
        final data = jsonDecode(response.body);
        _error = data['detail'] ?? 'Failed to update group';
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
        await fetchGroups(parentId: _currentParentId);
        await fetchGroupTree();
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

  // 플랫한 그룹 리스트 가져오기 (드롭다운용)
  List<Group> getFlatGroupList() {
    List<Group> flatList = [];

    void addGroupsRecursively(List<Group> groups, int depth) {
      for (var group in groups) {
        flatList.add(group);
        if (group.children != null && group.children!.isNotEmpty) {
          addGroupsRecursively(group.children!, depth + 1);
        }
      }
    }

    addGroupsRecursively(_groupTree, 0);
    return flatList;
  }

  // 그룹의 깊이 계산 (들여쓰기용)
  int getGroupDepth(int groupId, [List<Group>? groups, int depth = 0]) {
    groups ??= _groupTree;

    for (var group in groups) {
      if (group.id == groupId) {
        return depth;
      }
      if (group.children != null && group.children!.isNotEmpty) {
        final childDepth = getGroupDepth(groupId, group.children, depth + 1);
        if (childDepth > -1) return childDepth;
      }
    }
    return -1;
  }
}
