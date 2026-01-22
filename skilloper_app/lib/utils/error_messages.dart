import '../services/auth_service.dart';

/// Converts AuthException to user-friendly error messages.
/// Maps known error codes to friendly messages and capitalizes unknown ones.
String friendlyAuthError(AuthException e) {
  switch (e.code) {
    // Login errors
    case 'INVALID_CREDENTIALS':
      return 'Incorrect username or password. Please try again.';
    case 'ACCOUNT_LOCKED':
      return 'Account temporarily locked. Please try again later.';
    case 'UNAUTHORIZED':
      return 'Please log in to continue.';

    // Registration errors
    case 'USERNAME_TAKEN':
      return 'This username is already taken. Please choose another.';
    case 'INVALID_USERNAME':
      return 'Username must be 6-30 characters using only letters, numbers, and underscores.';
    case 'INVALID_PASSWORD':
      return 'Password must be 8-72 characters long.';
    case 'WEAK_PASSWORD':
      return 'Password must include uppercase, lowercase, and a number.';

    // Generic errors
    case 'REQUEST_FAILED':
      return 'Something went wrong. Please try again.';

    default:
      // Capitalize first letter of original message
      final msg = e.message;
      return msg.isEmpty ? msg : '${msg[0].toUpperCase()}${msg.substring(1)}';
  }
}
