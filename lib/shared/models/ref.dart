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

class Ref {
  final int id;
  final String title;
  final String? summary;
  final String? content;
  final int? userId;
  final int? groupId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Hashtag> hashtags;

  Ref({
    required this.id,
    required this.title,
    this.summary,
    this.content,
    this.userId,
    this.groupId,
    required this.createdAt,
    required this.updatedAt,
    this.hashtags = const [],
  });

  factory Ref.fromJson(Map<String, dynamic> json) {
    try {
      return Ref(
        id: json['id'] as int,
        title: json['title'] as String,
        summary: json['summary'] as String?,
        content: json['content'] as String?,
        userId: json['user_id'] as int?,
        groupId: json['group_id'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        hashtags: (json['hashtags'] as List<dynamic>?)
                ?.map((tag) => Hashtag.fromJson(tag as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e) {
      print('Error parsing Ref from JSON: $e');
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
      if (groupId != null) 'group_id': groupId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'hashtags':
          hashtags.map((tag) => {'id': tag.id, 'name': tag.name}).toList(),
    };
  }
}
