import 'package:flutter/material.dart';

/// Skilloper App Design System - Icons
/// Consistent iconography following Material Design principles
class AppIcons {
  AppIcons._();

  // MARK: - Question Types (Learning Platform Optimized)
  static const IconData practiceMode = Icons.lightbulb_outlined; // Lightbulb for learning/ideas
  static const IconData practiceModeSelected = Icons.lightbulb;
  static const IconData examMode = Icons.school_outlined;
  static const IconData examModeSelected = Icons.school;
  

  // MARK: - Navigation
  static const IconData home = Icons.home_outlined;
  static const IconData homeSelected = Icons.home;
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

  // Standard sizes
  static const double medium = 20.0;
  static const double large = 24.0;

  // Context-specific sizes
  static const double buttonIcon = 18.0;
  static const double navIcon = 24.0;
}

/// Icon themes for different contexts (Learning Platform Optimized)
class AppIconThemes {
  AppIconThemes._();

  static IconThemeData light = const IconThemeData(
    color: Color(0xFF6B7280), // textTertiary
    size: AppIconSizes.medium,
  );
}