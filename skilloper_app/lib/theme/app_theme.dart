import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_icons.dart';

/// Skilloper App Design System - Complete Theme
class AppTheme {
  AppTheme._();

  // MARK: - Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorSchemes.light,

      // Typography
      textTheme: _textTheme,

      // App Bar
      appBarTheme: _appBarTheme,

      // Cards
      cardTheme: _cardTheme,

      // Navigation (Material 3)
      navigationBarTheme: _navigationBarTheme,
      
      // Bottom Navigation (Legacy)
      bottomNavigationBarTheme: _bottomNavigationBarTheme,

      // Dividers
      dividerTheme: _dividerTheme,

      // Buttons
      elevatedButtonTheme: _elevatedButtonTheme,
      textButtonTheme: _textButtonTheme,
      iconButtonTheme: _iconButtonTheme,

      // Input fields
      inputDecorationTheme: _inputDecorationTheme,

      // Icons
      iconTheme: AppIconThemes.light,

      // Progress indicators
      progressIndicatorTheme: _progressIndicatorTheme,

      // Chips
      chipTheme: _chipTheme,
    );
  }

  // MARK: - Component Themes

  static const TextTheme _textTheme = TextTheme(
    displayLarge: AppTypography.displayLarge,
    displayMedium: AppTypography.displayMedium,
    headlineLarge: AppTypography.headlineLarge,
    headlineMedium: AppTypography.headlineMedium,
    headlineSmall: AppTypography.headlineSmall,
    titleLarge: AppTypography.titleLarge,
    titleMedium: AppTypography.titleMedium,
    titleSmall: AppTypography.titleSmall,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.labelLarge,
    labelMedium: AppTypography.labelMedium,
    labelSmall: AppTypography.labelSmall,
  );

  static const AppBarTheme _appBarTheme = AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: AppColors.primaryContainer,
    foregroundColor: AppColors.onPrimaryContainer,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.onPrimaryContainer,
    ),
    iconTheme: IconThemeData(
      color: AppColors.onPrimaryContainer,
      size: AppIconSizes.navIcon,
    ),
  );

  static const CardThemeData _cardTheme = CardThemeData(
    elevation: 3, // Slightly more elevation for depth
    shadowColor: Color(0x12000000), // Slightly more visible shadow
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)), // More rounded for friendliness
    ),
    color: AppColors.surface,
    surfaceTintColor: AppColors.primary, // Material 3 surface tinting
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      textStyle: AppTypography.buttonMedium,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)), // More rounded for friendliness
      ),
      elevation: 3, // Slightly more elevation for learning platform
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
    ),
  );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTypography.buttonMedium,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );

  static final IconButtonThemeData _iconButtonTheme = IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      padding: const EdgeInsets.all(12),
      iconSize: AppIconSizes.buttonIcon,
    ),
  );

  static const InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceContainer,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.error),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: AppTypography.labelLarge,
    hintStyle: AppTypography.bodyMedium,
  );

  // Material 3 NavigationBar theme
  static final NavigationBarThemeData _navigationBarTheme = NavigationBarThemeData(
    elevation: 3,
    backgroundColor: AppColors.surface,
    surfaceTintColor: AppColors.primary,
    shadowColor: Colors.black.withValues(alpha: 0.1),
    height: 80,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        );
      }
      return AppTypography.labelMedium.copyWith(
        color: AppColors.textTertiary,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return IconThemeData(
          color: AppColors.primary,
          size: AppIconSizes.navIcon,
        );
      }
      return IconThemeData(
        color: AppColors.textTertiary,
        size: AppIconSizes.navIcon,
      );
    }),
    indicatorColor: AppColors.primaryContainer,
    indicatorShape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  );

  // Legacy BottomNavigationBar theme (kept for compatibility)
  static final BottomNavigationBarThemeData _bottomNavigationBarTheme = BottomNavigationBarThemeData(
    elevation: 8,
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textTertiary,
    selectedLabelStyle: AppTypography.labelMedium.copyWith(
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: AppTypography.labelMedium,
    type: BottomNavigationBarType.fixed,
    showSelectedLabels: true,
    showUnselectedLabels: true,
  );

  static const DividerThemeData _dividerTheme = DividerThemeData(
    color: AppColors.outlineVariant,
    thickness: 1,
    space: 1,
  );

  static const ProgressIndicatorThemeData _progressIndicatorTheme = ProgressIndicatorThemeData(
    color: AppColors.primary,
    linearTrackColor: AppColors.surfaceContainer,
    circularTrackColor: AppColors.surfaceContainer,
  );

  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: AppColors.surfaceContainer,
    selectedColor: AppColors.primaryContainer,
    labelStyle: AppTypography.labelMedium,
    side: const BorderSide(color: AppColors.outline),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

/// Additional theme utilities
class AppThemeExtensions {
  AppThemeExtensions._();

  // Semantic color getters for easy access
  static Color success(BuildContext context) => AppColors.success;
  static Color successContainer(BuildContext context) => AppColors.successContainer;
  static Color error(BuildContext context) => AppColors.error;
  static Color errorContainer(BuildContext context) => AppColors.errorContainer;
  static Color warning(BuildContext context) => AppColors.warning;
  static Color warningContainer(BuildContext context) => AppColors.warningContainer;

  // Text style getters with context
  static TextStyle questionTitle(BuildContext context) => AppTypography.questionTitle;
  static TextStyle questionBody(BuildContext context) => AppTypography.questionBody;
  static TextStyle cardTitle(BuildContext context) => AppTypography.cardTitle;
  static TextStyle cardSubtitle(BuildContext context) => AppTypography.cardSubtitle;
  static TextStyle answerText(BuildContext context) => AppTypography.answerText;
  static TextStyle answerLabel(BuildContext context) => AppTypography.answerLabel;
}