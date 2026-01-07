import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_icons.dart';

/// Skilloper App Design System - Complete Theme
/// Soft Gradient Violet theme with modern, friendly aesthetics
class AppTheme {
  AppTheme._();

  // MARK: - Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorSchemes.light,

      // Typography
      textTheme: _textTheme,

      // Scaffold background
      scaffoldBackgroundColor: AppColors.surface,

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
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
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

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
        ),
        elevation: 0,
      ),

      // Floating Action Button
      floatingActionButtonTheme: _fabTheme,
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
    scrolledUnderElevation: 0,
    backgroundColor: AppColors.primaryContainer,
    foregroundColor: AppColors.onPrimaryContainer,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.onPrimaryContainer,
    ),
    iconTheme: IconThemeData(
      color: AppColors.onPrimaryContainer,
      size: AppIconSizes.nav,
    ),
  );

  static final CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgAll,
    ),
    color: AppColors.surfaceWhite,
    surfaceTintColor: Colors.transparent,
    margin: EdgeInsets.zero,
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      textStyle: AppTypography.buttonMedium,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
      ),
      elevation: 0,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppColors.textOnPrimary.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return AppColors.textOnPrimary.withValues(alpha: 0.08);
        }
        return null;
      }),
    ),
  );

  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      textStyle: AppTypography.buttonMedium,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
      ),
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      backgroundColor: AppColors.surfaceWhite,
      textStyle: AppTypography.buttonMedium,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
      ),
      side: const BorderSide(color: AppColors.outline, width: 1),
    ).copyWith(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const BorderSide(color: AppColors.primaryContainer, width: 1);
        }
        return const BorderSide(color: AppColors.outline, width: 1);
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primaryContainerLight;
        }
        return AppColors.surfaceWhite;
      }),
    ),
  );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTypography.buttonMedium,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smAll,
      ),
    ),
  );

  static final IconButtonThemeData _iconButtonTheme = IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      padding: const EdgeInsets.all(12),
      iconSize: AppIconSizes.button,
      shape: const CircleBorder(),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return AppColors.surfaceContainer;
        }
        return Colors.transparent;
      }),
    ),
  );

  static final InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceWhite,
    border: OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: const BorderSide(color: AppColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: const BorderSide(color: AppColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: AppTypography.labelLarge,
    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
    errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.error),
  );

  // Material 3 NavigationBar theme
  static final NavigationBarThemeData _navigationBarTheme = NavigationBarThemeData(
    elevation: 0,
    backgroundColor: AppColors.surfaceWhite,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    height: 72,
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
        return const IconThemeData(
          color: AppColors.primary,
          size: AppIconSizes.nav,
        );
      }
      return const IconThemeData(
        color: AppColors.textTertiary,
        size: AppIconSizes.nav,
      );
    }),
    indicatorColor: AppColors.primaryContainer,
    indicatorShape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdAll,
    ),
  );

  // Legacy BottomNavigationBar theme (kept for compatibility)
  static final BottomNavigationBarThemeData _bottomNavigationBarTheme = BottomNavigationBarThemeData(
    elevation: 0,
    backgroundColor: AppColors.surfaceWhite,
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
    color: AppColors.outline,
    thickness: 1,
    space: 1,
  );

  static const ProgressIndicatorThemeData _progressIndicatorTheme = ProgressIndicatorThemeData(
    color: AppColors.primary,
    linearTrackColor: AppColors.primaryContainerLight,
    circularTrackColor: AppColors.primaryContainerLight,
  );

  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: AppColors.surfaceContainer,
    selectedColor: AppColors.primaryContainer,
    labelStyle: AppTypography.labelMedium,
    side: const BorderSide(color: AppColors.outline, width: 1),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xsAll,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  static final FloatingActionButtonThemeData _fabTheme = FloatingActionButtonThemeData(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.textOnPrimary,
    elevation: 0,
    hoverElevation: 0,
    focusElevation: 0,
    highlightElevation: 0,
    shape: const CircleBorder(),
    sizeConstraints: const BoxConstraints.tightFor(width: 56, height: 56),
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
