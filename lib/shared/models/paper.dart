class Hashtag {
  final int id;
  final String name;

  Hashtag({required this.id, required this.name});

  factory Hashtag.fromJson(Map<String, dynamic> json) {
    return Hashtag(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class Paper {
  final int id;
  final String title;
  final String? summary;
  final String? content;
  final int? userId;
  final int? groupId; // 추가
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Hashtag> hashtags;

  Paper({
    required this.id,
    required this.title,
    this.summary,
    this.content,
    this.userId,
    this.groupId, // 추가
    required this.createdAt,
    required this.updatedAt,
    this.hashtags = const [],
  });

  factory Paper.fromJson(Map<String, dynamic> json) {
    try {
      return Paper(
        id: json['id'] as int,
        title: json['title'] as String,
        summary: json['summary'] as String?,
        content: json['content'] as String?,
        userId: json['user_id'] as int?,
        groupId: json['group_id'] as int?, // 추가
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        hashtags: (json['hashtags'] as List<dynamic>?)
                ?.map((tag) => Hashtag.fromJson(tag as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e) {
      print('Error parsing Paper from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      if (userId != null) 'user_id': userId,
      if (groupId != null) 'group_id': groupId, // 추가
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'hashtags':
          hashtags.map((tag) => {'id': tag.id, 'name': tag.name}).toList(),
    };
  }
}
