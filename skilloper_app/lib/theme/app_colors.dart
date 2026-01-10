import 'package:flutter/material.dart';

/// Skilloper App Design System - Colors
/// Soft Gradient Violet theme - friendly, premium-leaning, calm, progress-focused
class AppColors {
  AppColors._();

  // MARK: - Primary Brand Colors (Soft Violet)
  static const Color primary = Color(
    0xFF6D5EF7,
  ); // Soft violet - main brand color
  static const Color primaryLight = Color(0xFF7B6CFF); // Lighter violet
  static const Color primaryDark = Color(0xFF5B4BE6); // Darker for hover states
  static const Color primaryDeep = Color(0xFF4C3EDC); // Deepest for gradients
  static const Color primaryDarkest = Color(
    0xFF3F32B8,
  ); // For text on light backgrounds

  // Primary container colors (lavender tints)
  static const Color primaryContainer = Color(0xFFEEE8FF); // Violet 100
  static const Color primaryContainerLight = Color(0xFFF6F3FF); // Violet 50
  static const Color onPrimaryContainer = Color(0xFF3F32B8); // Violet 800

  // MARK: - Surface Colors (Lavender-tinted)
  static const Color surface = Color(0xFFFBFAFF); // Lavender-white background
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Pure white for cards
  static const Color surfaceContainer = Color(
    0xFFF4F1FF,
  ); // Container background
  static const Color surfaceContainerHigh = Color(
    0xFFE8E3FF,
  ); // Higher emphasis container

  // Border colors (violet-tinted)
  static const Color outline = Color(0xFFE8E3FF); // Default border
  static const Color outlineSubtle = Color(0xFFF2EFFF); // Subtle border
  static const Color outlineVariant = Color(0xFFE8E3FF); // Variant border

  // Legacy compatibility (maps to new surface colors)
  static const Color surfaceVariant = surfaceContainer;

  // MARK: - Accent Colors (UI chips/icons)
  static const Color accentTeal = Color(0xFF2CBAC3); // For icons and chips
  static const Color accentBlue = Color(0xFF4C9DFF); // Secondary accent
  static const Color accentOrange = Color(0xFFF6B34B); // Highlight/achievement

  // MARK: - Semantic Colors (Learning Platform Optimized)
  // Success (Teal-Green) - Fresh celebration of learning
  static const Color success = Color(0xFF22C55E); // Green for correct answers
  static const Color successLight = Color(0xFF4ADE80); // Lighter green
  static const Color successContainer = Color(0xFFE9FFF9); // Very light green
  static const Color onSuccessContainer = Color(0xFF14532D); // Dark green text

  // Error (Soft Red) - Less harsh for learning mistakes
  static const Color error = Color(0xFFEF4444); // Soft red
  static const Color errorLight = Color(0xFFF87171); // Lighter red
  static const Color errorContainer = Color(0xFFFFF5F5); // Very light red
  static const Color onErrorContainer = Color(0xFF7F1D1D); // Dark red text

  // Warning (Orange) - Energetic for challenges
  static const Color warning = Color(0xFFEA580C); // Orange
  static const Color warningLight = Color(0xFFF97316); // Lighter orange
  static const Color warningContainer = Color(0xFFFED7AA); // Light orange
  static const Color onWarningContainer = Color(0xFF9A3412); // Dark orange text

  // Info (Cyan) - Distinct informational color
  static const Color info = Color(0xFF0891B2); // Cyan
  static const Color infoContainer = Color(0xFFCFFAFE); // Light cyan
  static const Color onInfoContainer = Color(0xFF164E63); // Dark cyan text

  // MARK: - Text Colors
  static const Color textPrimary = Color(0xFF111827); // Gray 900 - main text
  static const Color textSecondary = Color(
    0xFF374151,
  ); // Gray 700 - secondary text
  static const Color textTertiary = Color(
    0xFF6B7280,
  ); // Gray 500 - tertiary/meta
  static const Color textDisabled = Color(0xFF9CA3AF); // Gray 400 - disabled
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White text on primary

  // MARK: - Code Block Colors
  static const Color codeBackground = Color(0xFFF1F5F9); // Slate 100
  static const Color codeBorder = Color(0xFFCBD5E1); // Slate 300
  static const Color codeText = Color(0xFF1E293B); // Slate 800
  static const Color codeKeyword = Color(0xFF7C3AED); // Violet 600
  static const Color codeString = Color(0xFF059669); // Emerald 600
  static const Color codeComment = Color(0xFF64748B); // Slate 500

  // MARK: - Achievement & Progress
  static const Color achievement = Color(
    0xFFF6B34B,
  ); // Gold/orange for achievements
  static const Color achievementContainer = Color(0xFFFEF3C7); // Light gold
  static const Color progress = Color(0xFF06B6D4); // Cyan for progress
  static const Color progressContainer = Color(0xFFCFFAFE); // Light cyan

