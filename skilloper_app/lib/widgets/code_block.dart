import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import '../theme/app_colors.dart';

class CodeBlock extends StatelessWidget {
  final String code;
  final String? language;

  const CodeBlock({
    super.key,
    required this.code,
    this.language,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Code copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Language indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getLanguageIcon(language),
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        language?.toUpperCase() ?? 'CODE',
                        style: TextStyle(
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
                
                // Copy button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _copyToClipboard(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
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
          
          // Code content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.codeBackground,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                code,
                language: language,
                theme: _customTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'SF Mono',
                  fontSize: 14,
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  // Custom theme that aligns with our app's design system
  static const Map<String, TextStyle> _customTheme = {
    'root': TextStyle(
      color: AppColors.codeText,
      backgroundColor: Colors.transparent,
    ),
    'keyword': TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    ),
    'built_in': TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w500,
    ),
    'type': TextStyle(
      color: AppColors.primary,
      fontStyle: FontStyle.italic,
    ),
    'literal': TextStyle(
      color: AppColors.success,
    ),
    'number': TextStyle(
      color: AppColors.success,
    ),
    'string': TextStyle(
      color: AppColors.success,
    ),
    'doctag': TextStyle(
      color: AppColors.success,
    ),
    'comment': TextStyle(
      color: AppColors.textTertiary,
      fontStyle: FontStyle.italic,
    ),
    'meta': TextStyle(
      color: AppColors.textTertiary,
    ),
    'function': TextStyle(
      color: AppColors.examMode,
      fontWeight: FontWeight.w500,
    ),
    'title': TextStyle(
      color: AppColors.examMode,
      fontWeight: FontWeight.w500,
    ),
    'variable': TextStyle(
      color: AppColors.textPrimary,
    ),
    'attribute': TextStyle(
      color: AppColors.info,
    ),
    'symbol': TextStyle(
      color: AppColors.warning,
    ),
    'tag': TextStyle(
      color: AppColors.error,
      fontWeight: FontWeight.w500,
    ),
    'name': TextStyle(
      color: AppColors.error,
    ),
    'selector-id': TextStyle(
      color: AppColors.error,
    ),
    'selector-class': TextStyle(
      color: AppColors.warning,
    ),
  };
}