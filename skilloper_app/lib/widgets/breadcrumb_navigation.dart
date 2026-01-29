import 'package:flutter/material.dart';

import '../models/collection.dart';
import '../theme/app_colors.dart';

const String kBreadcrumbRootLabel = 'All';

class BreadcrumbNavigation extends StatelessWidget {
  final List<CollectionBreadcrumb> breadcrumbs;
  final VoidCallback onNavigateUp;
  final void Function(int index) onNavigateToBreadcrumb;

  const BreadcrumbNavigation({
    required this.breadcrumbs,
    required this.onNavigateUp,
    required this.onNavigateToBreadcrumb,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (breadcrumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          InkWell(
            onTap: onNavigateUp,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => onNavigateToBreadcrumb(-1),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        kBreadcrumbRootLabel,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < breadcrumbs.length; i++) ...[
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    InkWell(
                      onTap: i < breadcrumbs.length - 1
                          ? () => onNavigateToBreadcrumb(i)
                          : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          breadcrumbs[i].name,
                          style: TextStyle(
                            color: i < breadcrumbs.length - 1
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: i < breadcrumbs.length - 1
                                ? FontWeight.w500
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

mixin CollectionNavigationMixin<T extends StatefulWidget> on State<T> {
  List<CollectionBreadcrumb> breadcrumbs = [];
  int? currentParentId;

  void navigateIntoCollection(Collection collection, {VoidCallback? onNavigate}) {
    setState(() {
      breadcrumbs = [
        ...breadcrumbs,
        CollectionBreadcrumb(id: collection.id, name: collection.name),
      ];
      currentParentId = collection.id;
    });
    onNavigate?.call();
  }

  void navigateToBreadcrumb(int index, {VoidCallback? onNavigate}) {
    if (index < 0) {
      setState(() {
        breadcrumbs = [];
        currentParentId = null;
      });
    } else {
      final breadcrumb = breadcrumbs[index];
      setState(() {
        breadcrumbs = breadcrumbs.sublist(0, index + 1);
        currentParentId = breadcrumb.id;
      });
    }
    onNavigate?.call();
  }

  void navigateUp({VoidCallback? onNavigate}) {
    if (breadcrumbs.isEmpty) return;
    if (breadcrumbs.length == 1) {
      navigateToBreadcrumb(-1, onNavigate: onNavigate);
    } else {
      navigateToBreadcrumb(breadcrumbs.length - 2, onNavigate: onNavigate);
    }
  }

  void resetNavigation({VoidCallback? onNavigate}) {
    setState(() {
      breadcrumbs = [];
      currentParentId = null;
    });
    onNavigate?.call();
  }
}
