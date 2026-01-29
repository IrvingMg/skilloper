/// API endpoint paths for the Skilloper API
class ApiEndpoints {
  ApiEndpoints._();

  // Quiz endpoints
  static const String quizzes = '/quizzes';
  static const String quizSummaries = '/quizzes/summaries';
  static String quiz(int id) => '/quizzes/$id';
  static String quizCollection(int id) => '/quizzes/$id/collection';

  // Collection endpoints
  static const String collections = '/collections';
  static const String collectionsFlat = '/collections/flat';
  static String collection(int id) => '/collections/$id';

  // Bulk operations
  static const String quizzesBulkCollection = '/quizzes/bulk-collection';
  static const String quizzesBulkDelete = '/quizzes/bulk-delete';

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
