class GroupSummary {
  final int id;
  final String name;
  final int refCount;
  final int? parentId;

  GroupSummary({
    required this.id,
    required this.name,
    required this.refCount,
    this.parentId,
  });

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    return GroupSummary(
      id: json['id'],
      name: json['name'],
      refCount: json['ref_count'],
      parentId: json['parent_id'],
    );
  }
}

class HashtagSummary {
  final String name;
  final int count;

  HashtagSummary({
    required this.name,
    required this.count,
  });

  factory HashtagSummary.fromJson(Map<String, dynamic> json) {
    return HashtagSummary(
      name: json['name'],
      count: json['count'],
    );
  }
}

class UserStats {
  final int totalGroups;
  final int totalRefs;
  final int totalHashtags;
  final List<GroupSummary> groups;
  final List<HashtagSummary> hashtags;

  UserStats({
    required this.totalGroups,
    required this.totalRefs,
    required this.totalHashtags,
    required this.groups,
    required this.hashtags,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalGroups: json['total_groups'],
      totalRefs: json['total_refs'],
      totalHashtags: json['total_hashtags'],
      groups: (json['groups'] as List)
          .map((g) => GroupSummary.fromJson(g))
          .toList(),
      hashtags: (json['hashtags'] as List)
          .map((h) => HashtagSummary.fromJson(h))
          .toList(),
    );
  }
}
