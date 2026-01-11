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

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String currentUser = '/auth/me';
  static String userPassword(int id) => '/users/$id/password';
  static String userHistory(int id) => '/users/$id/history';
  static String user(int id) => '/users/$id';
}
