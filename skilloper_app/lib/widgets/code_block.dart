import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_view/flutter_code_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Code block widget for displaying code snippets in quiz questions
class CodeBlock extends StatelessWidget {
  final String code;
  final String? language;

  const CodeBlock({required this.code, super.key, this.language});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check,
              color: AppColors.textOnPrimary,
              size: AppIconSizes.sm,
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Code copied to clipboard'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Languages? _getLanguage(String? lang) {
    switch (lang?.toLowerCase()) {
      case 'javascript':
      case 'js':
        return Languages.javascript;
      case 'python':
      case 'py':
        return Languages.python;
      case 'java':
        return Languages.java;
      case 'go':
        return Languages.go;
      case 'dart':
        return Languages.dart;
      case 'html':
        return Languages.xml;
      case 'css':
        return Languages.css;
      case 'sql':
        return Languages.sql;
      case 'typescript':
      case 'ts':
        return Languages.typescript;
      case 'json':
        return Languages.json;
      case 'swift':
        return Languages.swift;
      case 'kotlin':
        return Languages.kotlin;
      case 'rust':
        return Languages.rust;
      case 'c':
      case 'cpp':
      case 'c++':
        return Languages.cpp;
      default:
        return null;
    }
  }

  IconData _getLanguageIcon(String? language) {
    switch (language?.toLowerCase()) {
      case 'javascript':
      case 'js':
        return Icons.code;
      case 'python':
      case 'py':
        return Icons.psychology;
      case 'java':
        return Icons.coffee;
      case 'go':
        return Icons.speed;
      case 'dart':
        return Icons.flutter_dash;
      case 'html':
        return Icons.web;
      case 'css':
        return Icons.palette;
      case 'sql':
        return Icons.storage;
      default:
        return Icons.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: AppSpacing.verticalSm,
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language badge and copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.xsAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLanguageIcon(language),
                        size: AppIconSizes.xs,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Text(
                        language?.toUpperCase() ?? 'CODE',
                        style: const TextStyle(
                          color: AppColors.onPrimaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _copyToClipboard(context),
                    borderRadius: AppRadius.xsAll,
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.xs + 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: AppIconSizes.xs,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            'Copy',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code view - wrapped in Container with consistent background
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.md),
            ),
            child: Container(
              width: double.infinity,
              color: AppColors.codeBackground,
              child: FlutterCodeView(
                source: code,
                language: _getLanguage(language),
                themeType: ThemeType.github,
                showLineNumbers: true,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
