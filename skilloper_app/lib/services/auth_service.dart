import 'dart:async';
import 'dart:convert' show base64Url, json, utf8;
import 'dart:ui' show VoidCallback;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class User {
  final int id;
  final String username;
  final bool isAdmin;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    required this.isAdmin,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthService {
  static const String _tokenKey = 'skilloper_auth_token';
  static const String _userKey = 'skilloper_user';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Secure storage for sensitive data
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Synchronization lock for auth operations
  Completer<void>? _operationLock;

  String? _token;
  User? _currentUser;
  VoidCallback? onSessionExpired;

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null && _currentUser != null;

  /// Acquires lock for auth operations to prevent race conditions
  Future<void> _acquireLock() async {
    while (_operationLock != null) {
      await _operationLock!.future;
    }
    _operationLock = Completer<void>();
  }

  /// Releases the operation lock
  void _releaseLock() {
    final lock = _operationLock;
    _operationLock = null;
    lock?.complete();
  }

  Future<void> loadStoredSession() async {
    await _acquireLock();
    try {
      final storedToken = await _secureStorage.read(key: _tokenKey);
      final userJson = await _secureStorage.read(key: _userKey);

      // Both token and user must be present for a valid session
      if (storedToken == null || userJson == null) {
        await _clearStoredSession();
        return;
      }

      // Check if token is expired
      if (_isTokenExpired(storedToken)) {
        await _clearStoredSession();
        return;
      }

      // Parse user data
      try {
        _currentUser = User.fromJson(
          json.decode(userJson) as Map<String, dynamic>,
        );
        _token = storedToken;
      } on Exception catch (e) {
        _debugLog('Failed to parse stored user: $e');
        await _clearStoredSession();
      }
    } on Exception catch (e) {
      _debugLog('Failed to load session: $e');
      _token = null;
      _currentUser = null;
    } finally {
      _releaseLock();
    }
  }

  Future<void> _clearStoredSession() async {
    _token = null;
    _currentUser = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
  }

  bool get isTokenValid => _token != null && !_isTokenExpired(_token!);

  bool _isTokenExpired(String token) {
    return _isTokenExpiredOrExpiringSoon(token, threshold: Duration.zero);
  }

  bool _isTokenExpiredOrExpiringSoon(
    String token, {
    Duration threshold = const Duration(minutes: 5),
  }) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }

      final List<int> decodedBytes;
      try {
        decodedBytes = base64Url.decode(payload);
      } on Exception catch (e) {
        _debugLog('Invalid base64 in token payload: $e');
        return true;
      }

      final String decoded;
      try {
        decoded = utf8.decode(decodedBytes);
      } on Exception catch (e) {
        _debugLog('Invalid UTF-8 in token payload: $e');
        return true;
      }

      final dynamic decodedJson = json.decode(decoded);
      if (decodedJson is! Map<String, dynamic>) {
        _debugLog('Token payload is not a valid JSON object');
        return true;
      }

      final claims = decodedJson;
      final expValue = claims['exp'];
      if (expValue == null) return true;

      final int exp;
      if (expValue is int) {
        exp = expValue;
      } else if (expValue is double) {
        exp = expValue.toInt();
      } else {
        _debugLog('Invalid exp claim type');
        return true;
      }

      final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      return expiryTime.isBefore(now.add(threshold));
    } on Exception catch (e) {
      _debugLog('Error parsing token: $e');
      return true;
    }
  }

  Future<void> register(String username, String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _token = data['token'] as String;
        _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);

        await _secureStorage.write(key: _tokenKey, value: _token);
        await _secureStorage.write(
          key: _userKey,
          value: json.encode(data['user']),
        );
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on Exception catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to register: $e');
    } finally {
      _releaseLock();
    }
  }

  Future<void> login(String username, String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _token = data['token'] as String;
        _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);

        await _secureStorage.write(key: _tokenKey, value: _token);
        await _secureStorage.write(
          key: _userKey,
          value: json.encode(data['user']),
        );
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on Exception catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to login: $e');
    } finally {
      _releaseLock();
    }
  }

  Future<void> logout({bool sessionExpired = false}) async {
    await _acquireLock();
    final hadToken = _token != null;

    try {
      if (_token != null && !sessionExpired) {
        // Only call server logout if not due to session expiration
        await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/sessions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } on Exception catch (e) {
      _debugLog('Logout request failed: $e');
    } finally {
      _token = null;
      _currentUser = null;

      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);

      _releaseLock();

      if (sessionExpired && hadToken && onSessionExpired != null) {
        onSessionExpired!();
      }
    }
  }

  /// Called by API service when a 401 response is received
  void handleSessionExpired() {
    logout(sessionExpired: true);
  }

  Map<String, String> getAuthHeaders() {
    if (_token == null) {
      return {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  ({String message, String? code}) _parseError(http.Response response) {
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (
        message: data['error'] as String? ?? 'Unknown error',
        code: data['code'] as String?,
      );
    } on Exception catch (e) {
      _debugLog('Failed to parse error response: $e');
      return (message: 'Request failed (${response.statusCode})', code: null);
    }
  }

  /// Debug logging that only runs in debug mode
  void _debugLog(String message) {
    if (kDebugMode) {
      print('AuthService: $message');
    }
  }

  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _acquireLock();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/users/me/password'),
        headers: getAuthHeaders(),
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final newToken = data['token'] as String?;
        if (newToken == null) {
          throw const AuthException(
            'Password updated but no new token received',
          );
        }
        _token = newToken;
        await _secureStorage.write(key: _tokenKey, value: _token);
        return;
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on Exception catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to update password: $e');
    } finally {
      _releaseLock();
    }
  }

  Future<int> resetHistory(String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/me/history-clearance'),
        headers: getAuthHeaders(),
        body: json.encode({'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['deleted_count'] as int;
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on Exception catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to reset history: $e');
    } finally {
      _releaseLock();
    }
  }

  Future<void> deleteAccount(String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/me/deletion'),
        headers: getAuthHeaders(),
        body: json.encode({'password': password}),
      );

      if (response.statusCode == 200) {
        _token = null;
        _currentUser = null;
        await _secureStorage.delete(key: _tokenKey);
        await _secureStorage.delete(key: _userKey);
        return;
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on Exception catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to delete account: $e');
    } finally {
      _releaseLock();
    }
  }
}
