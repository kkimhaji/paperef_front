class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://localhost:8000';

  // Auth endpoints
  static const String login = '/auth/token';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Ref endpoints
  static const String refs = '/refs/';
  static String refDetail(int id) => '/refs/$id';

  // Hashtag endpoints
  static const String hashtags = '/hashtags/';

  // Group endpoints
  static const String groups = '/groups/';
  static const String groupsTree = '/groups/tree';
  static String groupDetail(int id) => '/groups/$id';
  static String groupPath(int id) => '/groups/$id/path';
  static String groupRefCount(int id) => '/groups/$id/ref-count';

  static const String userStats = '/auth/me/stats';
  static const String changePassword = '/auth/change-password';
  static const String deleteAccount = '/auth/me';
}
