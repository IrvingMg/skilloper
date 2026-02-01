import 'package:flutter/material.dart';

import '../models/collection.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'breadcrumb_navigation.dart';
import 'collection_chip.dart';
import 'page_header.dart';
import 'search_filter_bar.dart';

const double kPageHeaderHeight = 94.0;
const double kCollectionsRowHeight = 36.0;
const double kQuizCountRowHeight = 20.0;

class CollapsibleHomeToolbar extends StatelessWidget {
  final List<CollectionBreadcrumb> breadcrumbs;
  final List<Collection> collections;
  final int? selectedCollectionId;
  final ScrollController collectionsScrollController;
  final bool canScrollLeft;
  final bool canScrollRight;
  final VoidCallback onScrollLeft;
  final VoidCallback onScrollRight;
  final void Function(Collection) onNavigateIntoCollection;
  final VoidCallback onNavigateUp;
  final void Function(int) onNavigateToBreadcrumb;
  final VoidCallback onCreateCollection;
  final void Function(Collection) onRenameCollection;
  final void Function(Collection) onDeleteCollection;

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<FilterOption> filterOptions;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final List<SortOption> sortOptions;
  final String selectedSort;
  final ValueChanged<String> onSortChanged;

  final int quizCount;
  final int totalQuizCount;
  final bool hasMore;

  final bool isSelectionMode;
  final int selectedCount;
  final int totalSelectableCount;
  final VoidCallback onExitSelectionMode;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onEnterSelectionMode;
  final bool hasQuizzes;

  const CollapsibleHomeToolbar({
    required this.breadcrumbs,
    required this.collections,
    required this.selectedCollectionId,
    required this.collectionsScrollController,
    required this.canScrollLeft,
    required this.canScrollRight,
    required this.onScrollLeft,
    required this.onScrollRight,
    required this.onNavigateIntoCollection,
    required this.onNavigateUp,
    required this.onNavigateToBreadcrumb,
    required this.onCreateCollection,
    required this.onRenameCollection,
    required this.onDeleteCollection,
    required this.searchController,
    required this.onSearchChanged,
    required this.filterOptions,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.sortOptions,
    required this.selectedSort,
    required this.onSortChanged,
    required this.quizCount,
    required this.totalQuizCount,
    required this.hasMore,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.totalSelectableCount,
    required this.onExitSelectionMode,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onEnterSelectionMode,
    required this.hasQuizzes,
    super.key,
  });

  Widget _buildScrollArrow(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            backgroundColor,
            backgroundColor.withValues(alpha: 0.8),
            backgroundColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Padding(
            padding: EdgeInsets.only(
              left: isLeft ? AppSpacing.xs : AppSpacing.lg,
              right: isLeft ? AppSpacing.lg : AppSpacing.xs,
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Icon(
              icon,
              size: AppIconSizes.xl,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onExitSelectionMode,
          tooltip: 'Cancel selection',
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$selectedCount selected',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: selectedCount == totalSelectableCount
              ? onDeselectAll
              : onSelectAll,
          child: Text(
            selectedCount == totalSelectableCount
                ? 'Deselect All'
                : 'Select All',
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsRow(BuildContext context) {
    return SizedBox(
      height: kCollectionsRowHeight,
      child: Stack(
        children: [
          ListView.separated(
            controller: collectionsScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: breadcrumbs.isEmpty
                ? collections.length + 2
                : collections.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (breadcrumbs.isEmpty && index == 0) {
                return CollectionChip(
                  label: 'All',
                  isSelected: selectedCollectionId == null,
                  onTap: () {},
                );
              }
              final collectionIndex = breadcrumbs.isEmpty ? index - 1 : index;
              if (collectionIndex == collections.length) {
                return AddCollectionChip(onTap: onCreateCollection);
              }
              final collection = collections[collectionIndex];
              return CollectionChip(
                label: collection.name,
                isSelected: selectedCollectionId == collection.id,
                color: AppColors.getCollectionColor(collection.id),
                onTap: () => onNavigateIntoCollection(collection),
                onRename: () => onRenameCollection(collection),
                onDelete: () => onDeleteCollection(collection),
              );
            },
          ),
          if (canScrollLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _buildScrollArrow(
                context,
                icon: Icons.chevron_left,
                isLeft: true,
                onTap: onScrollLeft,
              ),
            ),
          if (canScrollRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _buildScrollArrow(
                context,
                icon: Icons.chevron_right,
                isLeft: false,
                onTap: onScrollRight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SearchFilterBar(
            searchHint: 'Search quizzes...',
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            filterOptions: filterOptions,
            selectedFilter: selectedFilter,
            onFilterChanged: onFilterChanged,
            sortOptions: sortOptions,
            selectedSort: selectedSort,
            onSortChanged: onSortChanged,
          ),
        ),
        if (hasQuizzes && !isSelectionMode) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: onEnterSelectionMode,
            tooltip: 'Select multiple quizzes',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuizCountRow() {
    if (totalQuizCount <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: kQuizCountRowHeight,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          hasMore
              ? 'Showing $quizCount of $totalQuizCount quizzes'
              : '$totalQuizCount ${totalQuizCount == 1 ? 'quiz' : 'quizzes'}',
          style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSelectionMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: _buildSelectionHeader(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const PageHeader(
            title: 'Available Quizzes',
            subtitle: 'Choose a quiz to test your skills',
            icon: Icons.quiz_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (breadcrumbs.isNotEmpty) ...[
            BreadcrumbNavigation(
              breadcrumbs: breadcrumbs,
              onNavigateUp: onNavigateUp,
              onNavigateToBreadcrumb: onNavigateToBreadcrumb,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _buildCollectionsRow(context),
          const SizedBox(height: AppSpacing.md),
          _buildSearchFilterRow(),
          const SizedBox(height: AppSpacing.sm),
          _buildQuizCountRow(),
        ],
      ),
    );
  }
}

class CollapsibleHomeToolbarDelegate extends SliverPersistentHeaderDelegate {
  final CollapsibleHomeToolbar toolbar;
  final double minHeight;
  final double maxHeight;

  CollapsibleHomeToolbarDelegate({
    required this.toolbar,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // shrinkOffset and overlapsContent unused: this is a fixed-height floating
    // header (minExtent == maxExtent) that hides/shows without collapsing.
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
  bool shouldRebuild(CollapsibleHomeToolbarDelegate oldDelegate) {
    // Toolbar is recreated on each build, so always rebuild
    return true;
  }
}
