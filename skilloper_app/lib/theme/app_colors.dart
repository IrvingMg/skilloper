import 'package:flutter/material.dart';

/// Skilloper App Design System - Colors
/// A comprehensive color palette following Material Design 3 principles
class AppColors {
  AppColors._();

  // MARK: - Primary Brand Colors (Learning Platform Focused)
  static const Color primary = Color(0xFF4F46E5); // Indigo 600 - Inspiring, educational
  static const Color primaryLight = Color(0xFF6366F1); // Indigo 500

  // Primary container colors
  static const Color primaryContainer = Color(0xFFE0E7FF); // Indigo 100
  static const Color onPrimaryContainer = Color(0xFF312E81); // Indigo 800

  // MARK: - Semantic Colors (Learning Platform Optimized)
  // Success (Green) - More vibrant for achievements
  static const Color success = Color(0xFF16A34A); // Green 600 - Celebration of learning
  static const Color successLight = Color(0xFF22C55E); // Green 500
  static const Color successContainer = Color(0xFFDCFCE7); // Green 100
  static const Color onSuccessContainer = Color(0xFF14532D); // Green 900

  // Error (Red) - Softer for learning mistakes
  static const Color error = Color(0xFFE11D48); // Rose 600 - Less harsh than pure red
  static const Color errorLight = Color(0xFFF43F5E); // Rose 500
  static const Color errorContainer = Color(0xFFFFE4E6); // Rose 100
  static const Color onErrorContainer = Color(0xFF881337); // Rose 900

  // Warning (Orange) - Energetic for learning challenges
  static const Color warning = Color(0xFFEA580C); // Orange 600 - More energetic
  static const Color warningLight = Color(0xFFF97316); // Orange 500
  static const Color warningContainer = Color(0xFFFED7AA); // Orange 100
  static const Color onWarningContainer = Color(0xFF9A3412); // Orange 800

  // Info (Cyan) - Distinct from primary for learning context
  static const Color info = Color(0xFF0891B2); // Cyan 600
  static const Color infoContainer = Color(0xFFCFFAFE); // Cyan 100
  static const Color onInfoContainer = Color(0xFF164E63); // Cyan 900

  // MARK: - Neutral Colors (Gray palette)
  // Text colors
  static const Color textPrimary = Color(0xFF111827); // Gray 900
  static const Color textSecondary = Color(0xFF374151); // Gray 700
  static const Color textTertiary = Color(0xFF6B7280); // Gray 500
  static const Color textDisabled = Color(0xFF9CA3AF); // Gray 400

  // Surface colors - Warmer and more engaging
  static const Color surface = Color(0xFFFEFEFE); // Warm white
  static const Color surfaceVariant = Color(0xFFF8FAFC); // Slate 50 - subtle blue tint
  static const Color surfaceContainer = Color(0xFFF1F5F9); // Slate 100 - learning-friendly
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0); // Slate 200

  // Border colors
  static const Color outline = Color(0xFFD1D5DB); // Gray 300
  static const Color outlineVariant = Color(0xFFE5E7EB); // Gray 200

  // MARK: - Special Purpose Colors
  // Questionnaire types - Distinct from main app/semantic colors
  static const Color typePractice = Color(0xFFEC4899); // Pink 500
  static const Color typePracticeContainer = Color(0xFFFCE7F3); // Pink 100
  static const Color onTypePracticeContainer = Color(0xFF831843); // Pink 900

  static const Color typeExam = Color(0xFFF97316); // Orange 500 (different from warning 600)
  static const Color typeExamContainer = Color(0xFFFEEBDC); // Light orange
  static const Color onTypeExamContainer = Color(0xFF7C2D12); // Orange 900

  // Back-compat: temporary mapping while migrating usages
  static const Color practiceMode = typePractice;
  static const Color practiceModeContainer = typePracticeContainer;
  static const Color onPracticeModeContainer = onTypePracticeContainer;

  static const Color examMode = typeExam;
  static const Color examModeContainer = typeExamContainer;
  static const Color onExamModeContainer = onTypeExamContainer;

  // Code block colors - Enhanced for learning
  static const Color codeBackground = Color(0xFFF1F5F9); // Slate 100 - better contrast
  static const Color codeBorder = Color(0xFFCBD5E1); // Slate 300 - more defined
  static const Color codeText = Color(0xFF1E293B); // Slate 800 - better readability
  static const Color codeKeyword = Color(0xFF7C3AED); // Violet 600 - syntax highlighting
  static const Color codeString = Color(0xFF059669); // Emerald 600
  static const Color codeComment = Color(0xFF64748B); // Slate 500

  // MARK: - Learning Platform Specific Colors
  // Achievement and progress colors
  static const Color achievement = Color(0xFFF59E0B); // Amber 500 - golden achievement
  static const Color achievementContainer = Color(0xFFFEF3C7); // Amber 100
  static const Color progress = Color(0xFF06B6D4); // Cyan 500 - progress indication
  static const Color progressContainer = Color(0xFFCFFAFE); // Cyan 100
  
  // Difficulty levels
  static const Color beginner = Color(0xFF22C55E); // Green 500 - easy
  static const Color intermediate = Color(0xFFF59E0B); // Amber 500 - medium
  static const Color advanced = Color(0xFFEF4444); // Red 500 - hard
  static const Color expert = Color(0xFF8B5CF6); // Violet 500 - expert

  // MARK: - Accessibility & State Colors
  // Focus and selection - more vibrant
  static const Color focus = primary;
  static const Color selection = Color(0xFFC7D2FE); // Indigo 200
  static const Color selectionHover = Color(0xFFA5B4FC); // Indigo 300

  // Hover states (for web)
  static const Color hoverOverlay = Color(0x0A000000); // 4% black - lighter
  static const Color pressedOverlay = Color(0x14000000); // 8% black - lighter
}

/// Color schemes for different contexts
class AppColorSchemes {
  AppColorSchemes._();

  // Light theme color scheme - Learning platform optimized
  static const ColorScheme light = ColorScheme.light(
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.progress, // Use progress color as secondary
    secondaryContainer: AppColors.progressContainer,
    tertiary: AppColors.achievement, // Achievement color as tertiary
    tertiaryContainer: AppColors.achievementContainer,
    surface: AppColors.surface,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHighest: AppColors.surfaceContainerHigh,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    error: AppColors.error,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
  );
}