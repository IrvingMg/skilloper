import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Snackbar type for styling.
enum SnackBarType { success, error, warning }

/// Shows a success snackbar with a check icon.
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    buildStyledSnackBar(message: message, type: SnackBarType.success),
  );
}

/// Shows an error snackbar with an error icon.
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    buildStyledSnackBar(message: message, type: SnackBarType.error),
  );
}

/// Shows a warning snackbar with a warning icon.
void showWarningSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    buildStyledSnackBar(message: message, type: SnackBarType.warning),
  );
}

/// Shows a success snackbar for copy operations (shorter duration).
void showCopySuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    buildStyledSnackBar(
      message: message,
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Shows an error snackbar for copy operations.
void showCopyErrorSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    buildStyledSnackBar(
      message: 'Failed to copy. Please select and copy manually.',
      type: SnackBarType.error,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Builds a styled snackbar for use with a captured [ScaffoldMessengerState].
///
/// Use this when you need to show a snackbar after a dialog closes:
/// ```dart
/// final scaffoldMessenger = ScaffoldMessenger.of(context);
/// await showDialog(...);
/// scaffoldMessenger.showSnackBar(
///   buildStyledSnackBar(message: 'Success!', type: SnackBarType.success),
/// );
/// ```
SnackBar buildStyledSnackBar({
  required String message,
  required SnackBarType type,
  Duration? duration,
}) {
  return SnackBar(
    content: Row(
      children: [
        Icon(
          _iconForType(type),
          color: AppColors.textOnPrimary,
          size: AppIconSizes.lg,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message)),
      ],
    ),
    backgroundColor: _colorForType(type),
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    duration: duration ?? const Duration(seconds: 4),
  );
}

IconData _iconForType(SnackBarType type) {
  switch (type) {
    case SnackBarType.success:
      return Icons.check_circle;
    case SnackBarType.error:
      return Icons.error;
    case SnackBarType.warning:
      return Icons.warning;
  }
}

Color _colorForType(SnackBarType type) {
  switch (type) {
    case SnackBarType.success:
      return AppColors.success;
    case SnackBarType.error:
      return AppColors.error;
    case SnackBarType.warning:
      return AppColors.warning;
  }
}
