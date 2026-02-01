import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'page_header.dart';
import 'search_filter_bar.dart';

class HistoryScreenToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<FilterOption> filterOptions;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final List<SortOption> sortOptions;
  final String selectedSort;
  final ValueChanged<String> onSortChanged;

  const HistoryScreenToolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.filterOptions,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.sortOptions,
    required this.selectedSort,
    required this.onSortChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const PageHeader(
            title: 'Quiz History',
            subtitle: 'Review your past quiz attempts',
            icon: Icons.history,
          ),
          const SizedBox(height: AppSpacing.lg),
          SearchFilterBar(
            searchHint: 'Search history...',
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            filterOptions: filterOptions,
            selectedFilter: selectedFilter,
            onFilterChanged: onFilterChanged,
            sortOptions: sortOptions,
            selectedSort: selectedSort,
            onSortChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

class HistoryScreenToolbarDelegate extends SliverPersistentHeaderDelegate {
  final HistoryScreenToolbar toolbar;

  HistoryScreenToolbarDelegate({required this.toolbar});

  double _calculateHeight() {
    const topPadding = AppSpacing.lg;
    final pageHeaderHeight = calculatePageHeaderHeight(hasSubtitle: true);
    const spacingAfterHeader = AppSpacing.lg;
    const searchBarHeight = 52.0;
    return topPadding + pageHeaderHeight + spacingAfterHeader + searchBarHeight;
  }

  @override
  double get minExtent => _calculateHeight();

  @override
  double get maxExtent => _calculateHeight();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: toolbar),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(HistoryScreenToolbarDelegate oldDelegate) {
    // Toolbar is recreated on each build with new closures, so always rebuild
    return true;
  }
}
