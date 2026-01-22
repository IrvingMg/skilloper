import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

void showCopySuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check,
            color: AppColors.textOnPrimary,
            size: AppIconSizes.sm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(message),
        ],
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.success,
    ),
  );
}

void showCopyErrorSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.textOnPrimary,
            size: AppIconSizes.sm,
          ),
          SizedBox(width: AppSpacing.sm),
          Text('Failed to copy. Please select and copy manually.'),
        ],
      ),
      duration: Duration(seconds: 3),
      backgroundColor: AppColors.error,
    ),
  );
}
