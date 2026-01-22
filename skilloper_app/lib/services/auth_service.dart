import 'dart:async';
import 'dart:convert' show base64Url, json, utf8;
import 'dart:ui' show VoidCallback;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';
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
  static const String _refreshTokenKey = 'skilloper_refresh_token';
  static const String _userKey = 'skilloper_user';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Secure storage for native platforms
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Cached SharedPreferences instance for web
  SharedPreferences? _webPrefs;

  Future<SharedPreferences> get _prefs async =>
      _webPrefs ??= await SharedPreferences.getInstance();

  // Storage helper methods that use SharedPreferences on web
  Future<String?> _readStorage(String key) async {
    if (kIsWeb) {
      final prefs = await _prefs;
      return prefs.getString(key);
    }
    return _secureStorage.read(key: key);
  }

  Future<void> _writeStorage(String key, String value) async {
    if (kIsWeb) {
      final prefs = await _prefs;
      await prefs.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<void> _deleteStorage(String key) async {
    if (kIsWeb) {
      final prefs = await _prefs;
      await prefs.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  // Synchronization lock for auth operations
  Completer<void>? _operationLock;

  // Prevents concurrent refresh attempts
  Completer<bool>? _refreshCompleter;

  String? _token;
  String? _refreshToken;
  User? _currentUser;
  VoidCallback? onSessionExpired;

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null && _currentUser != null;

  /// Acquires lock for auth operations to prevent race conditions
  Future<void> _acquireLock() async {
    var currentLock = _operationLock;
    while (currentLock != null) {
      await currentLock.future;
      currentLock = _operationLock;
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
      final storedToken = await _readStorage(_tokenKey);
      final storedRefreshToken = await _readStorage(_refreshTokenKey);
      final userJson = await _readStorage(_userKey);

      // Must have refresh token and user for a valid session
      if (storedRefreshToken == null || userJson == null) {
        await _clearStoredSession();
        return;
      }

      // Parse user data first
      try {
        _currentUser = User.fromJson(
          json.decode(userJson) as Map<String, dynamic>,
        );
      } on Exception catch (e) {
        _debugLog('Failed to parse stored user: $e');
        await _clearStoredSession();
        return;
      }

      _refreshToken = storedRefreshToken;

      // If access token exists and is valid, use it
      if (storedToken != null && !_isTokenExpired(storedToken)) {
        _token = storedToken;
      } else {
        // Access token missing or expired, try to refresh
        _releaseLock();
        final refreshed = await refreshAccessToken();
        await _acquireLock();

        if (!refreshed) {
          await _clearStoredSession();
          return;
        }
      }
    } on Object catch (e) {
      _debugLog('Failed to load session: $e');
      await _clearStoredSession();
    } finally {
      _releaseLock();
    }
  }

  Future<void> _clearStoredSession() async {
    _token = null;
    _refreshToken = null;
    _currentUser = null;
    await _deleteStorage(_tokenKey);
    await _deleteStorage(_refreshTokenKey);
    await _deleteStorage(_userKey);
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

  /// Attempts to refresh the access token using the refresh token.
  /// Returns true if successful, false if refresh failed (requires re-login).
  Future<bool> refreshAccessToken() async {
    // Prevent concurrent refresh attempts - capture in local var to avoid race
    final existingCompleter = _refreshCompleter;
    if (existingCompleter != null) {
      return existingCompleter.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshToken =
          _refreshToken ?? await _readStorage(_refreshTokenKey);
      if (refreshToken == null) {
        completer.complete(false);
        return false;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.sessionsRefresh}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final newRefreshToken = data['refresh_token'] as String;
        _token = token;
        _refreshToken = newRefreshToken;

        await _writeStorage(_tokenKey, token);
        await _writeStorage(_refreshTokenKey, newRefreshToken);

        _debugLog('Access token refreshed successfully');
        completer.complete(true);
        return true;
      } else {
        _debugLog('Token refresh failed: ${response.statusCode}');
        // Clear invalid refresh token from memory
        _refreshToken = null;
        await _deleteStorage(_refreshTokenKey);
        completer.complete(false);
        return false;
      }
    } on Object catch (e) {
      _debugLog('Token refresh error: $e');
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> register(String username, String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.users}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final refreshToken = data['refresh_token'] as String;
        _token = token;
        _refreshToken = refreshToken;
        _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);

        await _writeStorage(_tokenKey, token);
        await _writeStorage(_refreshTokenKey, refreshToken);
        await _writeStorage(_userKey, json.encode(data['user']));
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on AuthException {
      rethrow;
    } on Object catch (e) {
      throw AuthException('Failed to register: $e');
    } finally {
      _releaseLock();
    }
  }

  Future<void> login(String username, String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.sessions}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final refreshToken = data['refresh_token'] as String;
        _token = token;
        _refreshToken = refreshToken;
        _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);

        await _writeStorage(_tokenKey, token);
        await _writeStorage(_refreshTokenKey, refreshToken);
        await _writeStorage(_userKey, json.encode(data['user']));
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on AuthException {
      rethrow;
    } on Object catch (e) {
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
          Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.sessions}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } on Object catch (e) {
      _debugLog('Logout request failed: $e');
    } finally {
      _token = null;
      _refreshToken = null;
      _currentUser = null;

      await _deleteStorage(_tokenKey);
      await _deleteStorage(_refreshTokenKey);
      await _deleteStorage(_userKey);

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
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return (
          message: decoded['error'] as String? ?? 'Unknown error',
          code: decoded['code'] as String?,
        );
      }
      return (message: 'Request failed', code: 'REQUEST_FAILED');
    } on Object catch (e) {
      _debugLog('Failed to parse error response: $e');
      return (message: 'Request failed', code: 'REQUEST_FAILED');
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
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.userPassword}'),
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
        await _writeStorage(_tokenKey, newToken);
        return;
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on AuthException {
      rethrow;
    } on Object catch (e) {
      throw AuthException('Failed to update password: $e');
    } finally {
      _releaseLock();
    }
  }

  Future<int> resetHistory(String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.userHistoryClearance}'),
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
    } on AuthException {
      rethrow;
    } on Object catch (e) {
      throw AuthException('Failed to reset history: $e');
    } finally {
      _releaseLock();
    }
  }

  Future<void> deleteAccount(String password) async {
    await _acquireLock();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.userDeletion}'),
        headers: getAuthHeaders(),
        body: json.encode({'password': password}),
      );

      if (response.statusCode == 200) {
        _token = null;
        _refreshToken = null;
        _currentUser = null;
        await _deleteStorage(_tokenKey);
        await _deleteStorage(_refreshTokenKey);
        await _deleteStorage(_userKey);
        return;
      } else {
        final error = _parseError(response);
        throw AuthException(error.message, code: error.code);
      }
    } on AuthException {
      rethrow;
    } on Object catch (e) {
      throw AuthException('Failed to delete account: $e');
    } finally {
      _releaseLock();
    }
  }
}
