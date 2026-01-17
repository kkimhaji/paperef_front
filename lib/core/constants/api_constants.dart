class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://localhost:8000';

  // Auth endpoints
  static const String login = '/auth/token';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Ref endpoints
  static const String refs = '/refs';
  static String refDetail(int id) => '/refs/$id';

  // Hashtag endpoints
  static const String hashtags = '/hashtags';

  // Group endpoints
  static const String groups = '/groups';
  static String groupDetail(int id) => '/groups/$id';
}
