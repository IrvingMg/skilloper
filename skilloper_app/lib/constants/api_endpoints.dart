/// API endpoint paths for the Skilloper API
class ApiEndpoints {
  ApiEndpoints._();

  // Quiz endpoints
  static const String quizzes = '/quizzes';
  static const String quizSummaries = '/quizzes/summaries';
  static String quiz(int id) => '/quizzes/$id';

  // Attempt endpoints
  static const String attempts = '/attempts';
  static String attempt(int id) => '/attempts/$id';

  // Answer validation
  static const String answers = '/answers';

  // Session endpoints (auth)
  static const String sessions = '/sessions';
  static const String sessionsRefresh = '/sessions/refresh';

  // User endpoints
  static const String users = '/users';
  static const String usersMe = '/users/me';
  static const String userPassword = '/users/me/password';
  static const String userHistoryClearance = '/users/me/history-clearance';
  static const String userDeletion = '/users/me/deletion';
}
