import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

class FilterOption {
  final String value;
  final String label;

  const FilterOption({required this.value, required this.label});
}

class SortOption {
  final String value;
  final String label;

  const SortOption({required this.value, required this.label});
}

/// Common filter options for quiz type (practice/exam)
const kQuizTypeFilterOptions = [
  FilterOption(value: 'practice', label: 'Practice'),
  FilterOption(value: 'exam', label: 'Exam'),
];

/// Sort options for quizzes (home screen)
const kQuizSortOptions = [
  SortOption(value: 'date_desc', label: 'Newest first'),
  SortOption(value: 'date_asc', label: 'Oldest first'),
  SortOption(value: 'title_asc', label: 'Title A-Z'),
  SortOption(value: 'title_desc', label: 'Title Z-A'),
];

/// Sort options for attempts (history screen)
const kAttemptSortOptions = [
  SortOption(value: 'date_desc', label: 'Newest first'),
  SortOption(value: 'date_asc', label: 'Oldest first'),
  SortOption(value: 'score_desc', label: 'Highest score'),
  SortOption(value: 'score_asc', label: 'Lowest score'),
  SortOption(value: 'title_asc', label: 'Title A-Z'),
  SortOption(value: 'title_desc', label: 'Title Z-A'),
];

class SearchFilterBar extends StatefulWidget {
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<FilterOption> filterOptions;
  final String selectedFilter; // Empty string means "All"
  final ValueChanged<String> onFilterChanged;
  final List<SortOption>? sortOptions;
  final String? selectedSort;
  final ValueChanged<String>? onSortChanged;

  const SearchFilterBar({
    required this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    required this.filterOptions,
    required this.selectedFilter,
    required this.onFilterChanged,
    super.key,
    this.sortOptions,
    this.selectedSort,
    this.onSortChanged,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(SearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onControllerChanged);
      widget.searchController.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  String _getSelectedFilterLabel() {
    if (widget.selectedFilter.isEmpty) return 'All';
    return widget.filterOptions
        .firstWhere(
          (o) => o.value == widget.selectedFilter,
          orElse: () => const FilterOption(value: '', label: 'All'),
        )
        .label;
  }

  String _getSelectedSortLabel() {
    final sortOptions = widget.sortOptions;
    final selectedSort = widget.selectedSort;
    if (sortOptions == null || sortOptions.isEmpty) return '';
    if (selectedSort == null || selectedSort.isEmpty) {
      return sortOptions.first.label;
    }
    return sortOptions
        .firstWhere(
          (o) => o.value == selectedSort,
          orElse: () => sortOptions.first,
        )
        .label;
  }

  Widget _buildCheckIcon(bool isSelected) {
    return SizedBox(
      width: 18,
      child: isSelected
          ? const Icon(
              Icons.check,
              size: AppIconSizes.md,
              color: AppColors.primary,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.searchController.text.isNotEmpty;
    final hasFilter = widget.selectedFilter.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: widget.searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textDisabled,
                size: AppIconSizes.lg,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColors.textDisabled,
                        size: AppIconSizes.md,
                      ),
                      onPressed: () {
                        widget.searchController.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: const OutlineInputBorder(
                borderRadius: AppRadius.smAll,
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.smAll,
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.smAll,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        PopupMenuButton<String>(
          onSelected: widget.onFilterChanged,
          offset: const Offset(0, 45),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasFilter
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
              borderRadius: AppRadius.smAll,
              border: hasFilter
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list,
                  size: AppIconSizes.lg,
                  color: hasFilter ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  _getSelectedFilterLabel(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasFilter
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.arrow_drop_down,
                  size: AppIconSizes.lg,
                  color: hasFilter ? AppColors.primary : AppColors.textTertiary,
                ),
              ],
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: '',
              child: Row(
                children: [
                  _buildCheckIcon(widget.selectedFilter.isEmpty),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('All'),
                ],
              ),
            ),
            ...widget.filterOptions.map(
              (option) => PopupMenuItem<String>(
                value: option.value,
                child: Row(
                  children: [
                    _buildCheckIcon(widget.selectedFilter == option.value),
                    const SizedBox(width: AppSpacing.sm),
                    Text(option.label),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (widget.sortOptions != null &&
            widget.sortOptions!.isNotEmpty &&
            widget.onSortChanged != null) ...[
          const SizedBox(width: AppSpacing.sm),
          PopupMenuButton<String>(
            onSelected: widget.onSortChanged,
            offset: const Offset(0, 45),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.smAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.swap_vert,
                    size: AppIconSizes.lg,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    _getSelectedSortLabel(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: AppIconSizes.lg,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => widget.sortOptions!
                .map(
                  (option) => PopupMenuItem<String>(
                    value: option.value,
                    child: Row(
                      children: [
                        _buildCheckIcon(
                          widget.selectedSort == option.value ||
                              (widget.selectedSort?.isEmpty ?? true) &&
                                  option == widget.sortOptions!.first,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(option.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