  // MARK: - Difficulty Levels
  static const Color beginner = Color(0xFF22C55E); // Green - easy
  static const Color intermediate = Color(0xFFF59E0B); // Amber - medium
  static const Color advanced = Color(0xFFEF4444); // Red - hard
  static const Color expert = Color(0xFF8B5CF6); // Violet - expert

  // MARK: - Interactive States
  static const Color focus = primary;
  static const Color selection = Color(0xFFEEE8FF); // Primary container
  static const Color selectionHover = Color(0xFFE0DEFF); // Slightly darker
  static const Color hoverOverlay = Color(0x08000000); // 3% black
  static const Color pressedOverlay = Color(0x10000000); // 6% black
}

/// Gradient definitions for the Soft Gradient Violet theme
class AppGradients {
  AppGradients._();

  // Primary gradient for buttons and brand elements
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7B6CFF), // Light violet
      Color(0xFF6D5EF7), // Primary violet
      Color(0xFF4C3EDC), // Deep violet
    ],
    stops: [0.0, 0.45, 1.0],
  );

  // Subtle glow for cards (optional premium feel)
  static const RadialGradient cardGlow = RadialGradient(
    center: Alignment(0.8, -0.5),
    radius: 0.8,
    colors: [
      Color(0x2E6D5EF7), // 18% primary
      Color(0x006D5EF7), // Transparent
    ],
    stops: [0.0, 0.6],
  );

  // Course category gradients
  static const LinearGradient python = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6D5EF7), // Violet
      Color(0xFF4C3EDC), // Deep violet
    ],
  );

  static const LinearGradient async = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2CBAC3), // Teal
      Color(0xFF0891B2), // Cyan
    ],
  );

  static const LinearGradient javascript = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF6B34B), // Orange
      Color(0xFFF59E0B), // Amber
    ],
  );
}

/// Shadow definitions - soft + airy with violet tint
class AppShadows {
  AppShadows._();

  // Small shadow for chips and small elements
  static const List<BoxShadow> sm = [
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: 2,
      color: Color(0x0F0F172A), // 6% neutral
    ),
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 16,
      color: Color(0x146D5EF7), // 8% violet
    ),
  ];

  // Medium shadow for cards and buttons
  static const List<BoxShadow> md = [
    BoxShadow(
      offset: Offset(0, 2),
      blurRadius: 6,
      color: Color(0x140F172A), // 8% neutral
    ),
    BoxShadow(
      offset: Offset(0, 18),
      blurRadius: 40,
      color: Color(0x1A6D5EF7), // 10% violet
    ),
  ];

  // Large shadow for elevated elements
  static const List<BoxShadow> lg = [
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 24,
      color: Color(0x1A0F172A), // 10% neutral
    ),
    BoxShadow(
      offset: Offset(0, 30),
      blurRadius: 70,
      color: Color(0x1F6D5EF7), // 12% violet
    ),
  ];

  // Extra large for modals and dialogs
  static const List<BoxShadow> xl = [
    BoxShadow(
      offset: Offset(0, 12),
      blurRadius: 32,
      color: Color(0x1F0F172A), // 12% neutral
    ),
    BoxShadow(
      offset: Offset(0, 40),
      blurRadius: 80,
      color: Color(0x246D5EF7), // 14% violet
    ),
  ];
}

/// Border radius values - softer, more modern
class AppRadius {
  AppRadius._();

  static const double xs = 6.0; // Chips, small controls
  static const double sm = 10.0; // Inputs
  static const double md = 14.0; // Buttons, answer options
  static const double lg = 18.0; // Cards, panels
  static const double xl = 24.0; // Hero cards, feature tiles
  static const double full = 9999.0; // Pills

  // BorderRadius helpers
  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Color schemes for different contexts
class AppColorSchemes {
  AppColorSchemes._();

  // Light theme color scheme - Soft Gradient Violet
  static const ColorScheme light = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.accentTeal,
    secondaryContainer: Color(0xFFE0F7F9),
    onSecondaryContainer: Color(0xFF0E5A5F),
    tertiary: AppColors.accentOrange,
    tertiaryContainer: AppColors.achievementContainer,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerLowest: AppColors.surfaceWhite,
    surfaceContainerLow: AppColors.surfaceContainer,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHigh,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineSubtle,
    error: AppColors.error,
    onError: AppColors.textOnPrimary,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
  );
}

/// Spacing constants for consistent layouts
class AppSpacing {
  AppSpacing._();

  // Base spacing values (4px scale)
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Semantic spacing aliases
  static const double inlineSpacing = 4.0;
  static const double elementSpacing = 8.0;
  static const double componentSpacing = 12.0;
  static const double sectionSpacing = 16.0;
  static const double pageSpacing = 24.0;

  // EdgeInsets helpers
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);
  static const EdgeInsets allXxxl = EdgeInsets.all(xxxl);

  // Horizontal EdgeInsets helpers
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets horizontalXxl = EdgeInsets.symmetric(horizontal: xxl);

  // Vertical EdgeInsets helpers
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets verticalXxl = EdgeInsets.symmetric(vertical: xxl);
}
