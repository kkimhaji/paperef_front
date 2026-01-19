class Group {
  final int id;
  final String name;
  final String? description;
  final int? parentId;
  final int refCount;
  final int childrenCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Group>? children;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.parentId,
    required this.refCount,
    required this.childrenCount,
    required this.createdAt,
    required this.updatedAt,
    this.children,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentId: json['parent_id'] as int?,
      refCount: json['ref_count'] as int,
      childrenCount: json['children_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      children: json['children'] != null
          ? (json['children'] as List)
              .map((child) => Group.fromJson(child as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'parent_id': parentId,
      'ref_count': refCount,
      'children_count': childrenCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (children != null)
        'children': children!.map((c) => c.toJson()).toList(),
    };
  }

  // 깊이 계산 (들여쓰기용)
  int get depth {
    if (parentId == null) return 0;
    // 실제로는 부모를 추적해야 하지만, UI에서 계산
    return 0;
  }
}
