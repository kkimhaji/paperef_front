class ApiConstants {
  static const String baseUrl = 'http://localhost:8000';
  
  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/token';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  
  // Paper endpoints
  static const String papers = '/papers';
  static String paperDetail(int id) => '/papers/$id';
  static const String hashtags = '/papers/hashtags/all';
}