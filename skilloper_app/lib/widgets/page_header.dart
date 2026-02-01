import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Height constants for PageHeader layout calculations.
/// Used by SliverPersistentHeaderDelegate implementations.
///
/// IMPORTANT: These values must stay synchronized with PageHeader's internal
/// layout (padding, font sizes, spacing). Update if PageHeader layout changes.
const kPageHeaderContainerPadding = 32.0;
const kPageHeaderIconHeight = 44.0;
const kPageHeaderTitleHeight = 36.0;
const kPageHeaderSubtitleGap = 4.0;
const kPageHeaderSubtitleHeight = 46.0;

/// Calculates the total height of a PageHeader widget.
double calculatePageHeaderHeight({required bool hasSubtitle}) {
  final textColumnHeight =
      kPageHeaderTitleHeight +
      (hasSubtitle ? kPageHeaderSubtitleGap + kPageHeaderSubtitleHeight : 0);
  final contentHeight = textColumnHeight > kPageHeaderIconHeight
      ? textColumnHeight
      : kPageHeaderIconHeight;
  return kPageHeaderContainerPadding + contentHeight;
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Optional widget displayed after the title (e.g., action buttons, filters)
  final Widget? trailing;

  const PageHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.6),
            AppColors.primaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: AppIconSizes.xxl,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryContainer,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
