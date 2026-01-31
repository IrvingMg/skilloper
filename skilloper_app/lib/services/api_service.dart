import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../models/attempt.dart';
import '../models/collection.dart';
import '../models/pagination.dart';
import '../models/quiz.dart';
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
  factory ApiService() => _instance;
  ApiService._internal({String? baseUrl, Duration? timeout})
    : baseUrl = baseUrl ?? ApiConfig.baseUrl,
      timeout = timeout ?? _defaultTimeout;

  Map<String, String> get _headers {
    return _authService.getAuthHeaders();
  }

  /// Executes a GET request with automatic token refresh on 401
  Future<http.Response> _authenticatedGet(Uri url) async {
    var response = await http.get(url, headers: _headers).timeout(timeout);

    if (response.statusCode == 401) {
      if (await _authService.refreshAccessToken()) {
        response = await http.get(url, headers: _headers).timeout(timeout);
      }
    }

    return response;
  }

  /// Executes a POST request with automatic token refresh on 401
  Future<http.Response> _authenticatedPost(Uri url, {Object? body}) async {
    var response = await http
        .post(url, headers: _headers, body: body)
        .timeout(timeout);

    if (response.statusCode == 401) {
      if (await _authService.refreshAccessToken()) {
        response = await http
            .post(url, headers: _headers, body: body)
            .timeout(timeout);
      }
    }

    return response;
  }

  /// Executes a PUT request with automatic token refresh on 401
  Future<http.Response> _authenticatedPut(Uri url, {Object? body}) async {
    var response = await http
        .put(url, headers: _headers, body: body)
        .timeout(timeout);

    if (response.statusCode == 401) {
      if (await _authService.refreshAccessToken()) {
        response = await http
            .put(url, headers: _headers, body: body)
            .timeout(timeout);
      }
    }

    return response;
  }

  /// Executes a PATCH request with automatic token refresh on 401
  Future<http.Response> _authenticatedPatch(Uri url, {Object? body}) async {
    var response = await http
        .patch(url, headers: _headers, body: body)
        .timeout(timeout);

    if (response.statusCode == 401) {
      if (await _authService.refreshAccessToken()) {
        response = await http
            .patch(url, headers: _headers, body: body)
            .timeout(timeout);
      }
    }

    return response;
  }

  /// Executes a DELETE request with automatic token refresh on 401
  Future<http.Response> _authenticatedDelete(Uri url) async {
    var response = await http.delete(url, headers: _headers).timeout(timeout);

    if (response.statusCode == 401) {
      if (await _authService.refreshAccessToken()) {
        response = await http.delete(url, headers: _headers).timeout(timeout);
      }
    }

    return response;
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
      final Map<String, dynamic> errorData =
          json.decode(response.body) as Map<String, dynamic>;
      if (errorData.containsKey('error')) {
        errorMessage = errorData['error'] as String;
      }
    } on Exception catch (_) {
      errorMessage = switch (response.statusCode) {
        400 => 'Invalid request for $operation',
        403 => 'Forbidden access for $operation',
        404 => 'Resource not found for $operation',
        422 => 'Validation failed for $operation',
        429 => 'Too many requests. Please try again later.',
        500 => 'Server error during $operation',
        503 => 'Service unavailable for $operation',
        _ => 'Failed to $operation (${response.statusCode})',
      };
    }

    throw ApiException(errorMessage);
  }

  /// Converts caught exceptions to user-friendly ApiException
  ApiException _handleException(Object e, String operation) {
    if (e is TimeoutException) {
      return const ApiException(
        'Request timed out - please check your connection and try again',
      );
    }
    if (e is SocketException) {
      return const ApiException(
        'Unable to connect to server - please check if the API is running',
      );
    }
    if (e is FormatException || e is TypeError) {
      return ApiException(
        'Invalid response from server while trying to $operation',
      );
    }
    // Fallback for network-related errors that might not be SocketException
    if (e is HttpException) {
      return const ApiException('Network error - please check your connection');
    }
    return ApiException('Failed to $operation - please try again');
  }

  /// Get paginated quiz summaries with search and filter
  Future<PaginatedResponse<QuizSummary>> getQuizSummaries({
    int limit = 20,
    int offset = 0,
    String search = '',
    String type = '',
    String sort = '',
    int? collectionId,
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
      if (collectionId != null) {
        queryParams['collection_id'] = collectionId.toString();
      }

      final uri = Uri.parse(
        '$baseUrl${ApiEndpoints.quizSummaries}',
      ).replace(queryParameters: queryParams);

      final response = await _authenticatedGet(uri);

      _handleHttpResponse(response, 'load quiz summaries');

      final Map<String, dynamic> body =
          json.decode(response.body) as Map<String, dynamic>;
      final dynamic rawData = body['data'];
      if (rawData != null && rawData is! List) {
        throw const ApiException(
          'Invalid response format: expected data array',
        );
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
    } on Exception catch (e) {
      throw _handleException(e, 'load quiz summaries');
    }
  }

  Future<Quiz> getQuiz(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await _authenticatedGet(
        Uri.parse('$baseUrl${ApiEndpoints.quiz(id)}'),
      );

      _handleHttpResponse(response, 'load quiz');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return Quiz.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'load quiz');
    }
  }

  /// Get quiz with correct answers included (for edit mode)
  Future<Quiz> getQuizForEdit(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await _authenticatedGet(
        Uri.parse('$baseUrl${ApiEndpoints.quiz(id)}?view=$_viewModeEdit'),
      );

      _handleHttpResponse(response, 'load quiz for edit');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return Quiz.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'load quiz for edit');
    }
  }

  Future<QuizSummary?> importQuiz(
    List<int> fileBytes,
    String fileName, {
    String? title,
    String? description,
    String? type,
    int? maxOptions,
  }) async {
    if (fileBytes.isEmpty) {
      throw const ApiException('File is empty - validation failed');
    }

    if (fileName.isEmpty) {
      throw const ApiException('File name is required - validation failed');
    }

    try {
      final uri = Uri.parse('$baseUrl${ApiEndpoints.quizzes}').replace(
        queryParameters: {
          if (title != null && title.isNotEmpty) 'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (type != null && type.isNotEmpty) 'type': type,
          if (maxOptions != null) 'max_options': maxOptions.toString(),
        },
      );

      // Helper to create and send the multipart request
      Future<http.StreamedResponse> sendRequest() async {
        final request = http.MultipartRequest('POST', uri);
        final authHeaders = _authService.getAuthHeaders();
        if (authHeaders.containsKey('Authorization')) {
          request.headers['Authorization'] = authHeaders['Authorization']!;
        }
        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
        );
        return request.send().timeout(timeout);
      }

      var response = await sendRequest();

      // Try refresh and retry on 401
      if (response.statusCode == 401) {
        if (await _authService.refreshAccessToken()) {
          response = await sendRequest();
        }
      }

      if (response.statusCode == 401) {
        _authService.handleSessionExpired();
        throw const ApiException(
          'Session expired. Please log in again.',
          isUnauthorized: true,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data =
            json.decode(responseBody) as Map<String, dynamic>;
        return QuizSummary.fromJson(data);
      } else {
        final responseBody = await response.stream.bytesToString();
        String? errorMessage;

        try {
          final Map<String, dynamic> errorData =
              json.decode(responseBody) as Map<String, dynamic>;
          if (errorData.containsKey('error')) {
            errorMessage = errorData['error'] as String;
          }
        } on Exception catch (_) {
          // JSON parsing failed, use status code based message
        }

        errorMessage ??= switch (response.statusCode) {
          400 => 'Invalid file format or content',
          413 => 'File too large (max 10MB)',
          422 => 'File validation failed',
          429 => 'Too many requests. Please try again later.',
          500 => 'Server error - please try again later',
          _ => 'Upload failed (${response.statusCode})',
        };

        throw ApiException(errorMessage);
      }
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'upload file');
    }
  }

  Future<AttemptStartResponse> startAttempt(StartAttemptRequest request) async {
    try {
      final response = await _authenticatedPost(
        Uri.parse('$baseUrl${ApiEndpoints.attempts}'),
        body: json.encode(request.toJson()),
      );

      _handleHttpResponse(response, 'start attempt');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return AttemptStartResponse.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'start attempt');
    }
  }

  Future<QuizAttempt> completeAttempt(
    int attemptId,
    CompleteAttemptRequest request,
  ) async {
    try {
      final response = await _authenticatedPatch(
        Uri.parse('$baseUrl${ApiEndpoints.attempt(attemptId)}'),
        body: json.encode({
          'status': 'completed',
          'answers': request.toJson()['answers'],
        }),
      );

      _handleHttpResponse(response, 'complete attempt');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'complete attempt');
    }
  }

  Future<QuizAttempt> abandonAttempt(int attemptId) async {
    try {
      final response = await _authenticatedPatch(
        Uri.parse('$baseUrl${ApiEndpoints.attempt(attemptId)}'),
        body: json.encode({'status': 'completed'}),
      );

      _handleHttpResponse(response, 'abandon attempt');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
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

      final uri = Uri.parse(
        '$baseUrl${ApiEndpoints.attempts}',
      ).replace(queryParameters: queryParams);

      final response = await _authenticatedGet(uri);

      _handleHttpResponse(response, 'load history');

      final Map<String, dynamic> body =
          json.decode(response.body) as Map<String, dynamic>;
      final dynamic rawData = body['data'];
      if (rawData != null && rawData is! List) {
        throw const ApiException(
          'Invalid response format: expected data array',
        );
      }
      final List<dynamic> dataList = (rawData as List?) ?? [];
      final paginationJson = body['pagination'] as Map<String, dynamic>;

      return PaginatedResponse(
        data: dataList
            .map(
              (json) => AttemptSummary.fromJson(json as Map<String, dynamic>),
            )
            .toList(),
        pagination: PaginationMeta.fromJson(paginationJson),
      );
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'load history');
    }
  }

  /// Get details of a specific attempt
  Future<QuizAttempt> getAttemptDetails(int attemptId) async {
    if (attemptId <= 0) {
      throw ApiException('Invalid attempt ID: $attemptId');
    }

    try {
      final response = await _authenticatedGet(
        Uri.parse('$baseUrl${ApiEndpoints.attempt(attemptId)}'),
      );

      _handleHttpResponse(response, 'load attempt details');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'load attempt details');
    }
  }

  /// Create a new quiz using simplified JSON format
  Future<QuizSummary> createQuiz(Map<String, dynamic> data) async {
    try {
      final response = await _authenticatedPost(
        Uri.parse('$baseUrl${ApiEndpoints.quizzes}'),
        body: json.encode(data),
      );

      _handleHttpResponse(response, 'create quiz');

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      return QuizSummary.fromJson(responseData);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'create quiz');
    }
  }

  /// Update an existing quiz
  Future<QuizSummary> updateQuiz(int id, Map<String, dynamic> data) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await _authenticatedPut(
        Uri.parse('$baseUrl${ApiEndpoints.quiz(id)}'),
        body: json.encode(data),
      );

      _handleHttpResponse(response, 'update quiz');

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      return QuizSummary.fromJson(responseData);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'update quiz');
    }
  }

  /// Delete a quiz
  Future<void> deleteQuiz(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid quiz ID: $id');
    }

    try {
      final response = await _authenticatedDelete(
        Uri.parse('$baseUrl${ApiEndpoints.quiz(id)}'),
      );

      _handleHttpResponse(response, 'delete quiz');
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'delete quiz');
    }
  }

  /// Update quiz collection assignment
  Future<void> setQuizCollection(int quizId, int? collectionId) async {
    if (quizId <= 0) {
      throw ApiException('Invalid quiz ID: $quizId');
    }

    try {
      final response = await _authenticatedPatch(
        Uri.parse('$baseUrl${ApiEndpoints.quizCollection(quizId)}'),
        body: json.encode({'collection_id': collectionId}),
      );

      _handleHttpResponse(response, 'update quiz collection');
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'update quiz collection');
    }
  }

  /// Get paginated collections
  Future<PaginatedResponse<Collection>> getCollections({
    int limit = 20,
    int offset = 0,
    String search = '',
    String sort = '',
    int? parentId,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }
      if (parentId != null) {
        queryParams['parent_id'] = parentId.toString();
      }

      final uri = Uri.parse(
        '$baseUrl${ApiEndpoints.collections}',
      ).replace(queryParameters: queryParams);

      final response = await _authenticatedGet(uri);

      _handleHttpResponse(response, 'load collections');

      final Map<String, dynamic> body =
          json.decode(response.body) as Map<String, dynamic>;
      final dynamic rawData = body['data'];
      if (rawData != null && rawData is! List) {
        throw const ApiException(
          'Invalid response format: expected data array',
        );
      }
      final List<dynamic> dataList = (rawData as List?) ?? [];
      final paginationJson = body['pagination'] as Map<String, dynamic>;

      return PaginatedResponse(
        data: dataList
            .map((json) => Collection.fromJson(json as Map<String, dynamic>))
            .toList(),
        pagination: PaginationMeta.fromJson(paginationJson),
      );
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'load collections');
    }
  }

  /// Get a single collection by ID
  Future<Collection> getCollection(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid collection ID: $id');
    }

    try {
      final response = await _authenticatedGet(
        Uri.parse('$baseUrl${ApiEndpoints.collection(id)}'),
      );

      _handleHttpResponse(response, 'load collection');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return Collection.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'load collection');
    }
  }

  /// Create a new collection
  Future<Collection> createCollection(Map<String, dynamic> data) async {
    try {
      final response = await _authenticatedPost(
        Uri.parse('$baseUrl${ApiEndpoints.collections}'),
        body: json.encode(data),
      );

      _handleHttpResponse(response, 'create collection');

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      return Collection.fromJson(responseData);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'create collection');
    }
  }

  /// Update an existing collection
  Future<Collection> updateCollection(int id, Map<String, dynamic> data) async {
    if (id <= 0) {
      throw ApiException('Invalid collection ID: $id');
    }

    try {
      final response = await _authenticatedPut(
        Uri.parse('$baseUrl${ApiEndpoints.collection(id)}'),
        body: json.encode(data),
      );

      _handleHttpResponse(response, 'update collection');

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      return Collection.fromJson(responseData);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'update collection');
    }
  }

  /// Delete a collection
  Future<void> deleteCollection(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid collection ID: $id');
    }

    try {
      final response = await _authenticatedDelete(
        Uri.parse('$baseUrl${ApiEndpoints.collection(id)}'),
      );

      _handleHttpResponse(response, 'delete collection');
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'delete collection');
    }
  }

  /// Get all collections as a flat list with full paths
  Future<List<FlatCollectionItem>> getCollectionsFlat() async {
    try {
      final response = await _authenticatedGet(
        Uri.parse('$baseUrl${ApiEndpoints.collectionsFlat}'),
      );

      _handleHttpResponse(response, 'load flat collections');

      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      return data
          .map(
            (json) => FlatCollectionItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'load flat collections');
    }
  }

  /// Bulk update quiz collection assignment
  Future<void> bulkSetQuizCollection(
    List<int> quizIds,
    int? collectionId,
  ) async {
    try {
      final response = await _authenticatedPost(
        Uri.parse('$baseUrl${ApiEndpoints.quizzesBulkCollection}'),
        body: json.encode({'quiz_ids': quizIds, 'collection_id': collectionId}),
      );

      _handleHttpResponse(response, 'bulk update quiz collection');
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'bulk update quiz collection');
    }
  }

  /// Bulk delete quizzes
  Future<void> bulkDeleteQuizzes(List<int> quizIds) async {
    try {
      final response = await _authenticatedPost(
        Uri.parse('$baseUrl${ApiEndpoints.quizzesBulkDelete}'),
        body: json.encode({'quiz_ids': quizIds}),
      );

      _handleHttpResponse(response, 'bulk delete quizzes');
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'bulk delete quizzes');
    }
  }

  Future<ValidateAnswerResponse> validateAnswer(
    int questionId,
    ValidateAnswerRequest request,
  ) async {
    if (questionId <= 0) {
      throw ApiException('Invalid question ID: $questionId');
    }

    try {
      final body = request.toJson();
      body['question_id'] = questionId;

      final response = await _authenticatedPost(
        Uri.parse('$baseUrl${ApiEndpoints.answers}'),
        body: json.encode(body),
      );

      _handleHttpResponse(response, 'validate answer');

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      return ValidateAnswerResponse.fromJson(data);
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw _handleException(e, 'validate answer');
    }
  }
}
