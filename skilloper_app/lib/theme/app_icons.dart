import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_colors.dart';

/// Skilloper App Design System - Icons
/// Consistent iconography following Material Design principles
class AppIcons {
  AppIcons._();

  // MARK: - SVG Asset Paths
  static const String practiceModeSvg = 'assets/images/skilloper_practice.svg';
  static const String examModeSvg = 'assets/images/skilloper_exam.svg';

  // MARK: - Navigation
  static const IconData home = Icons.home_outlined;
  static const IconData homeSelected = Icons.home;
  static const IconData history = Icons.history_outlined;
  static const IconData historySelected = Icons.history;
  static const IconData add = Icons.add_circle_outline;
  static const IconData addSelected = Icons.add_circle;
  static const IconData upload = Icons.upload_outlined;
  static const IconData uploadSelected = Icons.upload;






  // MARK: - Programming Languages (for code blocks)
  static IconData getLanguageIcon(String? language) {
    switch (language?.toLowerCase()) {
      case 'javascript':
      case 'js':
        return Icons.javascript;
      case 'python':
      case 'py':
        return Icons.psychology; // Brain icon for AI/ML language
      case 'java':
        return Icons.coffee;
      case 'go':
      case 'golang':
        return Icons.speed;
      case 'dart':
      case 'flutter':
        return Icons.flutter_dash;
      case 'html':
      case 'css':
      case 'web':
        return Icons.web;
      case 'react':
      case 'vue':
      case 'angular':
        return Icons.dynamic_feed;
      case 'sql':
      case 'database':
        return Icons.storage;
      case 'json':
        return Icons.data_object;
      case 'xml':
        return Icons.code;
      default:
        return Icons.code;
    }
  }
}

/// Icon sizing constants for consistency
class AppIconSizes {
  AppIconSizes._();

  // Standard sizes (4px increments)
  static const double xs = 14.0;
  static const double sm = 16.0;
  static const double md = 18.0;
  static const double lg = 20.0;
  static const double xl = 22.0;
  static const double xxl = 24.0;
  static const double xxxl = 28.0;

  // Large sizes for prominent icons
  static const double appBarLogo = 36.0;
  static const double quizCardNarrow = 44.0;
  static const double quizCardWide = 56.0;

  // Semantic aliases for common contexts
  static const double inline = xs;       // For inline text icons
  static const double button = md;       // For button icons
  static const double menu = lg;         // For menu/list item icons
  static const double nav = xxl;         // For navigation icons
  static const double header = xxxl;     // For section headers
}

/// Icon themes for different contexts (Learning Platform Optimized)
class AppIconThemes {
  AppIconThemes._();

  static const IconThemeData light = IconThemeData(
    color: AppColors.textTertiary,
    size: AppIconSizes.lg,
  );
}

/// Widget for displaying quiz mode SVG icons
class QuizModeIcon extends StatelessWidget {
  final bool isExamMode;
  final double size;

  const QuizModeIcon({
    super.key,
    required this.isExamMode,
    this.size = AppIconSizes.lg,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      isExamMode ? AppIcons.examModeSvg : AppIcons.practiceModeSvg,
      width: size,
      height: size,
    );
  }
}