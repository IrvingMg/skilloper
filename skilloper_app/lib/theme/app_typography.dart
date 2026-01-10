import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Skilloper App Design System - Typography
/// Consistent text styles following Material Design 3 principles
class AppTypography {
  AppTypography._();

  // MARK: - Text Styles

  // Display styles (largest)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  // Headline styles
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // Title styles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  // Label styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.3,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
    color: AppColors.textTertiary,
  );

  // MARK: - Context-Specific Styles

  // Question text
  static const TextStyle questionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle questionBody = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  // Answer text
  static const TextStyle answerText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle answerLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  // Card content
  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  static const TextStyle cardMeta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  // Button text
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  // Badge/Chip text
  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
  );

  // Code text
  static const TextStyle code = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
    fontFamily: 'monospace',
    color: AppColors.codeText,
  );

  static const TextStyle codeSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
    fontFamily: 'monospace',
    color: AppColors.codeText,
  );

  // Helper/hint text
  static const TextStyle helper = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  // Stat/score display (large numbers)
  static const TextStyle statLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle statMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  // Section headers (bold variants)
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // Input/form text
  static const TextStyle input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle inputLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  // List item text
  static const TextStyle listTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle listSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  // Caption for small descriptive text
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  // MARK: - Color Variants

  // Success variants
  static TextStyle get successText =>
      bodyMedium.copyWith(color: AppColors.onSuccessContainer);

  static TextStyle get successLabel =>
      labelMedium.copyWith(color: AppColors.onSuccessContainer);

  // Error variants
  static TextStyle get errorText =>
      bodyMedium.copyWith(color: AppColors.onErrorContainer);

  static TextStyle get errorLabel =>
      labelMedium.copyWith(color: AppColors.onErrorContainer);

  // Warning variants
  static TextStyle get warningText =>
      bodyMedium.copyWith(color: AppColors.onWarningContainer);

  static TextStyle get warningLabel =>
      labelMedium.copyWith(color: AppColors.onWarningContainer);

  // Info variants
  static TextStyle get infoText =>
      bodyMedium.copyWith(color: AppColors.onInfoContainer);

  static TextStyle get infoLabel =>
      labelMedium.copyWith(color: AppColors.onInfoContainer);
}
