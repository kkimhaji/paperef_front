class Hashtag {
  final int id;
  final String name;

  const Hashtag({required this.id, required this.name});

  factory Hashtag.fromJson(Map<String, dynamic> json) => Hashtag(
        id: json['id'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Ref {
  final int id;
  final String title;
  final List<String> summaries;
  final String? content;
  final String? groupName;
  final int? userId;
  final int? groupId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Hashtag> hashtags;

  const Ref({
    required this.id,
    required this.title,
    this.summaries = const [],
    this.content,
    this.userId,
    this.groupId,
    this.groupName,
    required this.createdAt,
    required this.updatedAt,
    this.hashtags = const [],
  });

  factory Ref.fromJson(Map<String, dynamic> json) {
    try {
      return Ref(
        id: json['id'] as int,
        title: json['title'] as String,
        summaries: (json['summaries'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        content: json['content'] as String?,
        userId: json['user_id'] as int?,
        groupId: json['group_id'] as int?,
        groupName: json['group_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        hashtags: (json['hashtags'] as List<dynamic>?)
                ?.map((tag) => Hashtag.fromJson(tag as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summaries': summaries,
        'content': content,
        if (userId != null) 'user_id': userId,
        if (groupId != null) 'group_id': groupId,
        if (groupName != null) 'group_name': groupName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'hashtags': hashtags.map((t) => t.toJson()).toList(),
      };
}
