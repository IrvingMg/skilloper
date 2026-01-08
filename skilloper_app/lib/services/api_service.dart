import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quiz.dart';
import '../models/attempt.dart';
import '../models/pagination.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Custom exception for API-related errors
class ApiException implements Exception {
  final String message;
  final bool isUnauthorized;

  const ApiException(this.message, {this.isUnauthorized = false});

  @override
  String toString() => message;
}

class ApiService {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const String _viewModeEdit = 'edit';

  final String baseUrl;
  final Duration timeout;
  final AuthService _authService = AuthService();

  static final ApiService _instance = ApiService._internal();
  factory ApiService({String? baseUrl, Duration? timeout}) => _instance;
  ApiService._internal({String? baseUrl, Duration? timeout})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        timeout = timeout ?? _defaultTimeout;

  Map<String, String> get _headers {
    _validateTokenBeforeRequest();
    return _authService.getAuthHeaders();
  }

  void _validateTokenBeforeRequest() {
    if (_authService.token != null && !_authService.isTokenValid) {
      _authService.handleSessionExpired();
      throw const ApiException(
        'Session expired. Please log in again.',
        isUnauthorized: true,
      );
    }
  }

  /// Handles HTTP response and throws appropriate exceptions
  void _handleHttpResponse(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    if (response.statusCode == 401) {
      _authService.handleSessionExpired();
      throw const ApiException(
        'Session expired. Please log in again.',
        isUnauthorized: true,
      );
    }

    String errorMessage = 'Failed to $operation (${response.statusCode})';

    try {
      final Map<String, dynamic> errorData = json.decode(response.body);
      if (errorData.containsKey('error')) {
        errorMessage = errorData['error'] as String;
      }
    } catch (e) {
      switch (response.statusCode) {
        case 400:
          errorMessage = 'Invalid request for $operation';
          break;
        case 403:
          errorMessage = 'Forbidden access for $operation';
          break;
        case 404:
          errorMessage = 'Resource not found for $operation';
          break;
        case 422:
          errorMessage = 'Validation failed for $operation';
          break;
        case 429:
          errorMessage = 'Too many requests. Please try again later.';
          break;
        case 500:
          errorMessage = 'Server error during $operation';
          break;
        case 503:
          errorMessage = 'Service unavailable for $operation';
          break;
        default:
          errorMessage = 'Failed to $operation (${response.statusCode})';
      }
    }

    throw ApiException(errorMessage);
  }

