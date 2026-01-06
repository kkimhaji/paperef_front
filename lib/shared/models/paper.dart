class Hashtag {
  final int id;
  final String name;

  Hashtag({required this.id, required this.name});

  factory Hashtag.fromJson(Map<String, dynamic> json) {
    return Hashtag(
      id: json['id'],
      name: json['name'],
    );
  }
}

class Paper {
  final int id;
  final String title;
  final String? summary;
  final String? content;
  final int userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Hashtag> hashtags;

  Paper({
    required this.id,
    required this.title,
    this.summary,
    this.content,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.hashtags = const [],
  });

  factory Paper.fromJson(Map<String, dynamic> json) {
    return Paper(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      content: json['content'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      hashtags: (json['hashtags'] as List)
          .map((tag) => Hashtag.fromJson(tag))
          .toList(),
    );
  }
}