import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../utils/snackbar_helper.dart';
import '../utils/web_clipboard.dart';

class PromptCard extends StatefulWidget {
  final String title;
  final String description;
  final String prompt;

  const PromptCard({
    required this.title,
    required this.description,
    required this.prompt,
    super.key,
  });

  @override
  State<PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<PromptCard> {
  bool _copied = false;

  Future<void> _copyToClipboard() async {
    final success = await copyToClipboard(widget.prompt);
    if (!mounted) return;

    if (success) {
      setState(() => _copied = true);
      showCopySuccessSnackBar(context, 'Prompt copied to clipboard');
      unawaited(
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _copied = false);
          }
        }),
      );
    } else {
      showCopyErrorSnackBar(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with copy button
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: AppIconSizes.sm,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Copy button in header
                IconButton(
                  onPressed: _copyToClipboard,
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: AppIconSizes.md,
                    color: _copied ? AppColors.success : AppColors.primary,
                  ),
                  tooltip: 'Copy prompt',
                  style: IconButton.styleFrom(
                    backgroundColor: _copied
                        ? AppColors.successContainer
                        : AppColors.primaryContainer,
                  ),
                ),
              ],
            ),
          ),

          // Prompt content
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  widget.prompt,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.5,
                    color: AppColors.codeText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
