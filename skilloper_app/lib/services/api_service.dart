import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/questionnaire.dart';
import '../models/attempt.dart';
import '../models/pagination.dart';

/// Custom exception for API-related errors
class ApiException implements Exception {
  final String message;
  
  const ApiException(this.message);
  
  @override
  String toString() => message;
}

class ApiService {
  static const String _defaultBaseUrl = 'http://localhost:8080/api/v1';
  static const Duration _defaultTimeout = Duration(seconds: 30);
  
  final String baseUrl;
  final Duration timeout;
  
  // Singleton pattern with configurable base URL
  static final ApiService _instance = ApiService._internal();
  factory ApiService({String? baseUrl, Duration? timeout}) => _instance;
  ApiService._internal({String? baseUrl, Duration? timeout}) 
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        timeout = timeout ?? _defaultTimeout;

  /// Handles HTTP response and throws appropriate exceptions
  void _handleHttpResponse(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }
    
    String errorMessage = 'Failed to $operation (${response.statusCode})';
    
    // Try to extract error details from response body
    try {
      final Map<String, dynamic> errorData = json.decode(response.body);
      if (errorData.containsKey('error')) {
        errorMessage = errorData['error'] as String;
      }
    } catch (e) {
      // If can't parse JSON, use status code message
      switch (response.statusCode) {
        case 400:
          errorMessage = 'Invalid request for $operation';
          break;
        case 401:
          errorMessage = 'Unauthorized access for $operation';
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


  /// Get paginated questionnaire summaries with search and filter
  Future<PaginatedResponse<QuestionnaireSummary>> getQuestionnaireSummaries({
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

      final uri = Uri.parse('$baseUrl/questionnaires/summaries')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(timeout);

      _handleHttpResponse(response, 'load questionnaire summaries');

      final Map<String, dynamic> body = json.decode(response.body);
      final List<dynamic> dataList = body['data'] ?? [];
      final paginationJson = body['pagination'] as Map<String, dynamic>;

      return PaginatedResponse(
        data: dataList
            .map((json) => QuestionnaireSummary.fromJson(json as Map<String, dynamic>))
            .toList(),
        pagination: PaginationMeta.fromJson(paginationJson),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to connect to API: $e');
    }
  }


  Future<Questionnaire> getQuestionnaire(int id) async {
    if (id <= 0) {
      throw ApiException('Invalid questionnaire ID: $id');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/questionnaires/$id'),
      ).timeout(timeout);

      _handleHttpResponse(response, 'load questionnaire');

      final Map<String, dynamic> data = json.decode(response.body);
      return Questionnaire.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to connect to API: $e');
    }
  }

  Future<ImportResponse?> importQuestionnaire(List<int> fileBytes, String fileName) async {
    if (fileBytes.isEmpty) {
      throw ApiException('File is empty - validation failed');
    }
    
    if (fileName.isEmpty) {
      throw ApiException('File name is required - validation failed');
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/questionnaires/import'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final response = await request.send().timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);
        return ImportResponse.fromJson(data);
      } else {
        // Get error details from response
        final responseBody = await response.stream.bytesToString();
        String errorMessage = 'Upload failed (${response.statusCode})';

        try {
          final Map<String, dynamic> errorData = json.decode(responseBody);
          if (errorData.containsKey('error')) {
            errorMessage = errorData['error'] as String;
          } else {
            // Fallback if no error field
            errorMessage = 'Upload failed (${response.statusCode})';
          }
        } catch (e) {
          // If can't parse JSON, use status code message
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
      throw ApiException('Failed to upload file: $e');
    }
  }

  /// Start a quiz attempt (creates in_progress record)
  Future<QuizAttempt> startAttempt(StartAttemptRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attempts/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      ).timeout(timeout);

      _handleHttpResponse(response, 'start attempt');

      final Map<String, dynamic> data = json.decode(response.body);
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to start attempt: $e');
    }
  }

  /// Complete a quiz attempt with results
  Future<QuizAttempt> completeAttempt(int attemptId, CompleteAttemptRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attempts/$attemptId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      ).timeout(timeout);

      _handleHttpResponse(response, 'complete attempt');

      final Map<String, dynamic> data = json.decode(response.body);
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to complete attempt: $e');
    }
  }

  /// Get paginated quiz history for a device with search and filter
  Future<PaginatedResponse<AttemptSummary>> getHistory(
    String deviceId, {
    int limit = 20,
    int offset = 0,
    String search = '',
    String type = '',
    String sort = '',
  }) async {
    if (deviceId.isEmpty) {
      throw ApiException('Device ID is required');
    }

    try {
      final queryParams = <String, String>{
        'device_id': deviceId,
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

      final response = await http.get(uri).timeout(timeout);

      _handleHttpResponse(response, 'load history');

      final Map<String, dynamic> body = json.decode(response.body);
      final List<dynamic> dataList = body['data'] ?? [];
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
      throw ApiException('Failed to load history: $e');
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
      ).timeout(timeout);

      _handleHttpResponse(response, 'load attempt details');

      final Map<String, dynamic> data = json.decode(response.body);
      return QuizAttempt.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load attempt details: $e');
    }
  }

  /// Validate answer for practice mode (immediate feedback)
  Future<ValidateAnswerResponse> validateAnswer(int questionId, ValidateAnswerRequest request) async {
    if (questionId <= 0) {
      throw ApiException('Invalid question ID: $questionId');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/questions/$questionId/validate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      ).timeout(timeout);

      _handleHttpResponse(response, 'validate answer');

      final Map<String, dynamic> data = json.decode(response.body);
      return ValidateAnswerResponse.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to validate answer: $e');
    }
  }
}