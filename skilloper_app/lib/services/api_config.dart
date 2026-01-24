import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const String _envUrl = String.fromEnvironment('API_URL');

  static String get baseUrl {
    // If API_URL is explicitly set, use it
    if (_envUrl.isNotEmpty) {
      return _envUrl;
    }

    // On web, derive API URL from current window location
    if (kIsWeb) {
      return _getWebBaseUrl();
    }

    // Default for native development
    return 'http://localhost:8080/api/v1';
  }

  static String _getWebBaseUrl() {
    final uri = Uri.base;
    final scheme = uri.scheme;
    final host = uri.host;
    final port = uri.port;

    if (port == 3001 || port == 3000) {
      return '$scheme://$host:8080/api/v1';
    }

    final portStr = uri.hasPort && port != 80 && port != 443 ? ':$port' : '';
    return '$scheme://$host$portStr/api/v1';
  }
}