  /// Converts caught exceptions to user-friendly ApiException
  ApiException _handleException(dynamic e, String operation) {
    if (e is TimeoutException) {
      return ApiException('Request timed out - please check your connection and try again');
    }
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable')) {
      return ApiException('Unable to connect to server - please check if the API is running');
    }
    return ApiException('Failed to $operation: $e');
  }

  /// Get paginated quiz summaries with search and filter
  Future<PaginatedResponse<QuizSummary>> getQuizSummaries({
    int limit = 20,
    int offset = 0,
    String search = '',
    String type = '',
    String sort = '',
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      final uri = Uri.parse('$baseUrl/quizzes/summaries')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers).timeout(timeout);

      _handleHttpResponse(response, 'load quiz summaries');

      final Map<String, dynamic> body = json.decode(response.body);
      final dynamic rawData = body['data'];
      if (rawData != null && rawData is! List) {
        throw ApiException('Invalid response format: expected data array');
      }
      final List<dynamic> dataList = (rawData as List?) ?? [];
      final paginationJson = body['pagination'] as Map<String, dynamic>;

      return PaginatedResponse(
        data: dataList
            .map((json) => QuizSummary.fromJson(json as Map<String, dynamic>))
            .toList(),
        pagination: PaginationMeta.fromJson(paginationJson),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'load quiz summaries');
    }
  }


  Future<Quiz> getQuiz(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quizzes/$id'),
        headers: _headers,
      ).timeout(timeout);

      _handleHttpResponse(response, 'load quiz');

      final Map<String, dynamic> data = json.decode(response.body);
      return Quiz.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'load quiz');
    }
  }

  /// Get quiz with correct answers included (for edit mode)
  Future<Quiz> getQuizForEdit(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quizzes/$id?view=$_viewModeEdit'),
        headers: _headers,
      ).timeout(timeout);

      _handleHttpResponse(response, 'load quiz for edit');

      final Map<String, dynamic> data = json.decode(response.body);
      return Quiz.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'load quiz for edit');
    }
  }

  Future<ImportResponse?> importQuiz(
    List<int> fileBytes,
    String fileName, {
    String? title,
    String? description,
    String? type,
    int? maxOptions,
  }) async {
    if (fileBytes.isEmpty) {
      throw ApiException('File is empty - validation failed');
    }

    if (fileName.isEmpty) {
      throw ApiException('File name is required - validation failed');
    }

    try {
      final uri = Uri.parse('$baseUrl/quizzes').replace(
        queryParameters: {
          if (title != null && title.isNotEmpty) 'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          if (type != null && type.isNotEmpty) 'type': type,
          if (maxOptions != null) 'max_options': maxOptions.toString(),
        },
      );

      var request = http.MultipartRequest('POST', uri);

      final authHeaders = _authService.getAuthHeaders();
      if (authHeaders.containsKey('Authorization')) {
        request.headers['Authorization'] = authHeaders['Authorization']!;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final response = await request.send().timeout(timeout);

      if (response.statusCode == 401) {
        _authService.handleSessionExpired();
        throw const ApiException(
          'Session expired. Please log in again.',
          isUnauthorized: true,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);
        return ImportResponse.fromJson(data);
      } else {
        final responseBody = await response.stream.bytesToString();
        String errorMessage = 'Upload failed (${response.statusCode})';

        try {
          final Map<String, dynamic> errorData = json.decode(responseBody);
          if (errorData.containsKey('error')) {
            errorMessage = errorData['error'] as String;
          }
        } catch (e) {
          switch (response.statusCode) {
            case 400:
              errorMessage = 'Invalid file format or content';
              break;
            case 413:
              errorMessage = 'File too large (max 10MB)';
              break;
            case 422:
              errorMessage = 'File validation failed';
              break;
            case 429:
              errorMessage = 'Too many requests. Please try again later.';
              break;
            case 500:
              errorMessage = 'Server error - please try again later';
              break;
            default:
              errorMessage = 'Upload failed (${response.statusCode})';
          }
        }

        throw ApiException(errorMessage);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'upload file');
    }
  }

  Future<QuizAttempt> startAttempt(StartAttemptRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attempts'),
        headers: _headers,
        body: json.encode(request.toJson()),
      ).timeout(timeout);

      _handleHttpResponse(response, 'start attempt');

      final Map<String, dynamic> data = json.decode(response.body);
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'start attempt');
    }
  }

  Future<QuizAttempt> completeAttempt(int attemptId, CompleteAttemptRequest request) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/attempts/$attemptId'),
        headers: _headers,
        body: json.encode({
          'status': 'completed',
          'answers': request.toJson()['answers'],
        }),
      ).timeout(timeout);

      _handleHttpResponse(response, 'complete attempt');

      final Map<String, dynamic> data = json.decode(response.body);
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'complete attempt');
    }
  }

  Future<QuizAttempt> abandonAttempt(int attemptId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/attempts/$attemptId'),
        headers: _headers,
        body: json.encode({'status': 'completed'}),
      ).timeout(timeout);

      _handleHttpResponse(response, 'abandon attempt');

      final Map<String, dynamic> data = json.decode(response.body);
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'abandon attempt');
    }
  }

  /// Get paginated quiz history for the current user
  Future<PaginatedResponse<AttemptSummary>> getHistory({
    int limit = 20,
    int offset = 0,
    String search = '',
    String type = '',
    String sort = '',
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      final uri = Uri.parse('$baseUrl/attempts')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers).timeout(timeout);

      _handleHttpResponse(response, 'load history');

      final Map<String, dynamic> body = json.decode(response.body);
      final dynamic rawData = body['data'];
      if (rawData != null && rawData is! List) {
        throw ApiException('Invalid response format: expected data array');
      }
      final List<dynamic> dataList = (rawData as List?) ?? [];
      final paginationJson = body['pagination'] as Map<String, dynamic>;

      return PaginatedResponse(
        data: dataList
            .map((json) => AttemptSummary.fromJson(json as Map<String, dynamic>))
            .toList(),
        pagination: PaginationMeta.fromJson(paginationJson),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'load history');
    }
  }

  /// Get details of a specific attempt
  Future<QuizAttempt> getAttemptDetails(int attemptId) async {
    if (attemptId <= 0) {
      throw ApiException('Invalid attempt ID: $attemptId');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attempts/$attemptId'),
        headers: _headers,
      ).timeout(timeout);

      _handleHttpResponse(response, 'load attempt details');

      final Map<String, dynamic> data = json.decode(response.body);
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'load attempt details');
    }
  }

  /// Create a new quiz using simplified JSON format
  Future<Map<String, dynamic>> createQuiz(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quizzes'),
        headers: _headers,
        body: json.encode(data),
      ).timeout(timeout);

      _handleHttpResponse(response, 'create quiz');

      return json.decode(response.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'create quiz');
    }
  }

  /// Update an existing quiz
  Future<Map<String, dynamic>> updateQuiz(int id, Map<String, dynamic> data) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/quizzes/$id'),
        headers: _headers,
        body: json.encode(data),
      ).timeout(timeout);

      _handleHttpResponse(response, 'update quiz');

      return json.decode(response.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'update quiz');
    }
  }

  /// Delete a quiz
  Future<void> deleteQuiz(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/quizzes/$id'),
        headers: _headers,
      ).timeout(timeout);

      _handleHttpResponse(response, 'delete quiz');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'delete quiz');
    }
  }

  Future<ValidateAnswerResponse> validateAnswer(int questionId, ValidateAnswerRequest request) async {
    if (questionId <= 0) {
      throw ApiException('Invalid question ID: $questionId');
    }

    try {
      final body = request.toJson();
      body['question_id'] = questionId;

      final response = await http.post(
        Uri.parse('$baseUrl/answers'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(timeout);

      _handleHttpResponse(response, 'validate answer');

      final Map<String, dynamic> data = json.decode(response.body);
      return ValidateAnswerResponse.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _handleException(e, 'validate answer');
    }
  }
}