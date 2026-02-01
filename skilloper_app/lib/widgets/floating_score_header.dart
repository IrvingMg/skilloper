import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

const _kScoreHeaderPadding = 64.0;
const _kScoreHeaderScoreHeight = 65.0;
const _kScoreHeaderSubtitleGap = 8.0;
// Height for 2 lines of text at fontSize 18 with normal line height (~1.2)
const _kScoreHeaderSubtitleHeight = 52.0;
const _kScoreHeaderBadgeGap = 4.0;
const _kScoreHeaderBadgeHeight = 32.0;
const _kScoreHeaderFootnoteGap = 4.0;
const _kScoreHeaderFootnoteHeight = 22.0;
const _kScoreHeaderSavedIndicatorGap = 12.0;
const _kScoreHeaderSavedIndicatorHeight = 20.0;

/// A score header widget for displaying quiz results with a gradient background.
///
/// The [subtitle] parameter displays context about the score (e.g., quiz title
/// or "X out of Y questions correct"). It supports up to 2 lines with ellipsis.
class FloatingScoreHeader extends StatelessWidget {
  final int score;
  final String subtitle;
  final String? badgeText;
  final String? footnote;
  final bool showSavedIndicator;

  const FloatingScoreHeader({
    required this.score,
    required this.subtitle,
    this.badgeText,
    this.footnote,
    this.showSavedIndicator = false,
    super.key,
  });

  /// Calculates the total height of the header based on which optional
  /// elements are present. Used by [FloatingScoreHeaderDelegate] for extent.
  double calculateHeight() {
    var height =
        _kScoreHeaderPadding +
        _kScoreHeaderScoreHeight +
        _kScoreHeaderSubtitleGap +
        _kScoreHeaderSubtitleHeight;

    if (badgeText != null) {
      height += _kScoreHeaderBadgeGap + _kScoreHeaderBadgeHeight;
    }
    if (footnote != null) {
      height += _kScoreHeaderFootnoteGap + _kScoreHeaderFootnoteHeight;
    }
    if (showSavedIndicator) {
      height +=
          _kScoreHeaderSavedIndicatorGap + _kScoreHeaderSavedIndicatorHeight;
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allXxxl,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score%',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (badgeText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.textOnPrimary.withValues(alpha: 0.2),
                borderRadius: AppRadius.fullAll,
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              footnote!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textOnPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (showSavedIndicator) ...[
            const SizedBox(height: AppSpacing.md),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done,
                  size: AppIconSizes.xs,
                  color: AppColors.textOnPrimary,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Result saved',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class FloatingScoreHeaderDelegate extends SliverPersistentHeaderDelegate {
  final FloatingScoreHeader header;

  FloatingScoreHeaderDelegate({required this.header});

  @override
  double get minExtent => header.calculateHeight();

  @override
  double get maxExtent => header.calculateHeight();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return header;
  }

  @override
  bool shouldRebuild(FloatingScoreHeaderDelegate oldDelegate) {
    return header.score != oldDelegate.header.score ||
        header.subtitle != oldDelegate.header.subtitle ||
        header.badgeText != oldDelegate.header.badgeText ||
        header.footnote != oldDelegate.header.footnote ||
        header.showSavedIndicator != oldDelegate.header.showSavedIndicator;
  }
}
