import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'page_header.dart';

class FloatingPageHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String? subtitle;
  final IconData? icon;

  FloatingPageHeaderDelegate({required this.title, this.subtitle, this.icon});

  double _calculateHeaderHeight() {
    return calculatePageHeaderHeight(hasSubtitle: subtitle != null);
  }

  @override
  double get minExtent => AppSpacing.lg + _calculateHeaderHeight();

  @override
  double get maxExtent => AppSpacing.lg + _calculateHeaderHeight();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: PageHeader(title: title, subtitle: subtitle, icon: icon),
      ),
    );
  }

  @override
  bool shouldRebuild(FloatingPageHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        subtitle != oldDelegate.subtitle ||
        icon != oldDelegate.icon;
  }
}
