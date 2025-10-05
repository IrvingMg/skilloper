import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/questionnaire.dart';

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


  Future<List<QuestionnaireSummary>> getQuestionnaireSummaries() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/questionnaires/summaries'),
      ).timeout(timeout);

      _handleHttpResponse(response, 'load questionnaire summaries');

      final List<dynamic> data = json.decode(response.body);
      return data
          .map((json) => QuestionnaireSummary.fromJson(json as Map<String, dynamic>))
          .toList();
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

}